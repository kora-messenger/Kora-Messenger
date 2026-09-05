require('dotenv').config();
const express = require('express');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first'); // Render: no IPv6 egress
const cors = require('cors');
const connectDb = require('./db');

const app = express();
app.use(cors()); // Kora apps on any device; tighten to the app origin at launch.
app.use(express.json({ limit: '25mb' })); // 25mb matches the app's media upload ceiling.

// Health check — used by Render/uptime monitors and by the app's
// "connection test" diagnostics.
app.get('/health', (req, res) => {
  res.json({
    ok: true,
    service: 'kora-backend',
    time: new Date().toISOString(),
  });
});

// Auth endpoint — same path the app already calls:
//   KORA_BACKEND_URL/koraAuth
const koraAuth = require('./routes/koraAuth');
app.use('/koraAuth', koraAuth);

// User lookup — the app's contact search + profile fetch.
const koraLookup = require('./routes/koraLookup');
app.use('/koraLookup', koraLookup);
const koraLookupByEmail = require('./routes/koraLookupByEmail');
app.use('/koraLookupByEmail', koraLookupByEmail);

// The app hits these too; they arrive as the migration continues.
// Each returns a clean "not migrated yet" until its route module lands.
const PENDING = [
  'koraEmailChange', 'koraCallSignal', 'koraTranslate', 'koraGptTrans',
  'koraLinkDevice', 'koraWebPair',
  'koraCrashReport', 'koraServiceNotification', 'koraAntiSpam', 'koraUpload',
  'koraAutoDetect', 'koraInitPayment', 'koraRecoverSubscription',
  'koraVerifyPayment', 'koraChatSync', 'koraSettingsSync', 'koraAiChat',
  'koraAiFeatures', 'koraAiOrchestrator', 'koraAiConversation',
  'koraE2eeKeys', 'koraPushRegister', 'koraPushUnregister', 'koraPushSend',
];
for (const name of PENDING) {
  app.use(`/${name}`, (req, res) =>
    res.json({ success: false, error: 'This endpoint is not migrated yet.' })
  );
}

const PORT = Number(process.env.PORT || 8080);
connectDb()
  .then(() => {
    app.listen(PORT, () => console.log(`[kora-backend] listening on :${PORT}`));
  })
  .catch((err) => {
    console.error('[kora-backend] failed to start:', err.message);
    process.exit(1);
  });
