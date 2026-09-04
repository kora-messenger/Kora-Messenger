# Kora Backend (Node.js + MongoDB Atlas)

Self-hosted replacement for the temporary Base44 backend functions.
The Flutter app already talks to `KORA_BACKEND_URL/<endpoint>` — pointing
that dart-define at this service swaps the backend with zero app changes.

## Run locally
```bash
cd backend
npm install
cp .env.example .env    # set MONGODB_URI from Atlas
npm start
```

## Deploy (Render, free tier)
1. New → Web Service → connect the GitHub repo → root directory `backend`.
2. Build command: `npm install` — Start command: `npm start`.
3. Add environment variables from `.env.example` (at minimum `MONGODB_URI`).
4. Deploy, then set the app's `KORA_BACKEND_URL` GitHub secret to
   `https://<service>.onrender.com`.

## Status
- ✅ koraAuth — signup, login, device verification, password reset,
  profile save/get, username check, sign-in options
- ⏳ Remaining endpoints return `not migrated yet` until their modules land.

## Domain swap
Nothing is hardcoded. The app only knows `KORA_BACKEND_URL`; when
koramessenger.com goes live, point it at this service (or redeploy there)
and update that one secret.
