# Run Doc — HamQadam Preview Dashboard

## What this preview is

A static HTML dashboard at `.freebuff/preview.html` that shows:
- Backend health status (hits `GET /api/v1/health`)
- Pusher / realtime config (from bridge connector-a)
- FCM / push notification configuration
- Agora calling setup status
- CSRF fix status
- Interactive endpoint testing

It is a single HTML file — no build, no server, no dependencies.

## How to reproduce

1. The file `.freebuff/preview.html` is already in the workspace.
2. Register it with `register_preview(htmlPath)` for the thread's Preview tab.
3. The dashboard auto-connects to the local backend at `http://localhost/hamqadam_live`.

## How to run

```bash
# The dashboard is a static file — just open it in the preview tab.
# The backend must be running at http://localhost/hamqadam_live
# (XAMPP: start Apache + MySQL)

# To manually open:
open .freebuff/preview.html
```

## API Base URL

The dashboard defaults to `http://localhost/hamqadam_live`. Change the URL in the input field to test against a different backend (e.g., `https://hamqadam.com`).
