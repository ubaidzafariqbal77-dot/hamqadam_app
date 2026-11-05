# Package purchase — card payment testing guide

Verified end-to-end locally: a real Stripe **test-mode** charge on the hosted
Stripe page paid for a package, and the backend then set
`members.current_package_id`, `users.membership = 2`, the coin/allowance
counters and `package_validity`; `GET /api/v1/payments/current` reported the
package **active**.

---

## 1. Start the local backend (XAMPP)

```bash
# needs admin (starts Apache + MySQL + ProFTPD)
/Applications/XAMPP/xamppfiles/xampp start
```

- Backend root: `/Applications/XAMPP/xamppfiles/htdocs/hamqadam_live`
- API base: `http://localhost/hamqadam_live/public/api/v1`
- Admin panel: `http://localhost/hamqadam_live/public/admin`
- MySQL CLI: `/Applications/XAMPP/xamppfiles/bin/mysql -uroot hamqadam`

Stripe must be in test mode locally:

```dotenv
# hamqadam_live/.env
STRIPE_KEY="pk_test_..."
STRIPE_SECRET="sk_test_..."
```

and Stripe switched on in **Admin → Payment methods** (`stripe_payment_activation = 1`).

## 2. Point the Flutter app at the local backend

The app points at production unless you override the base URL. Use the
`API_BASE_URL` dart-define added for exactly this:

```bash
# iOS simulator (also desktop)
flutter run --dart-define=API_BASE_URL=http://localhost/hamqadam_live/public

# Android emulator (the host machine is 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2/hamqadam_live/public

# physical phone on the same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://<your-Mac-LAN-IP>/hamqadam_live/public
```

`DEMO_LOCAL=true` still works as the Android-emulator shorthand. When neither
is passed the app talks to `https://hamqadam.com`.

## 3. Log in

Seeded demo members all use password `password`:

| Email | Password |
| --- | --- |
| `demo.user@hamqadam.test` | `password` |
| `ayesha.khan@hamqadam.test` | `password` |
| `fatima.ahmed@hamqadam.test` | `password` |

## 4. Buy a package with a card

1. Open **Membership Plans**.
2. Pick a paid plan (Silver / Gold / Platinum) → **Subscribe**.
3. Keep **Credit / Debit Card (Stripe)** selected → **Pay … with Card**.
4. Stripe's hosted page opens in the in-app browser. Enter a **test card**
   (below) and tap **Pay**.
5. Stripe shows *Payment received*; return to the app. It polls
   `GET /payments/checkout/{id}/status` and flips to *Payment confirmed*, then
   the plan becomes **Currently Active**.

### Stripe test cards (test mode only)

| Card number | What it does |
| --- | --- |
| `4242 4242 4242 4242` | ✅ Successful Visa charge |
| `5555 5555 5555 4444` | ✅ Successful Mastercard |
| `4000 0025 0000 3155` | ✅ Requires 3-D Secure — complete the popup |
| `4000 0000 0000 0002` | ❌ Card declined |
| `4000 0000 0000 9995` | ❌ Insufficient funds |

For all of them:

- **Expiry**: any future date, e.g. `12 / 34`
- **CVC**: any 3 digits, e.g. `123`
- **Name / country / postal**: anything

## 5. Confirm activation

```
GET /api/v1/payments/current      → current_package + is_active: true
GET /api/v1/payments/history      → the payment row, status Paid
```

In MySQL:

```sql
SELECT u.id, u.membership, m.current_package_id, m.remaining_interest,
       m.package_validity
FROM users u JOIN members m ON m.user_id = u.id
WHERE u.email = 'demo.user@hamqadam.test';
-- membership flips 1 → 2, current_package_id → the bought plan,
-- coins increase by the plan's allowance, package_validity → today + validity
```

---

## 6. Real (live) cards

Test cards only work with test keys. To take **real** money:

1. Put **live** keys in the production `.env`:
   `STRIPE_KEY="pk_live_..."`, `STRIPE_SECRET="sk_live_..."`.
2. Keep Stripe activated in admin payment settings.
3. Make sure the Stripe account is **approved for live charges** and supports
   the billed currency (`PKR` — the app sends PKR for packages).
4. (Optional, recommended) Enable the signed webhook — see below.

The live charge path is identical to what was verified here: the hosted Stripe
page takes the card, and the app's status poll confirms the charge server-side
(secret key, amount **and** currency re-checked) before the package is
activated. The webhook is only a backup.

### Stripe webhook secret

`POST /api/v1/payments/webhooks/stripe` now **verifies Stripe's signature**
before it will mark a payment paid. Add the endpoint secret so Stripe's
deliveries are accepted:

```dotenv
# hamqadam_live/.env  (or Admin settings key STRIPE_WEBHOOK_SECRET)
STRIPE_WEBHOOK_SECRET="whsec_..."
```

Without it the endpoint answers `503 Stripe webhook is not configured.` — which
is intentional and harmless, because activation happens through the app's
status polling, not the webhook.

---

## 7. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| App can't reach the backend | Missing `--dart-define=API_BASE_URL=...`; on iOS use `localhost`, on Android the emulator use `10.0.2.2`. |
| "Card checkout could not be started" | Stripe keys missing/wrong, or `stripe_payment_activation != 1`. |
| Checkout page opens but never confirms | The app must keep polling `checkout/{id}/status`; confirm Stripe keys are the ones the session was created with. |
| Webhook returns 503 | `STRIPE_WEBHOOK_SECRET` not set (expected). |
| Webhook returns 400 | Signature mismatch — wrong `whsec_` for this endpoint. |
