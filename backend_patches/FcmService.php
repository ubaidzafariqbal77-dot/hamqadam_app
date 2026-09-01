<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Firebase Cloud Messaging over the HTTP v1 API.
 *
 * WHY THIS REPLACES App\Services\FirbaseNotification
 * --------------------------------------------------
 * That class posts to `https://fcm.googleapis.com/fcm/send` with an
 * `Authorization: key=<FIREBASE_SERVER_KEY>` header. Google retired the legacy
 * FCM HTTP API on 20 June 2024 and the endpoint now answers **404** — verified
 * against the live endpoint. So no push it has ever sent since then was
 * delivered, and because it discards the curl result nothing was logged either.
 *
 * v1 needs an OAuth2 access token minted from a SERVICE ACCOUNT JSON file
 * instead of a server key. No new composer package is required: the assertion
 * below is a plain RS256 JWT signed with openssl, which ships with PHP.
 *
 * SETUP
 * -----
 * 1. Firebase console -> Project settings -> Service accounts -> "Generate new
 *    private key". Save the JSON OUTSIDE the webroot, e.g.
 *    storage/app/firebase/service-account.json, and make sure it is not
 *    web-readable and not committed.
 * 2. .env:
 *      FIREBASE_PROJECT_ID=your-firebase-project-id
 *      FIREBASE_CREDENTIALS=/absolute/path/to/service-account.json
 * 3. Delete FIREBASE_SERVER_KEY — it does nothing any more.
 */
class FcmService
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
    private const TOKEN_CACHE_KEY = 'fcm_v1_access_token';

    /**
     * Sends one message to one device token.
     *
     * @param  array<string,string>  $data  Data payload. FCM requires every
     *                                      value to be a string.
     * @return bool  Whether FCM accepted it.
     */
    public function send(
        string $deviceToken,
        string $title,
        string $body,
        array $data = [],
        bool $highPriority = false,
    ): bool {
        if ($deviceToken === '') {
            return false;
        }

        $projectId = (string) config('services.fcm.project_id', env('FIREBASE_PROJECT_ID', ''));
        if ($projectId === '') {
            Log::error('FCM project id is not configured.');

            return false;
        }

        $accessToken = $this->accessToken();
        if ($accessToken === null) {
            return false;
        }

        $message = [
            'token' => $deviceToken,
            'notification' => ['title' => $title, 'body' => $body],
            // Values MUST be strings; FCM rejects the whole message otherwise.
            'data' => array_map(static fn ($v) => (string) $v, $data),
            'android' => [
                'priority' => $highPriority ? 'HIGH' : 'NORMAL',
                'notification' => ['channel_id' => $highPriority ? 'calls' : 'high_importance_channel'],
            ],
            'apns' => [
                'headers' => [
                    'apns-priority' => $highPriority ? '10' : '5',
                    // Lets a call alert through Focus / Do Not Disturb.
                    'apns-push-type' => 'alert',
                ],
                'payload' => ['aps' => ['sound' => 'default']],
            ],
        ];

        try {
            $response = Http::withToken($accessToken)
                ->timeout(10)
                ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                    'message' => $message,
                ]);

            if ($response->successful()) {
                return true;
            }

            // The old class threw the result away, which is exactly why nobody
            // noticed it had been failing for months.
            Log::warning('FCM send failed.', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            // UNREGISTERED means the app was uninstalled or the token rotated.
            // Prune it so the next send is not wasted on a dead device.
            if ($response->status() === 404) {
                \App\Models\UserPushToken::where('token', $deviceToken)->delete();
            }

            return false;
        } catch (Throwable $e) {
            Log::error('FCM send threw.', ['message' => $e->getMessage()]);

            return false;
        }
    }

    /**
     * Sends to every device a user has registered.
     *
     * @param  array<string,string>  $data
     */
    public function sendToUser(
        int $userId,
        string $title,
        string $body,
        array $data = [],
        bool $highPriority = false,
    ): void {
        $tokens = \App\Models\UserPushToken::query()
            ->where('user_id', $userId)
            ->pluck('token')
            ->filter()
            ->unique();

        foreach ($tokens as $token) {
            $this->send((string) $token, $title, $body, $data, $highPriority);
        }
    }

    /**
     * OAuth2 access token for the service account, cached until just before it
     * expires so a burst of pushes does not mint one each.
     */
    private function accessToken(): ?string
    {
        $cached = Cache::get(self::TOKEN_CACHE_KEY);
        if (is_string($cached) && $cached !== '') {
            return $cached;
        }

        $path = (string) config('services.fcm.credentials', env('FIREBASE_CREDENTIALS', ''));
        if ($path === '' || ! is_readable($path)) {
            Log::error('Firebase service account file is missing or unreadable.', ['path' => $path]);

            return null;
        }

        $credentials = json_decode((string) file_get_contents($path), true);
        if (! is_array($credentials) || ! isset($credentials['client_email'], $credentials['private_key'])) {
            Log::error('Firebase service account file is not a valid service account JSON.');

            return null;
        }

        $now = time();
        $claims = [
            'iss' => $credentials['client_email'],
            'scope' => self::SCOPE,
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ];

        $segments = [
            $this->base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT'])),
            $this->base64Url(json_encode($claims)),
        ];
        $signingInput = implode('.', $segments);

        $signature = '';
        if (! openssl_sign($signingInput, $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256)) {
            Log::error('Could not sign the Firebase JWT assertion.');

            return null;
        }
        $assertion = $signingInput . '.' . $this->base64Url($signature);

        try {
            $response = Http::asForm()->timeout(10)->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ]);
        } catch (Throwable $e) {
            Log::error('Firebase token request threw.', ['message' => $e->getMessage()]);

            return null;
        }

        if (! $response->successful()) {
            Log::error('Firebase token request failed.', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            return null;
        }

        $token = (string) $response->json('access_token', '');
        if ($token === '') {
            return null;
        }

        $expiresIn = (int) $response->json('expires_in', 3600);
        // 60s of headroom so a token cannot expire mid-request.
        Cache::put(self::TOKEN_CACHE_KEY, $token, max(60, $expiresIn - 60));

        return $token;
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
