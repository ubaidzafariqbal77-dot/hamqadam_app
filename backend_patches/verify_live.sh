#!/usr/bin/env bash
# Checks the live backend for the three things mobile calling depends on.
# Prints verdicts only — your token is never echoed.
#
#   chmod +x backend_patches/verify_live.sh
#   ./backend_patches/verify_live.sh 'ayesha@example.com' 'Password123!'
#
# Paste the OUTPUT back. It contains no password and no token.
set -u

BASE="https://hamqadam.com"
API="$BASE/api/v1"
EMAIL="${1:?usage: verify_live.sh <email> <password>}"
PASS="${2:?usage: verify_live.sh <email> <password>}"

j() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)" 2>/dev/null; }

echo "== 0. login =="
LOGIN=$(curl -s -X POST "$API/auth/login/email" \
  -H 'Accept: application/json' -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"device_type\":\"android\"}")
TOKEN=$(printf '%s' "$LOGIN" | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
x=d.get('data') or {}
print(x.get('token') or x.get('access_token') or (x.get('data') or {}).get('token') or '')
" 2>/dev/null)
USER_ID=$(printf '%s' "$LOGIN" | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: print(0); raise SystemExit
x=(d.get('data') or {}); u=x.get('user') or {}
print(u.get('id') or 0)
" 2>/dev/null)

if [ -z "${TOKEN:-}" ]; then
  echo "FAIL — could not log in. Response keys:"
  printf '%s' "$LOGIN" | j "list(d.keys())"
  printf '%s' "$LOGIN" | j "d.get('message')"
  exit 1
fi
echo "OK — logged in, user id = $USER_ID  (token length ${#TOKEN}, not shown)"

AUTH="Authorization: Bearer $TOKEN"

echo
echo "== 1. /broadcasting/auth accepts the app's bearer token =="
echo "   (needs Broadcast::routes(['middleware' => ['web','auth:sanctum']]))"
CODE=$(curl -s -o /tmp/hq_bcast.txt -w '%{http_code}' -X POST "$BASE/broadcasting/auth" \
  -H "$AUTH" -H 'Accept: application/json' \
  --data-urlencode "socket_id=1234.5678" \
  --data-urlencode "channel_name=private-App.User.$USER_ID")
if [ "$CODE" = "200" ]; then
  echo "   PASS ($CODE) — private channels will work on mobile"
else
  echo "   FAIL ($CODE) — mobile receives NO chat and NO call events until this is fixed"
  head -c 200 /tmp/hq_bcast.txt; echo
fi

echo
echo "== 2. /bridge/connector-a gives the app a usable Pusher key =="
BR=$(curl -s "$API/bridge/connector-a" -H "$AUTH" -H 'Accept: application/json')
printf '%s' "$BR" | python3 -c "
import sys,json
d=json.load(sys.stdin); x=d.get('data') or {}
pub=x.get('public') or {}
key=str(pub.get('app_key') or '')
print('   enabled      :', x.get('enabled'))
print('   cluster      :', pub.get('cluster'))
print('   app_key set  :', bool(key), '(prefix', key[:6]+'…)' if key else '(empty)')
print('   app_id       :', pub.get('app_id'))
if not x.get('enabled'): print('   FAIL — app falls back to polling; set chat_realtime_enabled = 1')
elif not key:            print('   FAIL — pusher_app_key is empty in admin settings')
else:                    print('   PASS — but confirm this app_id matches PUSHER_APP_ID in .env')
" 2>/dev/null || { echo "   could not parse:"; head -c 300 <<<"$BR"; echo; }

echo
echo "== 3. annual_salary_ranges labels (for registration step 10) =="
curl -s "$API/profile/dropdown-reference-data" -H "$AUTH" -H 'Accept: application/json' \
 | python3 -c "
import sys,json
d=json.load(sys.stdin); x=d.get('data') or {}
r=x.get('annual_salary_ranges')
if r is None:
    print('   MISSING — backend must expose this key; the app cannot label ids it is never told the names of')
    print('   lists served:', len(x))
else:
    print('   PASS — copy this straight into SalaryRangeOptions.bands:')
    print(json.dumps(r, indent=2, ensure_ascii=False))
" 2>/dev/null

echo
echo "== 4. does a call push exist at all? =="
echo "   (FirbaseNotification uses the legacy fcm/send endpoint, retired 20 Jun 2024 → 404)"
curl -s -o /dev/null -w "   legacy fcm/send now answers: %{http_code}\n" \
  -X POST https://fcm.googleapis.com/fcm/send -H 'Authorization: key=probe' \
  -H 'Content-Type: application/json' -d '{"to":"x"}'
