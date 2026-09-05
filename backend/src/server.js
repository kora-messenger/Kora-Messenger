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

// Chat + conversation persistence (sync / fetch / fetchNew / backup / clearChat).
const koraChatSync = require('./routes/koraChatSync');
app.use('/koraChatSync', koraChatSync);

// Avatar / media data-URL wrapping (stateless pass-through).
const koraUpload = require('./routes/koraUpload');
app.use('/koraUpload', koraUpload);

// Cloud settings (Telegram-style merged JSON blob per user).
const koraSettingsSync = require('./routes/koraSettingsSync');
app.use('/koraSettingsSync', koraSettingsSync);

// ── Remaining migrated services (5th migration wave — full off-Base44) ──
const koraE2eeKeys = require('./routes/koraE2eeKeys');
app.use('/koraE2eeKeys', koraE2eeKeys);
const koraPushRegister = require('./routes/koraPushRegister');
app.use('/koraPushRegister', koraPushRegister);
const koraPushUnregister = require('./routes/koraPushUnregister');
app.use('/koraPushUnregister', koraPushUnregister);
const koraPushSend = require('./routes/koraPushSend');
app.use('/koraPushSend', koraPushSend);
const koraCrashReport = require('./routes/koraCrashReport');
app.use('/koraCrashReport', koraCrashReport);
const koraServiceNotification = require('./routes/koraServiceNotification');
app.use('/koraServiceNotification', koraServiceNotification);
const koraAntiSpam = require('./routes/koraAntiSpam');
app.use('/koraAntiSpam', koraAntiSpam);
const koraAutoDetect = require('./routes/koraAutoDetect');
app.use('/koraAutoDetect', koraAutoDetect);
const koraEmailChange = require('./routes/koraEmailChange');
app.use('/koraEmailChange', koraEmailChange);
const koraInitPayment = require('./routes/koraInitPayment');
app.use('/koraInitPayment', koraInitPayment);
const koraVerifyPayment = require('./routes/koraVerifyPayment');
app.use('/koraVerifyPayment', koraVerifyPayment);
const koraRecoverSubscription = require('./routes/koraRecoverSubscription');
app.use('/koraRecoverSubscription', koraRecoverSubscription);
const koraPlayBilling = require('./routes/koraPlayBilling');
app.use('/koraPlayBilling', koraPlayBilling);
const koraTranslate = require('./routes/koraTranslate');
app.use('/koraTranslate', koraTranslate);
const koraGptTrans = require('./routes/koraGptTrans');
app.use('/koraGptTrans', koraGptTrans);
const koraAiChat = require('./routes/koraAiChat');
app.use('/koraAiChat', koraAiChat);
const koraAiConversation = require('./routes/koraAiConversation');
app.use('/koraAiConversation', koraAiConversation);
const koraAiFeatures = require('./routes/koraAiFeatures');
app.use('/koraAiFeatures', koraAiFeatures);
const koraAiOrchestrator = require('./routes/koraAiOrchestrator');
app.use('/koraAiOrchestrator', koraAiOrchestrator);
const koraCallSignal = require('./routes/koraCallSignal');
app.use('/koraCallSignal', koraCallSignal);
const koraLinkDevice = require('./routes/koraLinkDevice');
app.use('/koraLinkDevice', koraLinkDevice);
const koraWebPair = require('./routes/koraWebPair');
app.use('/koraWebPair', koraWebPair);



const PORT = Number(process.env.PORT || 8080);
connectDb()
  .then(() => {
    app.listen(PORT, () => console.log(`[kora-backend] listening on :${PORT}`));
  })
  .catch((err) => {
    console.error('[kora-backend] failed to start:', err.message);
    process.exit(1);
  });
