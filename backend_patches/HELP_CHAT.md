# Help Center Chat (the app's Help button)

Implemented 2026-09-08 in the live source at
`/Applications/XAMPP/xamppfiles/htdocs/hamqadam_live/` and in the Flutter app
at `~/Desktop/Matrimonial/hamqadam`. Every backend change is in git there, so
`git diff` shows it and `git checkout` reverts it.

---

## What it does

A logged-in member with a problem taps **HamQadam Help Center** in the app's
drawer, writes their issue (text + optional photos/documents), and sends it.
The message lands in a new **Help Center Chats** section of the admin panel,
listed one row per member with an unread badge. The admin replies from the
panel; the reply reaches the member **in real time** — in the open
conversation over Pusher, and as an FCM tray push when the app is closed.

## Backend (Laravel)

| Piece | File |
|---|---|
| Tables | `database/migrations/2026_09_08_000001_create_help_chat_tables.php` |
| Raw SQL for CyberPanel | `sqlupdates/v57.sql` |
| Models | `app/Models/HelpChatThread.php`, `app/Models/HelpChatMessage.php` |
| Broadcast event | `app/Events/HelpChatMessageSent.php` |
| Service (both sides) | `app/Services/HelpChatService.php` |
| Member API | `app/Http/Controllers/Api/V1/HelpChat/HelpChatController.php` + resources under `app/Http/Resources/Api/V1/HelpChat/` |
| Admin panel | `app/Http/Controllers/HelpChatAdminController.php` + `resources/views/admin/help_chat/` |
| Routes | `routes/api_v1.php` (`/api/v1/help-chat/*`), `routes/admin.php` (`/admin/help-chat/*`), `routes/channels.php` (`private-help-chat.{id}`) |
| Sidebar | `resources/views/admin/inc/sidenav.blade.php` — "Help Center Chats", after Contact Us Queries |

### API (Sanctum bearer)

```
GET  /api/v1/help-chat/thread     → the member's conversation (created on first use; clears unread)
GET  /api/v1/help-chat/messages   → paginated messages, newest first
POST /api/v1/help-chat/messages   → send text and/or up to 5 attachments (multipart `attachments[]`)
```

### Realtime

`HelpChatMessageSent` broadcasts as `help-message-sent` on:

* `private-help-chat.{threadId}` — the conversation. Authorized for the
  thread's owner and for admin/staff/subadmin (see `routes/channels.php`).
* `private-App.User.{recipient}` — the side not looking at the conversation.

The admin panel page subscribes with the same Pusher JS shim the frontend
layout uses (session-cookie auth at `/broadcasting/auth`), renders incoming
member messages through `GET /admin/help-chat/{id}/message-html`, and posts
replies with `fetch` so the panel never reloads mid-conversation.

### Unread bookkeeping

Two counters on the thread, each touched only by its own side:

* `admin_unread_count` — badges the panel list and the sidebar entry.
* `user_unread_count` — badges the app's drawer Help tile.

Opening the conversation on either side zeroes that side's counter and marks
the rows seen.

### Deployment

1. Run `php artisan migrate` (or apply `sqlupdates/v57.sql` by hand, the
   CyberPanel way).
2. Nothing else: the feature uses the existing Pusher settings
   (`chat_realtime_enabled`, `pusher_app_key`, `pusher_app_cluster`) and the
   existing FCM v1 service account. If realtime is off, both sides fall back
   to polling and nothing breaks.

## Flutter app

| Piece | File |
|---|---|
| Endpoints | `lib/constants/api_endpoints.dart` (`helpChatThread`, `helpChatMessages`) |
| Model | `lib/models/help_chat_model.dart` |
| Repository | `lib/repositories/help_chat_repository.dart` |
| Controller | `lib/controllers/help_chat_controller.dart` |
| Screen | `lib/features/help_center/views/help_chat_view.dart` |
| Realtime | `lib/core/services/pusher_chat_service.dart` gained `subscribeToHelpChannel` / `unsubscribeHelpChannel` / `onHelpChatMessage` |
| Push routing | `lib/core/services/notification_service.dart` — `type: help_chat` opens the Help Center (checked **before** the generic chat matcher, which `help_chat` would otherwise satisfy) |
| Drawer button | `lib/features/auth/views/home_view.dart` — "HamQadam Help Center" with an unread badge |
| Wiring | `lib/core/dependency/app_dependencies.dart` (permanent controller), `lib/controllers/auth_controller.dart` (reset on logout), `lib/core/services/app_lifecycle_service.dart` (resume/background) |

The controller mirrors `ChatController`: optimistic send bubbles, socket-first
delivery with an adaptive fallback poller (6s when realtime is down, 60s
reconcile when it is up, nothing in the background), and idempotent ingest so
the same broadcast arriving on two channels is applied once.

`flutter analyze` is clean for every file above (the repo's pre-existing lint
count is unchanged).

## Local run (XAMPP, 2026-09-08) — verified working

The backend was run locally against XAMPP (Apache + MySQL + PHP 8.2) and the
whole flow was exercised end to end. Four environment issues were found and
fixed:

1. **`Class "Pdo\Mysql" not found`** — Laravel 12 executes the *vendor*
   framework's `config/database.php` as the base for config merging, and it
   used the PHP 8.4+ `\Pdo\Mysql::ATTR_SSL_CA` alias. Patched
   `vendor/laravel/framework/config/database.php` (mysql + mariadb blocks) to
   use the version guard
   `(PHP_VERSION_ID >= 80500 ? \Pdo\Mysql::ATTR_SSL_CA : PDO::MYSQL_ATTR_SSL_CA)`
   — the same replacement nunomaduro/collision's `fix-pdo-constant.php`
   performs on PHP >= 8.5. The app-level `config/database.php` was switched to
   the classic constant outright.
2. **storage permissions** — Apache's `daemon` user could not write
   `storage/logs`, turning every error into a bare 500. Fixed with
   `chmod -R a+rwX storage bootstrap/cache`.
3. **`deleted_at` missing** — both models use `SoftDeletes` but the migration
   did not create the column. Added `$table->softDeletes()` to both tables in
   the migration and `sqlupdates/v57.sql`, and `ALTER TABLE`-ed the live local
   DB.
4. **Broadcast fatals** — `HelpChatMessageSent` referenced `User` and
   `Upload` without imports, and `HelpChatMessageResource` treated a
   `whenLoaded()` `MissingValue` as truthy. Both fixed; broadcasts now log
   `Broadcasting [help-message-sent] on channels [private-help-chat.1,
   private-App.User.{id}]`.

Verified locally: migration ran, member token created a thread and sent
messages through the real HTTPS endpoints, admin reply incremented the
member's unread badge and broadcast on the member's private channel (FCM
skipped only because the test user had no device token), and both admin views
render with the sidenav entry.

> NOTE: the vendor patch in (1) is inside `vendor/` and will be lost on
> `composer install`/`update` — if this machine regenerates vendor, re-apply
> it (or upgrade XAMPP's PHP to >= 8.4, where the alias exists natively).
