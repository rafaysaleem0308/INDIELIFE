# IndieLife Deployment Guide

This project deploys as three services:

- Render backend API: `INDIELIFE-main/backend`
- Render AI API: `Ai model fyp`
- Vercel admin dashboard: `INDIELIFE-main/admin-panel`

Do not commit `.env` files. Add secret values only in Render/Vercel dashboards.

## 1. Pre-Deployment Checklist

- MongoDB Atlas cluster is created.
- Atlas Network Access allows Render to connect. For first deployment/testing, `0.0.0.0/0` is simplest; tighten later if your Render plan gives stable outbound IPs.
- Cloudinary cloud is created.
- Gmail App Password is configured.
- Admin user has been seeded locally into Atlas with `node seedAdmin.js`.

## 2. Push Code To GitHub

Render and Vercel should deploy from a GitHub repo. Commit the source changes, but do not commit `.env`.

Recommended files to include:

- `render.yaml`
- `INDIELIFE-main/backend/.env.example`
- `INDIELIFE-main/admin-panel/.env.example`
- `INDIELIFE-main/admin-panel/vercel.json`
- Backend, Flutter, admin, and AI code changes.

## 3. Deploy Backend And AI On Render

1. Open Render.
2. Create a new Blueprint from the GitHub repo.
3. Select the root `render.yaml`.
4. Render should create:
   - `indielife-backend`
   - `indielife-ai-model`
5. Fill every `sync: false` environment variable in the Render dashboard.

Backend environment variables:

```env
NODE_ENV=production
PUBLIC_API_URL=https://indielife-backend.onrender.com
MONGO_URI=<mongodb-atlas-uri>
JWT_SECRET=<jwt-secret>
EMAIL_USER=<gmail-address>
EMAIL_PASS=<gmail-app-password>
ADMIN_EMAIL=admin@gmail.com
ADMIN_PASSWORD=<admin-password>
ADMIN_ORIGIN=<vercel-admin-url-after-vercel-deploy>
MOBILE_ORIGIN=
FRONTEND_ORIGIN=
CLOUDINARY_CLOUD_NAME=<cloudinary-cloud-name>
CLOUDINARY_API_KEY=<cloudinary-api-key>
CLOUDINARY_API_SECRET=<cloudinary-api-secret>
STRIPE_SECRET_KEY=<stripe-secret-key>
STRIPE_PUBLISHABLE_KEY=<stripe-publishable-key>
STRIPE_WEBHOOK_SECRET=<stripe-webhook-secret>
PLATFORM_COMMISSION_PERCENT=10
```

AI service environment variables:

```env
AI_ALLOWED_ORIGINS=*
AI_AUTO_TRAIN=false
```

After deploy, verify:

- `https://indielife-backend.onrender.com/health`
- `https://indielife-ai-model.onrender.com/api/health`

## 4. Deploy Admin Dashboard On Vercel

1. Open Vercel.
2. Import the same GitHub repo.
3. Set Root Directory to:

```text
INDIELIFE-main/admin-panel
```

4. Confirm build settings:

```text
Build Command: npm run build
Output Directory: dist
Install Command: npm install
```

5. Add environment variable:

```env
VITE_API_URL=https://indielife-backend.onrender.com/api
```

6. Deploy.
7. Copy the Vercel project URL.
8. Go back to Render backend environment variables and set:

```env
ADMIN_ORIGIN=<vercel-admin-url>
```

9. Redeploy the Render backend after setting `ADMIN_ORIGIN`.

## 5. Flutter Build/Run Against Production

Use Dart defines:

```bash
flutter run --dart-define=API_BASE_URL=https://indielife-backend.onrender.com --dart-define=AI_BASE_URL=https://indielife-ai-model.onrender.com --dart-define=STRIPE_PUBLISHABLE_KEY=<stripe-publishable-key>
```

For release APK:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://indielife-backend.onrender.com --dart-define=AI_BASE_URL=https://indielife-ai-model.onrender.com --dart-define=STRIPE_PUBLISHABLE_KEY=<stripe-publishable-key>
```

## 6. Smoke Tests

Backend:

- Open `/health`.
- Login as admin from admin dashboard.
- Create a test user.
- Create a test service with image upload.
- Confirm uploaded image URL is Cloudinary.

Admin:

- Login.
- Check Dashboard, Users, Providers, Services, Housing, Bookings, Payments, Chats, Settings.
- Refresh a deep route and confirm Vercel rewrite works.

Flutter:

- Login/signup.
- Load services.
- Upload profile/service image.
- Open AI budget recommendation.
- Confirm Stripe test flow reaches backend.

## 7. Known Follow-Up

- Flutter analyzer still reports existing lint/style debt. This is not a deployment blocker but should be cleaned in a separate pass.
- Admin JS bundle currently builds with a large chunk warning. It is not a deployment blocker.
