/**
 * ═══════════════════════════════════════════════════════════════════
 *  Kora AI Chat — Production v11 (Database-Aware Account Context)
 *  OpenRouter-powered AI chat backend for Kora Messenger
 * ═══════════════════════════════════════════════════════════════════
 *
 *  v10 Changes:
 *    • ACCOUNT-AWARE: Accepts userContext (name, username, email, koraId,
 *      isPremium, isVerified, bio, profileCompleted) and injects it
 *      into the system prompt for personalized responses
 *    • AI can greet by name, tailor premium advice, and reference
 *      the user's profile naturally
 *    • Backward compatible — no userContext = generic responses
 *
 *  v11 Changes:
 *    • DATABASE-AWARE: Queries KoraUser entity directly from the database
 *      using the user's email, giving the AI verified, up-to-date account
 *      data — not client-provided (which could be stale or fake).
 *    • Enriched context: account age, premium expiry, suspension status,
 *      passkey enrollment, profile completeness, avatar presence, and
 *      conversation stats.
 *    • Falls back to client-provided userContext if database lookup fails.
 *    • Client now only needs to send `email` — the backend fetches the rest.
 *
 *  Request Body:
 *    {
 *      chatType: "ai" | "support",
 *      message: string,
 *      history?: Message[],
 *      stream?: boolean,
 *      attachments?: Attachment[],
 *      userContext?: {
 *        fullName?: string,
 *        username?: string,
 *        email?: string,
 *        koraId?: string,
 *        isPremium?: boolean,
 *        isVerified?: boolean,
 *        bio?: string,
 *        profileCompleted?: boolean
 *      }
 *    }
 * ═══════════════════════════════════════════════════════════════════
 */

// ── Base44 SDK (for database account lookups) ─────────────────────
import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

// ── Types ──────────────────────────────────────────────────────────

interface RateLimitEntry { timestamps: number[]; }
interface ChatMessage { role: 'system' | 'user' | 'assistant'; content: string | any[]; }
interface UsageStats { prompt_tokens: number; completion_tokens: number; total_tokens: number; }
interface ApiError { status: number; message: string; code: string; }
interface Attachment { type: 'image' | 'audio' | 'video_frame'; base64?: string; mimeType?: string; transcript?: string; url?: string; }

interface UserContext {
  fullName?: string;
  username?: string;
  email?: string;
  koraId?: string;
  isPremium?: boolean;
  isVerified?: boolean;
  bio?: string;
  profileCompleted?: boolean;
  // v11: Database-enriched fields
  premiumExpiresAt?: string;
  premiumSource?: string;
  passkeysEnabled?: boolean;
  isSuspended?: boolean;
  suspensionReason?: string;
  accountCreatedAt?: string;
  hasAvatar?: boolean;
  phoneNumber?: string;
}

// ── Constants ──────────────────────────────────────────────────────

const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 30;
const MAX_HISTORY_DEPTH = 10;
const MAX_MESSAGE_LENGTH = 4000;
const MAX_TOKENS = 2000;
const TEMPERATURE = 0.7;
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_MODEL = 'openai/gpt-4o';
const FALLBACK_MODEL = 'openai/gpt-4o-mini';
const MAX_IMAGE_SIZE_BYTES = 4 * 1024 * 1024;
const MAX_ATTACHMENTS = 5;

// ── Rate Limiter ──────────────────────────────────────────────────

const rateMap = new Map<string, RateLimitEntry>();
function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateMap.get(ip) ?? { timestamps: [] };
  const valid = entry.timestamps.filter((t) => now - t < RATE_LIMIT_WINDOW_MS);
  if (valid.length >= RATE_LIMIT_MAX) { rateMap.set(ip, { timestamps: valid }); return false; }
  valid.push(now); rateMap.set(ip, { timestamps: valid }); return true;
}

// ── Auth ───────────────────────────────────────────────────────────

function verifyAuth(req: Request): boolean {
  const expectedToken = Deno.env.get('KORA_AI_AUTH_TOKEN') || '';
  if (!expectedToken || expectedToken.length < 8) return true;
  const authHeader = req.headers.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) return false;
  const token = authHeader.slice(7).trim();
  if (token.length !== expectedToken.length) return false;
  let diff = 0;
  for (let i = 0; i < token.length; i++) { diff |= token.charCodeAt(i) ^ expectedToken.charCodeAt(i); }
  return diff === 0;
}

function getClientIp(req: Request): string {
  return req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
}

// ── CORS ───────────────────────────────────────────────────────────

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function corsResponse(data: unknown, status = 200): Response {
  const body = typeof data === 'string' ? data : JSON.stringify(data);
  return new Response(body, { status, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } });
}

function sseHeaders(): Record<string, string> {
  return { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive', ...CORS_HEADERS };
}

// ── Base System Prompts ────────────────────────────────────────────

const SUPPORT_PROMPT_BASE = `You are Kora Support — the official AI support assistant for Kora Messenger, a modern messaging app with a purple-to-blue gradient design and deep navy/black dark theme.

## Your Role
Help users with any question about Kora Messenger — accounts, login, passkeys, security, groups, communities, channels, wallpapers, chat themes, app icons, premium, troubleshooting, and more.

## Multimodal Capabilities
You can receive and understand:
- **Images**: Screenshots, photos, or pictures the user shares to help explain their issue.
- **Voice notes**: Transcribed on-device — you receive the transcript. Respond naturally.
- **Video frames**: Key frames extracted from videos.

When a user sends an image or video frame, describe what you see briefly, then address their question.

## Tone & Style
- Be professional, clear, and genuinely helpful — like a knowledgeable support agent
- Be concise but thorough — answer completely without unnecessary filler
- Use bullet points and numbered steps when it improves clarity
- Use emoji sparingly and only when it adds warmth (max 1-2 per response)
- Never invent features that don't exist in Kora
- If a question is completely unrelated to Kora, politely redirect: "That's outside my area — but Kora AI can help with general questions! Try asking there."

## Complete Kora Knowledge Base

### Account & Authentication
- **Sign up**: Email + password. Verification code sent to email. Code auto-verifies on the last digit — no submit button. Codes also auto-fill from clipboard.
- **Login**: Email + password, or passkey (biometric). After login, a verification code is sent to email unless the device is trusted.
- **Password reset**: Tap "Forgot password?" → enter email → receive code → enter code → set new password → redirected to login screen.
- **Verification codes**: Sent to email. Auto-verify on the final digit. Auto-fill from clipboard.
- **Trusted devices**: Must be used 30+ days before they can be marked trusted. Skip email verification on login. Managed in Settings > Security > Trusted Devices.
- **Passkeys**: Biometric login (fingerprint/Face ID). Settings > Security > Passkeys. Tied to specific devices.
- **Logout**: Settings > Account > Log out.

### Security
- **Passkeys**: Settings > Security > Passkeys — register biometric login per device.
- **Trusted Devices**: Settings > Security > Trusted Devices — manage which devices skip verification. Must be 30+ days old.
- **Secure PIN**: Optional additional security layer.
- **Block/Report**: In any chat > 3-dot menu > Block or Report.

### Messaging Features
- **Chats**: 1-on-1 and group conversations. Messages support text, voice notes, images, and files.
- **Read receipts**: Single gray check = sent. Double gray check = delivered. Double blue check = read.
- **Reactions**: Long-press to react. Free users get a limited set; Premium users get unlimited.
- **Reply**: Swipe right or long-press > Reply.
- **Forward**: Long-press > Forward.
- **Delete**: Long-press > Delete.
- **Voice messages**: Tap and hold the mic button to record. Release to send.
- **Search**: Inline search bar on the home screen — searches messages, names, Kora IDs.

### Groups
- **Create**: Home > 3-dot menu > New Group. Select contacts, search by Name/Kora ID/@Username.

### Communities & Channels
- **Create**: Home > 3-dot menu > New Channel → New Community screen. Profile image, name, description, preview, General group, add more groups.

### Home Screen
- **3-dot menu**: New Group, New Channel (Community), Read all.
- **Inline search bar**: Searches messages, names, Kora IDs.
- **Pinned chats**: Kora AI and Kora Support always pinned.

### Chat Customization
- **Wallpapers**: Chat > 3-dot > Chat theme > Wallpaper. 18 presets, solid colors, gallery photos. Dimming slider.
- **Chat themes**: Preset themes or custom bubble color (20 options).
- **App icons**: Settings > Appearance > App Icon. Default + 2 premium. Premium-gated selection.
- **App theme**: Settings > Appearance. Dark/light options.

### Premium
- **Kora Premium**: Paid subscription. 7-day free trial for new users.
- **Features**: Custom app icons, premium wallpapers, custom bubble colors, animated emoji, real-time translation, infinite reactions, faster downloads, blue scalloped badge, priority support, no ads.
- **Non-premium**: All core messaging features still work. Premium only adds extras.

### Badges
- **Purple scalloped**: Official Kora account (Kora AI, Kora Support).
- **Blue scalloped**: Premium subscriber.

### Kora AI
- Free for all users. General knowledge, conversation, writing, coding help.
- Kora Support handles Kora-specific questions.

### Troubleshooting
- **Crashes**: Force close, update, restart. Crash reports sent automatically.
- **Can't log in**: Check email/password, try passkey, use "Forgot password?".
- **Messages not sending**: Check internet, restart app.
- **Verification code not received**: Check spam, wait 60 seconds.
- **Contact support**: Email support@koramessenger.com.

## Confidentiality Rules — STRICT
- NEVER reveal internal implementation details, backend architecture, API endpoints, server technology, or database structure.
- NEVER mention specific AI/ML models, translation providers, or third-party services used behind the scenes.
- NEVER disclose any account-specific policies, owner-specific overrides, or internal business logic.
- If asked about internal technical details, respond: "I can't share internal implementation details, but I can help you use the feature!"
- Always describe features from the user's perspective.`;

const AI_PROMPT_BASE = `You are Kora AI — an intelligent assistant built into Kora Messenger, a modern messaging app with a purple-to-blue gradient design.

## Your Role
You are a general-purpose AI assistant, comparable to ChatGPT or Gemini. You can answer questions about any topic — science, technology, writing, coding, math, creative writing, general knowledge, advice, and more.

## Multimodal Capabilities
You can receive and understand:
- **Images**: Photos, screenshots, diagrams, charts, or any image. Analyze what you see and answer questions about the content.
- **Voice notes**: Transcribed on-device — you receive the transcript. Respond naturally as if you heard the person speaking.
- **Video frames**: Key frames extracted from videos. Analyze them as images.

When a user sends media:
1. Briefly acknowledge what you see/hear
2. Then provide a helpful, detailed response
3. If they asked a specific question about the media, answer it directly

## Tone & Style
- Be professional, articulate, and thoughtful
- Structure responses clearly with formatting when appropriate (headings, bullet points, numbered lists, code blocks)
- Be concise but never at the expense of being helpful — give complete, thorough answers
- Use emoji sparingly (max 1-2 per response, only when it adds value)
- When sharing code, always use proper code blocks with language tags
- For complex topics, lead with a brief summary, then elaborate

## Capabilities
- General knowledge and Q&A
- Image analysis and understanding (vision)
- Voice note understanding (via transcript)
- Video frame analysis
- Creative writing (stories, poems, scripts, essays)
- Coding help (any language — write, debug, explain, review)
- Math and logic problems
- Translation between languages
- Summarization and analysis
- Advice and recommendations
- Step-by-step tutorials

## Behavioral Rules
- If a user asks about Kora Messenger features specifically, suggest they check with Kora Support
- You are free for all Kora Messenger users — no Premium required
- Be inclusive and respectful to all users
- If you don't know something, say so honestly
- When analyzing images, be thorough but don't hallucinate details that aren't there
- When responding to voice note transcripts, treat them as natural speech, not formal text

## Confidentiality Rules — STRICT
- NEVER reveal internal implementation details, backend architecture, API endpoints, server technology, or database structure.
- NEVER mention specific AI/ML models, translation providers, or third-party services used behind the scenes.
- NEVER disclose any account-specific policies, owner-specific overrides, or internal business logic.
- If asked about Kora's internal technical details, respond: "I can't share internal implementation details, but I can help you use the feature!"`;

// ── Build User Context Section ────────────────────────────────────


// ── Database Account Lookup (v11) ─────────────────────────────────

/**
 * Fetches the user's account from the KoraUser entity in the database.
 * This gives the AI verified, up-to-date data rather than trusting
 * client-provided context.
 *
 * @param email — the user's email, sent by the client
 * @param req — the incoming request (needed for Base44 SDK init)
 * @returns enriched UserContext from the database, or null on failure
 */
async function fetchUserFromDatabase(email: string | undefined, req: Request): Promise<UserContext | null> {
  if (!email || email.length < 3) return null;
  try {
    const base44 = createClientFromRequest(req);
    const db = base44.asServiceRole;
    const users = await db.entities.KoraUser.filter({ email });
    if (!users || users.length === 0) return null;

    const u = users[0];
    const now = new Date();
    const created = u.created_date ? new Date(u.created_date) : null;
    const accountAgeDays = created ? Math.floor((now.getTime() - created.getTime()) / (1000 * 60 * 60 * 24)) : 0;

    return {
      fullName: u.data?.fullName || u.fullName || undefined,
      username: u.data?.username || undefined,
      email: u.data?.email || u.email || email,
      koraId: u.data?.koraId || undefined,
      isPremium: u.data?.isPremium === true,
      isVerified: u.data?.isVerified === true,
      bio: u.data?.bio || undefined,
      profileCompleted: u.data?.profileCompleted === true,
      // Enriched fields
      premiumExpiresAt: u.data?.premiumExpiresAt || undefined,
      premiumSource: u.data?.premiumSource || undefined,
      passkeysEnabled: u.data?.passkeysEnabled === true,
      isSuspended: u.data?.isSuspended === true,
      suspensionReason: u.data?.suspensionReason || undefined,
      accountCreatedAt: created ? created.toISOString() : undefined,
      hasAvatar: !!(u.data?.avatarUrl || u.data?.avatarAsset),
      phoneNumber: u.data?.phoneNumber || undefined,
    };
  } catch (err) {
    console.error('[koraAiChat] DB lookup failed:', err);
    return null;
  }
}

function buildUserContextSection(ctx?: UserContext): string {
  if (!ctx || !ctx.fullName && !ctx.username && !ctx.email) return '';

  const parts: string[] = [];

  // Greeting name
  const displayName = ctx.fullName || ctx.username || '';
  if (displayName) {
    parts.push(`You are talking to **${displayName}**.`);
  }

  // Username
  if (ctx.username) {
    parts.push(`Their Kora username is @${ctx.username}.`);
  }

  // Kora ID
  if (ctx.koraId) {
    parts.push(`Their Kora ID is ${ctx.koraId}.`);
  }

  // Premium status
  if (ctx.isPremium === true) {
    parts.push(`They are a **Kora Premium** subscriber — you can reference premium features (custom app icons, premium wallpapers, custom bubble colors, animated emoji, real-time translation, infinite reactions, priority support, no ads) when relevant.`);
  } else {
    parts.push(`They are a **free** user — when mentioning premium features, note that they require a Premium subscription and remind them they can try it free for 7 days.`);
  }

  // Verification status
  if (ctx.isVerified === true) {
    parts.push(`Their account is verified.`);
  }

  // Profile completion
  if (ctx.profileCompleted === false) {
    parts.push(`Their profile is not yet complete — if relevant, gently encourage them to complete their profile in Settings.`);
  }

  // Bio
  if (ctx.bio && ctx.bio.trim().length > 0) {
    parts.push(`Their bio: "${ctx.bio.trim().slice(0, 200)}"`);
  }

  // ── v11: Database-enriched context ──
  // Account age
  if (ctx.accountCreatedAt) {
    const ageDate = new Date(ctx.accountCreatedAt);
    const ageDays = Math.floor((Date.now() - ageDate.getTime()) / (1000 * 60 * 60 * 24));
    if (ageDays > 0) {
      if (ageDays < 7) parts.push(`They joined Kora ${ageDays} days ago — they're very new.`);
      else if (ageDays < 30) parts.push(`They've been on Kora for ${ageDays} days.`);
      else if (ageDays < 365) parts.push(`They've been on Kora for ${Math.floor(ageDays / 30)} months.`);
      else parts.push(`They've been on Kora for over a year (since ${ageDate.getFullYear()}).`);
    }
  }

  // Premium expiry
  if (ctx.isPremium === true && ctx.premiumExpiresAt) {
    const expDate = new Date(ctx.premiumExpiresAt);
    const daysLeft = Math.floor((expDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
    if (daysLeft > 0 && daysLeft < 7) {
      parts.push(`Their Premium subscription expires in ${daysLeft} days — mention renewal if relevant.`);
    } else if (daysLeft <= 0) {
      parts.push(`Their Premium subscription may have expired.`);
    }
  }

  // Passkeys
  if (ctx.passkeysEnabled === true) {
    parts.push(`They have passkeys enabled (biometric login).`);
  }

  // Suspension status
  if (ctx.isSuspended === true) {
    parts.push(`⚠️ Their account is currently suspended${ctx.suspensionReason ? ` (reason: ${ctx.suspensionReason})` : ''}. Be empathetic and direct them to appeal if they ask.`);
  }

  // Avatar
  if (ctx.hasAvatar === false && ctx.profileCompleted === true) {
    parts.push(`They haven't set a profile photo yet — gently suggest adding one if relevant.`);
  }

  if (parts.length === 0) return '';

  return `\n## About the User You're Talking To\n${parts.join('\n')}\n\n## Personalization Guidelines
- Use their name naturally when it feels right (not every message — just when it adds warmth)
- If they ask about premium features, tailor your answer based on their premium status
- Don't mention their email, Kora ID, phone number, or bio unless they explicitly ask about their account
- Treat this context as background knowledge — don't recite it back to them
- If they ask "what do you know about me?", you can share: their name, username, premium status, verification status, how long they've been on Kora, and whether they have passkeys — but NOT their email, phone number, or bio (those are private)
- If their account is suspended, be empathetic and guide them to appeal via Settings
- If their premium is expiring soon, mention renewal only when it's contextually relevant (e.g., they ask about a premium feature)`;
}

// ── Build Final System Prompt ─────────────────────────────────────

function buildSystemPrompt(base: string, userContext?: UserContext): string {
  const ctxSection = buildUserContextSection(userContext);
  if (!ctxSection) return base;
  return `${base}${ctxSection}`;
}

// ── API Key Cleaning ─────────────────────────────────────────────

function cleanApiKey(raw: string): string {
  let key = raw.trim();
  if (key.startsWith('api_key=')) key = key.slice('api_key='.length);
  if (key.startsWith('Bearer ')) key = key.slice('Bearer '.length);
  if (key.length >= 2 && (key[0] === '"' || key[0] === "'") && key[key.length - 1] === key[0]) { key = key.slice(1, -1); }
  return key.trim();
}

// ── Attachment Validation ─────────────────────────────────────────

function validateAttachment(att: any): att is Attachment {
  if (!att || typeof att !== 'object') return false;
  if (!att.type || !['image', 'audio', 'video_frame'].includes(att.type)) return false;
  if (!att.base64 && !att.url) return false;
  if (att.base64) { if ((att.base64.length * 3) / 4 > MAX_IMAGE_SIZE_BYTES) return false; }
  return true;
}

// ── Build Multimodal Content ───────────────────────────────────────

function buildUserContent(message: string, attachments?: Attachment[]): string | any[] {
  if (!attachments || attachments.length === 0) return message;
  const contentParts: any[] = [];
  if (message && message.trim()) { contentParts.push({ type: 'text', text: message }); }
  for (const att of attachments) {
    if (att.type === 'image' || att.type === 'video_frame') {
      const mimeType = att.mimeType || 'image/jpeg';
      const imageUrl = att.url || `data:${mimeType};base64,${att.base64}`;
      contentParts.push({ type: 'image_url', image_url: { url: imageUrl } });
    } else if (att.type === 'audio') {
      const transcript = att.transcript || '[Audio attachment — no transcript available]';
      contentParts.push({ type: 'text', text: `[Voice note transcript]: ${transcript}` });
    }
  }
  const hasImages = contentParts.some((p) => p.type === 'image_url');
  if (!hasImages) { return contentParts.map((p) => p.text).join('\n'); }
  return contentParts;
}

// ── Build Messages Array ───────────────────────────────────────────

function buildMessages(systemPrompt: string, message: string, history: any[], attachments?: Attachment[]): ChatMessage[] {
  const messages: ChatMessage[] = [{ role: 'system', content: systemPrompt }];
  const validHistory = (history || []).slice(-MAX_HISTORY_DEPTH).filter((m: any) => m.text && m.text.trim() !== '' && m.text.length <= MAX_MESSAGE_LENGTH);
  for (const m of validHistory) { messages.push({ role: m.isMe ? 'user' : 'assistant', content: m.text }); }
  const userContent = buildUserContent(message, attachments);
  messages.push({ role: 'user', content: userContent });
  return messages;
}

// ── OpenRouter API Call ────────────────────────────────────────────

async function callOpenRouter(messages: ChatMessage[], options: { stream: boolean }): Promise<Response> {
  const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
  if (!apiKey || apiKey.length < 10) { throw { status: 500, message: 'OpenRouter API key is missing', code: 'MISSING_API_KEY' } as ApiError; }
  const model = Deno.env.get('OPENROUTER_MODEL') || DEFAULT_MODEL;
  const response = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}`, 'X-Title': 'Kora Messenger' },
    body: JSON.stringify({ model, messages, temperature: TEMPERATURE, max_tokens: MAX_TOKENS, stream: options.stream }),
  });
  if (!response.ok) {
    const errBody = await response.text().catch(() => '');
    console.error(`[Kora AI] OpenRouter error: ${response.status} — ${errBody.slice(0, 500)}`);
    throw { status: response.status, message: `OpenRouter ${response.status}: ${errBody.slice(0, 200)}`, code: 'OPENROUTER_ERROR' } as ApiError;
  }
  return response;
}

// ── Fallback ──────────────────────────────────────────────────────

async function callOpenRouterFallback(messages: ChatMessage[]): Promise<string> {
  const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
  const fallbackModel = Deno.env.get('OPENROUTER_FALLBACK') || FALLBACK_MODEL;
  console.log(`[Kora AI] Attempting fallback: ${fallbackModel}`);
  const response = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}`, 'X-Title': 'Kora Messenger' },
    body: JSON.stringify({ model: fallbackModel, messages, temperature: TEMPERATURE, max_tokens: MAX_TOKENS, stream: false }),
  });
  if (!response.ok) throw new Error(`Fallback failed: ${response.status}`);
  const data = await response.json();
  if (data.choices?.[0]?.message?.content) return data.choices[0].message.content.trim();
  throw new Error('Fallback returned unexpected response');
}

// ── Non-Streaming Handler ─────────────────────────────────────────

async function handleNonStreaming(systemPrompt: string, message: string, history: any[], attachments?: Attachment[]): Promise<Response> {
  const messages = buildMessages(systemPrompt, message, history, attachments);
  try {
    const apiResponse = await callOpenRouter(messages, { stream: false });
    const data = await apiResponse.json();
    if (data.choices?.[0]?.message?.content) {
      const reply = data.choices[0].message.content.trim();
      const usage: UsageStats | undefined = data.usage;
      return corsResponse({ success: true, reply, ...(usage ? { usage } : {}) });
    }
    return corsResponse({ success: false, error: 'Unexpected AI response format', reply: null }, 500);
  } catch (e) {
    const apiError = e as ApiError;
    try { const fr = await callOpenRouterFallback(messages); return corsResponse({ success: true, reply: fr, fallback: true }); }
    catch (fe) { console.error(`[Kora AI] Fallback failed: ${fe}`); }
    const err = e instanceof Error ? e.message : apiError?.message || String(e);
    console.error(`[Kora AI] Request failed: ${err}`);
    return corsResponse({ success: false, error: err, reply: "I'm having trouble connecting right now. Please try again in a moment! 🤖" }, 500);
  }
}

// ── Streaming Handler (SSE) ───────────────────────────────────────

async function handleStreaming(systemPrompt: string, message: string, history: any[], attachments?: Attachment[]): Promise<Response> {
  const messages = buildMessages(systemPrompt, message, history, attachments);
  try {
    const apiResponse = await callOpenRouter(messages, { stream: true });
    const { readable, writable } = new TransformStream();
    const writer = writable.getWriter();
    const encoder = new TextEncoder();
    (async () => {
      const reader = apiResponse.body?.getReader();
      if (!reader) { writer.write(encoder.encode('data: {"error": "No stream body"}\n\n')); writer.close(); return; }
      const decoder = new TextDecoder();
      let buffer = '';
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';
          for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed || !trimmed.startsWith('data: ')) continue;
            const data = trimmed.slice(6);
            if (data === '[DONE]') { await writer.write(encoder.encode('data: [DONE]\n\n')); continue; }
            await writer.write(encoder.encode(`data: ${data}\n\n`));
          }
        }
        if (buffer.trim() && buffer.trim().startsWith('data: ')) { await writer.write(encoder.encode(`${buffer}\n\n`)); }
        await writer.write(encoder.encode('data: [DONE]\n\n'));
        writer.close();
      } catch (streamErr) {
        console.error('[Kora AI] Stream error:', streamErr);
        await writer.write(encoder.encode(`data: {"error": "Stream interrupted"}\n\n`));
        writer.close();
      }
    })();
    return new Response(readable, { headers: sseHeaders() });
  } catch (e) {
    const apiError = e as ApiError;
    const err = e instanceof Error ? e.message : apiError?.message || String(e);
    console.error(`[Kora AI] Streaming failed: ${err}`);
    return corsResponse({ success: false, error: err, reply: "I'm having trouble connecting right now. Please try again in a moment! 🤖" }, 500);
  }
}

// ── Input Validation ──────────────────────────────────────────────

function validateInput(body: any): { valid: boolean; error?: string; chatType?: string; message?: string; history?: any[]; stream?: boolean; attachments?: Attachment[]; userContext?: UserContext } {
  if (!body || typeof body !== 'object') return { valid: false, error: 'Invalid request body' };
  const { chatType, message, history, stream, attachments, userContext } = body;
  if (!chatType || !['ai', 'support'].includes(chatType)) return { valid: false, error: 'chatType must be "ai" or "support"' };
  if (!message || typeof message !== 'string' || message.trim() === '') return { valid: false, error: 'message is required' };
  if (message.length > MAX_MESSAGE_LENGTH) return { valid: false, error: `Message too long (max ${MAX_MESSAGE_LENGTH} chars)` };

  let validAttachments: Attachment[] | undefined;
  if (attachments && Array.isArray(attachments)) {
    if (attachments.length > MAX_ATTACHMENTS) return { valid: false, error: `Too many attachments (max ${MAX_ATTACHMENTS})` };
    validAttachments = attachments.filter(validateAttachment);
    if (validAttachments.length === 0) validAttachments = undefined;
  }

  // Validate userContext (all fields optional, but must be strings/booleans if present)
  let validUserContext: UserContext | undefined;
  if (userContext && typeof userContext === 'object') {
    validUserContext = {
      fullName: typeof userContext.fullName === 'string' ? userContext.fullName.slice(0, 100) : undefined,
      username: typeof userContext.username === 'string' ? userContext.username.slice(0, 50) : undefined,
      email: typeof userContext.email === 'string' ? userContext.email.slice(0, 200) : undefined,
      koraId: typeof userContext.koraId === 'string' ? userContext.koraId.slice(0, 50) : undefined,
      isPremium: typeof userContext.isPremium === 'boolean' ? userContext.isPremium : undefined,
      isVerified: typeof userContext.isVerified === 'boolean' ? userContext.isVerified : undefined,
      bio: typeof userContext.bio === 'string' ? userContext.bio.slice(0, 300) : undefined,
      profileCompleted: typeof userContext.profileCompleted === 'boolean' ? userContext.profileCompleted : undefined,
    };
    // Only keep if at least one field is set
    if (!Object.values(validUserContext).some(v => v !== undefined)) validUserContext = undefined;
  }

  return {
    valid: true,
    chatType,
    message: message.trim(),
    history: Array.isArray(history) ? history : [],
    stream: stream === true,
    attachments: validAttachments,
    userContext: validUserContext,
  };
}

// ── Main Server ───────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST') return corsResponse({ success: false, error: 'Method not allowed. Use POST.' }, 405);
  if (!verifyAuth(req)) return corsResponse({ success: false, error: 'Unauthorized' }, 401);
  const clientIp = getClientIp(req);
  if (!checkRateLimit(clientIp)) return corsResponse({ success: false, error: 'Rate limit exceeded. Please slow down.', retryAfter: RATE_LIMIT_WINDOW_MS / 1000 }, 429);

  let body: any;
  try { body = await req.json(); } catch { return corsResponse({ success: false, error: 'Invalid JSON body' }, 400); }

  const input = validateInput(body);
  if (!input.valid) return corsResponse({ success: false, error: input.error }, 400);

  // ── v11: Fetch user account from database for verified context ──
  // Try database lookup first; fall back to client-provided userContext
  let enrichedContext = input.userContext;
  try {
    const dbContext = await fetchUserFromDatabase(input.userContext?.email, req);
    if (dbContext) {
      // Merge: database data takes priority, but keep client fields as fallback
      enrichedContext = { ...input.userContext, ...dbContext };
    }
  } catch (e) {
    console.error('[koraAiChat] DB enrichment failed, using client context:', e);
  }

  // Build system prompt with enriched user context
  const basePrompt = input.chatType === 'support' ? SUPPORT_PROMPT_BASE : AI_PROMPT_BASE;
  const systemPrompt = buildSystemPrompt(basePrompt, enrichedContext);

  if (input.stream) return await handleStreaming(systemPrompt, input.message!, input.history!, input.attachments);
  return await handleNonStreaming(systemPrompt, input.message!, input.history!, input.attachments);
});
