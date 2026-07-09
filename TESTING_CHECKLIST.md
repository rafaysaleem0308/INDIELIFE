# IndieLife Production Test Checklist

Use disposable records only. Prefix test names with `TEST DO NOT USE`.

## Deploy Sync
- Render backend `/health` returns OK.
- Render AI `/api/health`, `/health`, and `/` return OK.
- Vercel admin opens `https://indielife.vercel.app` and refreshes direct routes.
- Vercel `VITE_API_URL` is `https://indielife-backend.onrender.com/api`.
- Render backend `ADMIN_ORIGIN` is `https://indielife.vercel.app`.

## Backend Smoke
- Public service routes return successful JSON.
- Protected routes return 401 without a token.
- Invalid login returns a clean JSON error.
- Admin login returns an access token.
- Admin dashboard, users, providers, services, housing, bookings, payments, chats, and settings load.

Run:

```powershell
$env:ADMIN_TEST_EMAIL="admin@gmail.com"
$env:ADMIN_TEST_PASSWORD="<admin password>"
node scripts/production-smoke.mjs
```

## Disposable App Flow
- Send signup OTP to a disposable user email.
- Verify OTP and create a user account.
- Login as the disposable user.
- Create a disposable service provider account.
- Approve provider in admin.
- Add one disposable meal/laundry/maintenance/housing service.
- Upload at least one image and confirm it uses a Cloudinary URL.
- Browse the service in Flutter.
- Create a booking/order.
- Start a chat.
- Create a Stripe test payment intent and confirm the test payment flow.
- Delete or mark all disposable records inactive after testing.

## APK Flow
- Build APK with deployed URLs.
- Install on Android phone or emulator.
- Confirm login/signup, service browsing, image rendering, housing, chat, orders, payments, notifications, and AI budget screen.
