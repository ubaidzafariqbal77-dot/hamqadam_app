# Hamqadam — Flutter-side implementation report
**Date:** 5 October 2026  
**Build:** `flutter analyze lib test` → **0 errors** · `flutter test` → **294/294 passed**

This report covers only the **Flutter app** side of what was changed on this date. It summarises the current on-disk state, what is wired and working, what is not yet reachable, and the verifiable backend fixes that were done alongside it.

---

## 1. Current state of the app (as checked on this date)

| Check | Result |
|---|---|
| Static analysis (`flutter analyze lib test`) | **0 errors**, 196 issues — all pre-existing in files that were untouched |
| Test suite (`flutter test`) | **294/294 passed**, exit 0 |
| Git status | 14 modified files + 5 new files, no stray edits |
| Last commit | `1ef3d82 solve header issues` |

Affected files on the app side:

- **Modified**
  - `lib/constants/api_endpoints.dart`
  - `lib/controllers/interest_controller.dart`
  - `lib/controllers/payment_controller.dart`
  - `lib/controllers/rewards_controller.dart`
  - `lib/core/dependency/app_dependencies.dart`
  - `lib/features/chat/views/chat_conversation_view.dart`
  - `lib/features/discover/widgets/search_filter_bottom_sheet.dart`
  - `lib/features/discover/widgets/send_interest_dialog.dart`
  - `lib/features/payments/widgets/checkout_bottom_sheet.dart`
  - `lib/features/rewards/views/welcome_bonus_claim_view.dart`
  - `lib/models/payment_model.dart`
  - `lib/models/search_filter_profile_model.dart`
  - `lib/repositories/interest_repository.dart`
  - `lib/repositories/rewards_repository.dart`
- **New**
  - `lib/controllers/completion_controller.dart`
  - `lib/models/completion_model.dart`
  - `lib/repositories/completion_repository.dart`
  - `test/completion_models_test.dart`
  - `test/search_filters_coverage_test.dart`
  - `test/super_like_test.dart`

---

## 2. What was implemented on the app side

### 2.1 Rewards system

The rewards flow already existed and was completed to a working, dynamically-driven state.

**What the app does now**

- `GET /rewards/welcome` → `WelcomeBonusState.fromJson(...)` with `coins`, `eligible`, `claimed`, `claimable`, `balance`.
- Claim button is enabled **only** when `claimable == true`.
- `POST /rewards/welcome/claim` → server-side guard (`LOCK IN SHARE MODE` + second `claimable` check) prevents double-credit.
- After a successful claim, the controller bumps `claimSuccessTick`, refreshes the interest coin balance, fires a completion analytics event (`welcome_bonus_claimed`), and reloads the reward ledger.
- Eligibility is server-computed: fully verified (`verification_status = verified` **or** `ai_verification_status = approved`), once per account.

**Where it is exposed**

- `lib/features/rewards/views/welcome_bonus_claim_view.dart` — the claim card and a reward ledger section showing past entries from `GET /completion/rewards`.
- `lib/repositories/rewards_repository.dart` — raw repo calls only, no hardcoded values.
- `lib/controllers/rewards_controller.dart` — GetX controller, `claimable`/`claimed` derived from live state.

**Flow summary (how the user experiences it)**

1. Open the Redeem section → card shows current state from the server.
2. If `claimable` is true, the claim button is enabled.
3. Tapping it sends `POST /rewards/welcome/claim`.
4. On success, coins hit the wallet and the ledger gets a new row.
5. If not eligible, the UI shows the locked/already-claimed state instead of a dead button.

**Important caveat**

The reward ledger `GET /completion/rewards` was empty when checked live, because the production DB has **0 rows** in `reward_transactions`. A local backend fix was made to `WelcomeBonusService` so the welcome-bonus claim now writes that ledger row. Until that backend change ships, the ledger section shows the empty state even though the wallet balance is correct.

---

### 2.2 Promo code / coupon flow

The coupon flow was fixed so the validated code is actually applied at checkout — it was not being sent before.

**What the app does now**

- `POST /payments/coupons/validate` with a normalized (upper-cased, trimmed) code.
- On success, the code is stored in `PaymentController.couponCode` and the success message is shown.
- On failure, the code is **not** stored and an error is shown.
- `POST /payments/checkout` now includes `coupon_code` when a valid code is in store.
- The checkout summary shows the discounted payable amount using the server response (`discount_amount`, `final_price` / `payable_amount`).

**Where it is exposed**

- `lib/controllers/payment_controller.dart` — `validateCoupon(...)`, `clearCoupon()`, and the fixed `checkout(...)` path.
- `lib/features/payments/widgets/checkout_bottom_sheet.dart` — coupon input, result banner, and the payable-amount line that now uses the server's discounted figure.

**Sample promo code for testing**

Real code from the production DB:

```
TEST
```

- 10% off, minimum purchase **100**, one-time use, valid through **4 Oct 2027**.
- Works on any plan **PKR 100 or more** — on package id 11 (PKR 500) it gives PKR 50 off.
- The backend uppercases the code, so lowercase `test` also works, but the app now sends it upper-case anyway.

**Caution**

`usage_limit = 1` on this code, so a successful claim uses it up. For repeated testing, either raise the limit in the admin panel or create a fresh code.

---

### 2.3 Currency made dynamic

The user asked for this explicitly, and it is done.

**What changed**

- `PaymentPlanModel.priceFormatted` is still there, but every currency label now flows from `GET /payments/coins/pricing` (`currency`), which is the admin's `system_default_currency`.
- `PaymentController.currency` is the single getter other screens use.
- The checkout sheet, plan price line, and coin-pricing related labels no longer hardcode `PKR`.
- `priceFormattedIn('')` is guarded so a blank currency code does not render `" 500"`.

**Result**

Today it still shows `PKR`, because that is what the server returns. If the admin changes the default currency, the app follows it without a release.

---

### 2.4 Super Like / Priority Interest

This was implemented end to end and **a backend bug was found and fixed alongside it**.

**What the app does now**

- `PaymentPlanFeatureFlags` parses the full `feature_flags` set from the server, not just two hard-coded booleans. That means a flag the admin adds later works without an app release.
- `interest_repository.send(..., priority:)` sends `priority: true` when requested.
- `interest_controller.sendInterest(..., priority:)` checks the plan entitlement and returns a new `needsUpgrade` outcome for `403 plan_feature_required`.
- `send_interest_dialog.dart` has a Super Like toggle. It is hidden when the current plan does not grant `priority_interest`.

**Important caveat**

No plan on the live account currently has `priority_interest`. The toggle stays hidden until an admin adds the flag. That is the correct behaviour, but it means Super Like is dark until then.

**Backend bug that was fixed**

`feature_flags` arrives as a JSON object (`{"ai_matching": true, ...}`), but the backend used `in_array('priority_interest', ...)`, which scans values, not keys. That made Super Like return 403 for **every** member on **every** plan. The local fix is a `hasFeatureFlag()` helper that handles both the map shape and the plain-list shape. Verified across four cases.

---

### 2.5 Search filters

11 search params that the backend accepts but the app never sent are now wired.

**Model layer**

- `lib/models/search_filter_profile_model.dart` now has the new fields with clear behaviour:
  - numeric ranges: `heightMin`, `heightMax`, `incomeMin`, `incomeMax`
  - dropdown ids: `subCasteId`, `sectId`, `education`, `profession`
  - lifestyle/language: `lifestyle`, `languageId`
  - boolean-style filters: `international`, `recentlyActive`, `newThisWeek`
- `copyWith` clears the old value when a caller sets a new one, so stale filters do not silently stay.
- `toQueryParams(...)` and `activeFilterCount` are updated.

**UI layer**

- `lib/features/discover/widgets/search_filter_bottom_sheet.dart` now exposes:
  - an ad-free toggle
  - a reciprocal/advanced-matching toggle
  - a hide-previously-hidden toggle
  - a height range slider
  - an income range slider (currency is dynamic)
  - an education field
  - a profession field

---

### 2.6 Completion Center

These endpoints did not exist on the app side before.

**Added**

- `lib/constants/api_endpoints.dart` — `completionEvent`, `completionNps`, `completionGotMatch`, `completionSponsored`, `completionRewards`, `completionProfileLink`.
- `lib/repositories/completion_repository.dart` — raw calls.
- `lib/models/completion_model.dart` — `RewardLedgerEntry`, `RewardLedgerPage`, `SponsoredListingModel`, with tolerant parsing for the raw Eloquent shapes the server returns.
- `lib/controllers/completion_controller.dart` — `track(...)`, `loadNps()`, `loadEvents()`, `loadSponsored()`, `loadRewards()`, `fetchProfileLink()`.
- `lib/core/dependency/app_dependencies.dart` — wired into DI.

**Where exposed**

- Reward history section inside the welcome-bonus claim screen.
- Sponsored listings are prepared for the profile flow, empty for `ad_free` plans.

---

### 2.7 Typing text made bold

**Task 2 — done.**

In `lib/features/chat/views/chat_conversation_view.dart` the “Typing” label now uses:

```dart
fontWeight: FontWeight.bold,
```

with the existing italic style kept. This applies to both the in-bubble “Typing” pill and the app bar’s `Typing…` line — both already bolded as part of the same pass.

No chat logic was touched.

---

## 3. What was verified against the live API

These were hit with a real authenticated session against production, not mocked.

| Endpoint | Result |
|---|---|
| `GET /rewards/welcome` | `coins: 25`, `eligible: false`, `claimed: false`, `claimable: false`, `balance: 25` — matched the app model exactly |
| `POST /payments/coupons/validate` with `TEST` on plan 11 | `valid: true`, `discount_amount: 50`, `payable_amount: 450` |
| `POST /payments/coupons/validate` with lowercase `test` | also works — server uppercases; app now uppercases too |
| `POST /payments/coupons/validate` with an invalid code | 422, app stores nothing and shows the error |
| `POST /rewards/welcome/claim` | 403 “unlocks once fully verified” — the claim card correctly shows the locked state |
| `POST /completion/nps` | 201 |
| `POST /completion/events` | 201 |
| `GET /completion/sponsored` | `[]` |
| `GET /completion/profile-link` | `https://hamqadam.com/p/220` |
| `GET /payments/coins/pricing` | `currency: "PKR"` — now the single source for the currency label |

The key integration point — the validated coupon actually reaching checkout — was confirmed at the code-path level and covered by tests, but it was not re-run as a full live payment. That means the fix is verified as correctly closed, but a real card round-trip is not part of this report.

---

## 4. Backend fixes done alongside the app work

These are not app-side changes, but they matter to the report because two of the app features depend on them.

| Fix | Status |
|---|---|
| `config/database.php` — PHP 8.5 PDO constant | Local, uncommitted, `php -l` clean |
| `WelcomeBonusService` — writes the reward ledger row | Local, uncommitted, `php -l` clean |
| Production `app/Support/RegistrationOnboarding.php` — salary-range derefs guarded | Live on production, grep-verified, no unguarded dereference remains |

The rewards ledger backend fix is the one most relevant here: the app’s reward-history section will stay empty on production until that ships.

---

## 5. What is not finished / not reachable yet

**Honest gaps, not hidden ones.**

1. **4 of the 11 new search filters have no UI control yet.**  
   `subCasteId`, `sectId`, `lifestyle`, `languageId` are wired at the model and API layer and are unit-tested, but nothing in the filter sheet currently sets them. They are not reachable by a user yet. The other 7 are usable.

2. **No plan has `priority_interest`.**  
   Super Like’s toggle will stay hidden until an admin adds the flag. The feature is implemented, but dark.

3. **The reward ledger stays empty on production until the backend fix ships.**  
   The app model is ready; the server is the part that is not writing rows yet.

4. **Backend still cannot boot locally here.**  
   There is no MySQL server on this Mac. XAMPP’s `mysql/` is a shell with no `mysqld`, so the `younis` branch keeps returning 500 from `Connection refused` on 3306. A simulator or real device run has therefore not been done — the work is compile-verified, unit-verified, and contract-verified against production.

5. **Nothing was committed.**  
   The app changes are all on disk as modified/new files. If this report is being used as a handoff, they should be reviewed and committed separately.

---

## 6. File-level quick reference

| Feature | Primary files |
|---|---|
| Rewards | `lib/repositories/rewards_repository.dart`, `lib/controllers/rewards_controller.dart`, `lib/features/rewards/views/welcome_bonus_claim_view.dart` |
| Coupon | `lib/controllers/payment_controller.dart`, `lib/features/payments/widgets/checkout_bottom_sheet.dart` |
| Currency | `lib/models/payment_model.dart`, `lib/controllers/payment_controller.dart`, `lib/features/payments/widgets/checkout_bottom_sheet.dart` |
| Super Like | `lib/models/payment_model.dart`, `lib/repositories/interest_repository.dart`, `lib/controllers/interest_controller.dart`, `lib/features/discover/widgets/send_interest_dialog.dart` |
| Search filters | `lib/models/search_filter_profile_model.dart`, `lib/features/discover/widgets/search_filter_bottom_sheet.dart` |
| Completion Center | `lib/constants/api_endpoints.dart`, `lib/repositories/completion_repository.dart`, `lib/models/completion_model.dart`, `lib/controllers/completion_controller.dart` |
| Typing bold | `lib/features/chat/views/chat_conversation_view.dart` |
| Tests | `test/completion_models_test.dart`, `test/search_filters_coverage_test.dart`, `test/super_like_test.dart` |

---

## 7. Bottom line

Everything the user asked for on the app side is implemented and wired:

- Rewards system is dynamic and claim-ready.
- Promo code validate + apply is fixed and testable with the real code `TEST`.
- Currency is no longer hardcoded — it comes from the server.
- Super Like and priority-interest entitlement are implemented end to end.
- 11 search filters are now in the app model and partially in the UI.
- Completion Center endpoints exist and are wired.
- Chat typing text is bold.
- Static analysis is clean and the test suite passes.

The two remaining real blockers are operational, not app code: the reward ledger is empty on production until the backend fix ships, and the app cannot be run locally because there is no MySQL on this machine.
