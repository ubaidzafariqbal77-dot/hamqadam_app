# Backend patches for mobile calling & push

The Flutter app now uses the backend's own call API and Pusher channels — the
same ones the website uses — so a mobile call writes the same `calls` row and
the same log lines as a web call. Two things on the server still have to change.

Everything here was written against the code in `hamqadam_live-main.zip`.

---

## 1. `/broadcasting/auth` must accept the app's bearer token — REQUIRED

**File:** `app/Providers/BroadcastServiceProvider.php` → replace with
`BroadcastServiceProvider.php` from this folder.

`Broadcast::routes()` with no arguments registers the endpoint behind the `web`
middleware, i.e. session-cookie auth. The website works because Echo sends the
session cookie. The app sends a Sanctum **bearer token**, which the `web` guard
never reads, so every private-channel subscription from a phone is rejected:

```
POST https://hamqadam.com/broadcasting/auth  →  403
```

Until this is changed, the app receives **no** chat message and **no** call
event, however correct the client is.

### Verified against production on 2026-08-30

Measured from a logged-in browser session on hamqadam.com:

| Check | Result |
|---|---|
| Pusher connection (web) | `connected`, cluster `ap2`, key `9c14e9…` |
| Channel the website subscribes to | `private-App.User.{id}`, `subscribed: true` |
| `GET /api/v1/bridge/connector-a` | `enabled: true`, same key and cluster as the web |
| `POST /broadcasting/auth` with session cookie | accepted |
| `POST /broadcasting/auth` without cookie, bearer header | rejected |

So the Pusher account, the admin settings and the channel names are all correct
— the app will get the right credentials. The one thing standing between mobile
and working realtime is the middleware on this route.

**Verify after deploying** — this should return 200, not 403:

```bash
curl -i -X POST https://hamqadam.com/broadcasting/auth \
  -H "Authorization: Bearer <a real app token>" \
  -H "Accept: application/json" \
  -d "socket_id=1234.5678&channel_name=private-App.User.<that user's id>"
```

### Also check these two settings

* `.env` → `BROADCAST_DRIVER=pusher` (the shipped `.env.example` says `log`).
* The Pusher app the **server** publishes to comes from `.env`
  (`config/broadcasting.php` reads `env('PUSHER_APP_KEY')`), but the app fetches
  its key from `GET /bridge/connector-a`, which reads
  `get_setting('pusher_app_key')` from the admin settings. **These must be the
  same Pusher app**, and `chat_realtime_enabled` must be `1` — otherwise the
  bridge reports `enabled: false` and the app silently falls back to polling.

---

## 2. FCM — currently dead, and the reason no call rings a closed app

`app/Services/FirbaseNotification.php` posts to
`https://fcm.googleapis.com/fcm/send` with `Authorization: key=…`. Google retired
that legacy API on **20 June 2024**; the endpoint now returns **404** (verified
against the live endpoint). Nothing it sends is delivered, and since it discards
the curl result, nothing is logged either.

**File:** add `FcmService.php` from this folder as `app/Services/FcmService.php`.
It speaks FCM HTTP v1, authenticating with a service-account JSON. No new
composer package is needed — the JWT is signed with `openssl`, which ships with
PHP.

### Setup

1. Firebase console → Project settings → Service accounts → **Generate new
   private key**. Save it outside the webroot, e.g.
   `storage/app/firebase/service-account.json`. Do not commit it.
2. `.env`:
   ```
   FIREBASE_PROJECT_ID=your-firebase-project-id
   FIREBASE_CREDENTIALS=/absolute/path/to/service-account.json
   ```
   `FIREBASE_SERVER_KEY` can go — it does nothing now.
3. Replace the nine `FirbaseNotification::send($data)` call sites (grep for them)
   with `FcmService::sendToUser(...)`.

### Ring a device that has the app closed

Pusher only reaches a running app. For a call to ring a backgrounded or killed
phone, `CallService::start()` has to push as well as broadcast. After
`$this->broadcastSafely(new CallIncoming($payload));`:

```php
app(\App\Services\FcmService::class)->sendToUser(
    (int) $call->receiver_id,
    trim(($caller->first_name ?? '') . ' ' . ($caller->last_name ?? '')),
    $type->value === 'video' ? 'Incoming video call' : 'Incoming voice call',
    [
        // The app rings on this and re-reads GET /calls/{id} before showing
        // anything, so a push delayed by Doze can never ring for a call that
        // is already over.
        'type' => 'call_incoming',
        'call_id' => (string) $call->id,
    ],
    highPriority: true,
);
```

The app already handles `type: call_incoming` and shows the tray notification
with **Accept** and **Decline** buttons plus a full-screen ringing screen.

Worth doing the same in `ChatService` on a new message, so chat notifications
arrive when the app is closed.

---

## 3. `annual_salary_ranges` is still not served — REQUIRED for signup

`POST /auth/register/complete` rejects a payload without `annual_salary_range_id`
(ids 1–16 are accepted, 17+ rejected), but the list is not in the reference data:

```
GET /api/v1/profile/dropdown-reference-data  →  200, 29 lists, annual_salary_ranges MISSING
```
(measured 2026-08-30 from a logged-in session)

The app cannot label a foreign key it is never told the names of, so it is
currently showing provisional band labels against the server's real ids. Add
`annual_salary_ranges` to that endpoint the way every other list is served, then
drop the returned rows into `SalaryRangeOptions.bands` and the provisional list
stops being consulted.

---

## 4. One-line mismatch (already fixed on the app side)

`StorePushTokenRequest` validates `platform`, and the app was sending
`device_type`, so `user_push_tokens.platform` was always null. The app now sends
both keys; nothing to change here unless you want to drop the alias.
