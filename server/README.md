# Kora Messenger Backend

Standalone Node.js / Express backend replacing Base44 for Kora Messenger.

## Prerequisites

- Node.js >= 20.x
- MongoDB instance (local or MongoDB Atlas)

## Getting Started

1. Clone or download the repository.
2. Install dependencies:
   ```bash
   npm install
   ```
3. Copy environment settings and configure variables:
   ```bash
   cp .env.example .env
   ```
4. Start the development server:
   ```bash
   npm run dev
   # or
   npm start
   ```

## Deployment Instructions

### 1. Railway
- Connect your GitHub repository to [Railway](https://railway.app/).
- Add a **MongoDB** plugin or set `MONGODB_URI` environment variable pointing to your database.
- Configure Environment Variables (`PORT`, `JWT_SECRET`, `SMTP_*`, etc.) under the **Variables** tab.
- Railway automatically detects the `Dockerfile` or `package.json` start script and deploys.

### 2. Render
- Create a new **Web Service** on [Render](https://render.com/).
- Connect your repository.
- Select **Environment**: Node.
- Set **Build Command**: `npm install`.
- Set **Start Command**: `npm start`.
- Under **Advanced**, add required environment variables from `.env.example`.
- Attach a Render PostgreSQL/MongoDB instance or provide your MongoDB Atlas URI in `MONGODB_URI`.

### 3. Fly.io
- Install `flyctl` CLI and run `fly launch` in the `/tmp/kora_server/` directory.
- `flyctl` will detect the included `Dockerfile`.
- Set secrets using:
  ```bash
  fly secrets set MONGODB_URI="mongodb+srv://..." JWT_SECRET="your_secret" OPENROUTER_API_KEY="..."
  ```
- Deploy using:
  ```bash
  fly deploy
  ```

## Endpoints

- `GET /health` - Server health status
- `/auth` - Authentication & User Management
- `/chat` - Messaging & Conversations
- `/pair` - QR Code & Device Pairing
- `/lookup` - User Discovery & Lookup
- `/ai` - AI Integrations
- `/calls` - Audio/Video Call Signaling
