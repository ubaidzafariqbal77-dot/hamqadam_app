# Backend notes for mobile calling & push

Verified against, and **applied to**, the live source at
`/Applications/XAMPP/xamppfiles/htdocs/hamqadam_live/` on 2026-09-02.
Every change below is in git there, so `git diff` shows it and `git checkout`
reverts it.

---

## Why push looked broken on the phone

The symptom was: notifications arrive while the app is open, and nothing at all
once it is closed.

That shape is diagnostic. While the app is open it has the Pusher socket and the
notifications poller, neither of which needs FCM — so "works when open" said
nothing about push. Once closed, only FCM can reach the device, and
`storage/logs/laravel.log` had the answer:

```
FCM v1: API returned error. {"status":400,
  "message":"The registration token is not a valid FCM registration token"}
```

The send was working. The **token** was wrong, because `users.fcm_token` is a
single column with two writers:

| Writer | Wrote |
|---|---|
| App → `POST /api/v1/notifications/push-tokens` | the phone's real FCM token |
| Website → `POST /fcm-token` → `HomeController::updateToken` | whatever the browser posted, **unvalidated** |

The site's Firebase JS is configured from `FCM_API_KEY`, `FCM_PROJECT_ID`,
`FCM_MESSAGING_SENDER_ID`, `FCM_APP_ID` — all empty strings in `.env`. So
`messaging.getToken()` there produces nothing usable, it was stored anyway, and
it replaced the phone's token. From that moment the member was unreachable on
mobile, and the only trace was the 400 above.

---

## Applied

### 1. Pushes go to every device, not to one shared column

`FcmV1Service` gained `tokensForUser()`, which reads the union of the
`user_push_tokens` rows (the real per-device register the app writes, which no
sender was reading) and the legacy `users.fcm_token` column, de-duplicated. On
top of it: `sendToUser()`, `sendDataToUser()`, `sendCallPushToUser()` and
`sendCallEndedToUser()`.

Every sender was moved over — `CallService`, `ChatApiService`,
`NotificationHelper`, `InterestService` — and each one's
`if (empty($user->fcm_token)) return;` guard was removed, because that column
being empty or stale never meant the member had no reachable device.

Phone and browser are now both reachable, and neither overwrites the other.

### 2. Dead tokens are pruned instead of failing forever

`FcmV1Service::forgetDeadToken()` runs when Google rejects a token — 404
`UNREGISTERED`, or 400 `not a valid FCM registration token` — and deletes it
from `user_push_tokens` and nulls it out of `users.fcm_token`.

This is what makes the situation above self-healing: the bad web token is
dropped on its first failed send, and the app's real token keeps working.

### 3. The website registers properly

`HomeController::updateToken` now rejects an empty token with 422 and writes a
`user_push_tokens` row with `platform: web` (it still keeps the legacy column in
step for anything else reading it). The browser's token no longer displaces the
phone's, and a misconfigured page can no longer poison the column.

### 4. One push per chat message

`ChatApiService::send()` was sending two: its own `sendChatFcmPush`, plus
another from `NotificationHelper::chatMessage`. Both carried a `notification`
block, so a backgrounded phone got **two tray entries and two buzzes** for one
message — and the app cannot de-duplicate those, because a notification-block
push is drawn by the system before any app code runs.

`createAndPush()` took a `bool $push = true` parameter and `chatMessage()` now
passes `push: false`. The surviving push is `sendChatFcmPush`, which is the only
one carrying `message_id` — the id the app keys its de-duplication on.

That payload also gained `notify_by` and `info_id` alongside `sender_id` and
`thread_id`, so one routing path in the app covers every notification type.

### 5. A call that stops ringing says so

`CallService` only pushed on `start()`, so cancelling a call left the receiver's
sleeping phone ringing for the rest of the ring window. `pushCallEnded()` now
fires from `reject()`, `cancel()` and `end()` with
`call_rejected` / `call_cancelled` / `call_ended` / `call_missed`, addressed to
whichever party did not act. The app dismisses its ringing notification on any
of them, including from the FCM background isolate with the app killed.

### 6. Logging out stops the pushes

`NotificationService::deletePushToken` deleted the `user_push_tokens` row but
left `users.fcm_token` set, and every sender read that column — so a member who
logged out **kept receiving their own messages and calls**, previews included,
on a phone that was no longer theirs. It now clears the column when it matches
the token being removed.

### 7. Activity notifications reach the phone at all

Eight controllers sent their notifications through
`FirbaseNotification::send()`, which POSTed to `https://fcm.googleapis.com/fcm/send`
— the endpoint Google retired in June 2024 — with an `Authorization: key=`
server key, and threw the result away. So express interest, profile-picture and
gallery view requests, profile views and package-payment approvals reached
nobody, and nothing in the log said so. Each call site was also gated on
`if ($notify_user->fcm_token != null)`.

Two changes, deliberately overlapping:

* `FirbaseNotification::send()` now hands the same payload to FCM v1. Where the
  token traces back to a member it uses `FcmV1Service::sendToUser`, so the push
  reaches every device in `user_push_tokens` rather than whichever one last
  wrote the shared column. **This is the one that is live on production** — it
  is a single file, which is what the CyberPanel file manager can deploy.
* Each controller's own `sendFirebaseNotification` helper now calls
  `FcmV1Service::sendToUser` directly, drops the `fcm_token != null` gate, and
  passes `info_id` through (the signature gained an optional sixth parameter;
  every call site already had `$info_id` in scope). This lands with the next
  git deploy and makes the bridge above redundant.

Affected: `HomeController`, `PackagePaymentController`,
`ViewProfilePictureController`, `ViewGalleryImageController`,
`ExpressInterestController`, `Api/ProfileController`,
`Api/ProfileImageController`, `Api/GalleryImageController`.

Note that all of these sit behind `get_setting('firebase_push_notification') == 1`.
If that admin toggle is off, none of them send whatever the code does.

---

## Still open

### Optional: put `notification_id` in activity pushes

`NotificationHelper::createAndPush` and `InterestService::notifyUser` send
`type`, `notify_by`, `info_id` and `route`, but not the id of the notification
row they have just written. The app therefore de-duplicates activity
notifications on `type` + `notify_by` + `info_id`
(`NotificationService.activityKey`), which works but is a heuristic. Adding
`'notification_id' => (string) $id` to both payloads lets it key on the row
itself, which the app prefers when present.

---

## iOS: a killed app cannot ring like Android

On Android the pieces above are enough: a high-priority data push wakes the
background isolate, which raises a full-screen ringing notification with
Accept / Decline. `showWhenLocked` / `turnScreenOn` are set on `MainActivity`
for that, and the ringtone is `res/raw/ringtone.mp3` on the `calls` channel.

iOS has no equivalent. A killed app cannot draw a ringing UI from a push; the
best available without CallKit is what the app does now — a time-sensitive
alert with Accept and Decline actions (the `hamqadam_call` notification
category). Tapping Accept launches the app and the answer is replayed from the
launch details.

Ringing an iPhone like a real phone call needs **PushKit + CallKit**: a `voip`
push type from the server, the `voip` background mode and a CallKit provider in
the app. That is separate work on both sides, and declaring the `voip`
background mode without implementing CallKit fails App Store review — so it is
deliberately not declared.

Note also that a custom iOS *tray* sound must be AIFF, WAV or CAF in the app
bundle; `UNNotificationSound` will not play an MP3. The iOS tray therefore uses
the default alert sound, while the in-app ring (which is what a foregrounded or
recently-backgrounded app plays) uses `assets/ringtone.mp3` like Android.

---

### `annual_salary_ranges` is still not served — REQUIRED for signup

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

### Push-token `platform` alias (already handled on the app side)

`StorePushTokenRequest` validates `platform`, and the app was sending
`device_type`, so `user_push_tokens.platform` was always null. The app now sends
both keys; nothing to change here unless you want to drop the alias.
