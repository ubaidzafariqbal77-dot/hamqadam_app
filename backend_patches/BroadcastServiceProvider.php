<?php

namespace App\Providers;

use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\ServiceProvider;

class BroadcastServiceProvider extends ServiceProvider
{
    public function boot()
    {
        // WHY THIS CHANGED
        //
        // `Broadcast::routes()` with no arguments registers /broadcasting/auth
        // behind the `web` middleware, i.e. session-cookie auth. That is why the
        // website works: Echo sends the session cookie.
        //
        // The mobile app authenticates with a Sanctum BEARER TOKEN, which the
        // `web` guard never looks at, so every private-channel subscription from
        // a phone was rejected — POST /broadcasting/auth answers 403 — and no
        // chat message or call event ever reached the app.
        //
        // Keeping `web` alongside `auth:sanctum` means one endpoint serves both
        // clients: the browser authenticates by cookie, the app by token.
        Broadcast::routes(['middleware' => ['web', 'auth:sanctum']]);

        require base_path('routes/channels.php');
    }
}
