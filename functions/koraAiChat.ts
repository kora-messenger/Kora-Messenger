// Kora AI Chat — v5 (OpenAI gpt-5.4-mini, free for all users)
function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' },
  });
}

const SUPPORT_PROMPT = `You are Kora Support, the official AI support assistant for Kora Messenger (a messaging app with purple-to-blue gradient design). Help users with Kora: account, login, passkeys, groups, channels, wallpapers, themes, premium, security, troubleshooting. Be warm, friendly, concise (under 100 words). Use emoji sparingly. Never invent features. If outside Kora, suggest Kora AI.

Key facts: Sign up=email+password. Login=email/passkey. Codes auto-verify. Passkeys=Settings>Security. Trusted devices need 30+ days. Groups=Home 3-dot menu>New Group. Communities=New Channel. Wallpapers=18 presets+colors+gallery, dimming. Chat bubbles=20 colors. App theme/icons=Premium. Premium=custom icons, wallpapers, bubbles, animated emoji, translation, infinite reactions, faster downloads, badge, no ads. 7-day free trial. Owner=free Premium. Badges: purple=official, blue=premium.`;

const AI_PROMPT = `You are Kora AI, a friendly assistant in Kora Messenger. Answer any question concisely (under 120 words). Be helpful, warm, and natural. Use emoji sparingly. For Kora app questions, suggest Kora Support.`;

interface FallbackEntry { keywords: string[]; response: string; }

const SUPPORT_FALLBACKS: FallbackEntry[] = [
  { keywords: ['premium','subscribe','subscription','upgrade','pay','billing'], response: 'Kora Premium: custom app icons, premium wallpapers, custom chat bubbles, animated emoji, real-time translation, infinite reactions, faster downloads, profile badge, priority support, no ads.\n\n7 days free for new users! 💜' },
  { keywords: ['password','reset','forgot'], response: 'Reset password:\n1. "Forgot password?" on login\n2. Enter email\n3. Check email for code\n4. Enter code, set new password → redirected to login 🔐' },
  { keywords: ['passkey','biometric','fingerprint','face id'], response: 'Passkeys = fingerprint/face login. Set up in Settings > Security > Passkeys. 🔐' },
  { keywords: ['group','new group'], response: 'New group: Home > 3-dot menu > New Group. Select contacts, name, set photo. 👥' },
  { keywords: ['channel','community'], response: 'New community: Home > 3-dot menu > New Channel. Name, description, preview, create. Starts with General group. 📢' },
  { keywords: ['wallpaper','background'], response: 'Wallpaper: Chat > 3-dot menu > Chat theme > Wallpaper. 18 presets, colors, gallery. Dimming supported. 🖼️' },
  { keywords: ['theme','bubble color'], response: 'Chat theme: Chat > 3-dot menu > Chat theme. Presets or custom bubble color (20 options). ✨' },
  { keywords: ['app icon'], response: 'App icon: Settings > Appearance > App Icon. Default + 2 premium. 3-dot menu to reset. Premium icons need Kora Premium. 🎨' },
  { keywords: ['avatar','profile picture'], response: 'Change avatar: Settings > Profile > tap avatar. Gallery or camera. 📸' },
  { keywords: ['qr','scan'], response: 'QR code: Settings > QR Code, or Contacts > New Contact > Scan QR. 📱' },
  { keywords: ['verify','verification','code','otp'], response: 'Codes sent to email. Auto-verify on last digit — no submit button! Auto-fill from clipboard. ✅' },
  { keywords: ['trusted device','device'], response: 'Trusted devices skip verification. Must be 30+ days old. Settings > Security > Trusted Devices. 🔒' },
  { keywords: ['block','report'], response: 'Block/report: Chat > 3-dot menu > Block or Report. 🚫' },
  { keywords: ['mute','notifications'], response: 'Mute: Chat > 3-dot menu > Mute notifications. 🔕' },
  { keywords: ['delete','clear'], response: 'Clear: Chat > 3-dot > Clear chat. Delete: long-press message > Delete. 🗑️' },
  { keywords: ['translate','translation'], response: 'Translation is Premium. Long-press message > Translate. 🌍' },
  { keywords: ['badge','verified'], response: '💜 Purple scalloped = Official Kora. 💙 Blue scalloped = Premium subscriber. ✨' },
  { keywords: ['crash','bug','error','broken','problem'], response: 'Try: force close, check updates, restart device. Crash reports sent automatically. 🙏' },
  { keywords: ['logout','sign out'], response: 'Log out: Settings > Account > Log out. 👋' },
  { keywords: ['hello','hi','hey','help'], response: 'Hi! 👋 I\'m Kora Support. Ask about account, passwords, passkeys, groups, wallpapers, themes, premium, security!' },
  { keywords: ['free','trial','expired'], response: '7 days free Premium! 🎉 After that, tap "Subscribe to Kora Premium". Owner accounts = free forever. 💜' },
  { keywords: ['ai','kora ai','smart'], response: 'Kora AI is a free assistant in Kora Messenger — ask it anything! 🤖\n\nI (Kora Support) handle Kora-specific questions.' },
];

const AI_FALLBACKS: FallbackEntry[] = [
  { keywords: ['hello','hi','hey'], response: 'Hey! 👋 I\'m Kora AI — ask me anything!' },
  { keywords: ['who are you','what are you'], response: 'I\'m Kora AI — a friendly assistant in Kora Messenger. 🤖' },
  { keywords: ['kora','messenger'], response: 'Kora Messenger = modern messaging app, purple-to-blue design. For features, ask Kora Support! 💜' },
  { keywords: ['thank'], response: 'Anytime! 😊' },
];

function findFallback(entries: FallbackEntry[], message: string): string | null {
  const lower = message.toLowerCase();
  let bestMatch: FallbackEntry | null = null;
  let bestScore = 0;
  for (const entry of entries) {
    let score = 0;
    for (const kw of entry.keywords) if (lower.includes(kw)) score += kw.length;
    if (score > bestScore) { bestScore = score; bestMatch = entry; }
  }
  return bestScore > 0 ? bestMatch.response : null;
}

/// Calls OpenAI Responses API (gpt-5.4-mini)
/// Clean the API key in case it was stored with a wrapper like api_key="sk-..."
function cleanApiKey(raw: string): string {
  let key = raw.trim();
  // Strip common wrappers: api_key="...", api_key='...', etc.
  if (key.startsWith('api_key=')) {
    key = key.slice('api_key='.length).trim();
    if ((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'"') && key.endsWith("'"))) {
      key = key.slice(1, -1);
    }
  }
  return key.trim();
}

async function callOpenAI(systemPrompt: string, message: string, history: any[]): Promise<string | null> {
  const apiKey = cleanApiKey(Deno.env.get('OPENAI_API_KEY') || '');
  if (!apiKey) return null;

  // Build conversation input from recent history (last 10 messages)
  const input: any[] = [];
  for (const m of (history || []).slice(-10).filter((m: any) => m.text && m.text.trim() !== '')) {
    input.push({
      role: m.isMe ? 'user' : 'assistant',
      content: m.text,
    });
  }
  // Add the current user message
  input.push({ role: 'user', content: message });

  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: 'gpt-5.4-mini',
      instructions: systemPrompt,
      input,
      store: true,
    }),
  });

  if (!response.ok) {
    console.error(`OpenAI API error: ${response.status} ${response.statusText}`);
    return null;
  }

  const data = await response.json();
  // The Responses API returns output_text directly
  return data.output_text || null;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' } });
  }
  let body: any;
  try { body = await req.json(); }
  catch { return jsonResponse({ success: false, error: 'Invalid JSON body' }, 400); }
  const { chatType, message, history } = body;
  if (!message || message.trim() === '') return jsonResponse({ success: false, error: 'Message is required' }, 400);
  const isSupport = chatType === 'support';
  const systemPrompt = isSupport ? SUPPORT_PROMPT : AI_PROMPT;
  const hist = history || [];

  // OpenAI gpt-5.4-mini for all users (free)
  try {
    const reply = await callOpenAI(systemPrompt, message, hist);
    if (reply && reply.trim()) return jsonResponse({ success: true, reply: reply.trim() });
  } catch (e) {
    console.error('OpenAI call failed:', e);
  }

  // Knowledge-based fallback
  const fallbacks = isSupport ? SUPPORT_FALLBACKS : AI_FALLBACKS;
  const match = findFallback(fallbacks, message);
  if (match) return jsonResponse({ success: true, reply: match, isFallback: true });
  if (isSupport) {
    return jsonResponse({ success: true, reply: "I'd love to help! Ask about: account, passwords, passkeys, groups, wallpapers, themes, premium, security.", isFallback: true });
  }
  return jsonResponse({ success: true, reply: "I'm having trouble connecting right now. Try again soon! 🤖", isFallback: true });
});
