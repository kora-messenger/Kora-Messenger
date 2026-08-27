/**
 * ═══════════════════════════════════════════════════════════════════
 *  Kora AI Chat — Production v9 (Multimodal)
 *  OpenRouter-powered AI chat backend for Kora Messenger
 * ═══════════════════════════════════════════════════════════════════
 *
 *  v9 Changes:
 *    • MULTIMODAL: Accepts image, audio, and video frame attachments
 *    • Images → GPT-4o vision (base64 data URLs via OpenRouter)
 *    • Audio → Client-provided transcript (on-device STT) + AI understanding
 *    • Video → Client-extracted key frames sent as image attachments
 *    • Backward compatible — no attachments = normal text chat
 *
 *  Request Body:
 *    {
 *      chatType: "ai" | "support",
 *      message: string,
 *      history?: Message[],
 *      stream?: boolean,
 *      attachments?: [{
 *        type: "image" | "audio" | "video_frame",
 *        base64: string,         // base64-encoded data (no data: prefix)
 *        mimeType?: string,      // e.g. "image/jpeg", "audio/aac"
 *        transcript?: string,    // for audio: client-side STT transcript
 *      }]
 *    }
 * ═══════════════════════════════════════════════════════════════════
 */

// ── Types ──────────────────────────────────────────────────────────

interface RateLimitEntry { timestamps: number[]; }
interface ChatMessage { role: 'system' | 'user' | 'assistant'; content: string | any[]; }
interface UsageStats { prompt_tokens: number; completion_tokens: number; total_tokens: number; }
interface ApiError { status: number; message: string; code: string; }

interface Attachment {
  type: 'image' | 'audio' | 'video_frame';
  base64?: string;
  mimeType?: string;
  transcript?: string;
  url?: string;
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
const MAX_IMAGE_SIZE_BYTES = 4 * 1024 * 1024; // 4MB per image
const MAX_ATTACHMENTS = 5;

// ── Rate Limiter ──────────────────────────────────────────────────

const rateMap = new Map<string, RateLimitEntry>();
function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateMap.get(ip) ?? { timestamps: [] };
  const valid = entry.timestamps.filter((t) => now - t < RATE_LIMIT_WINDOW_MS);
  if (valid.length >= RATE_LIMIT_MAX) { rateMap.set(ip, { timestamps: valid }); return false; }
  valid.push(now);
  rateMap.set(ip, { timestamps: valid });
  return true;
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

// ── System Prompts ─────────────────────────────────────────────────

const SUPPORT_PROMPT = `You are Kora Support — the official AI support assistant for Kora Messenger, a modern messaging app with a purple-to-blue gradient design and deep navy/black dark theme.

## Your Role
Help users with any question about Kora Messenger — accounts, login, passkeys, security, groups, communities, channels, wallpapers, chat themes, app icons, premium, troubleshooting, and more.

## Multimodal Capabilities
You can receive and understand:
- **Images**: Screenshots, photos, or pictures the user shares to help explain their issue. Analyze what you see and connect it to their question.
- **Voice notes**: Transcribed on-device — you receive the transcript. Respond naturally as if you heard the audio.
- **Video frames**: Key frames extracted from videos the user shares.

When a user sends an image or video frame, describe what you see briefly, then address their question or concern.

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
- **Search**: Inline search bar on the home screen — searches messages, names, and Kora IDs.

### Groups
- **Create**: Home > 3-dot menu > New Group. Select contacts, search by Name/Kora ID/@Username. Name and optional photo.

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

const AI_PROMPT = `You are Kora AI — an intelligent assistant built into Kora Messenger, a modern messaging app with a purple-to-blue gradient design.

## Your Role
You are a general-purpose AI assistant, comparable to ChatGPT or Gemini. You can answer questions about any topic — science, technology, writing, coding, math, creative writing, general knowledge, advice, and more.

## Multimodal Capabilities
You can receive and understand:
- **Images**: Photos, screenshots, diagrams, charts, or any image the user shares. Analyze what you see, describe relevant details, and answer questions about the content.
- **Voice notes**: Transcribed on-device — you receive the transcript. Respond naturally as if you heard the person speaking.
- **Video frames**: Key frames extracted from videos. Analyze them as images and describe what's happening in the video.

When a user sends media:
1. Briefly acknowledge what you see/hear
2. Then provide a helpful, detailed response
3. If they asked a specific question about the media, answer it directly

Examples of multimodal requests:
- "What's in this photo?" → Describe the image contents
- "Can you read this text?" → Read and transcribe text in the image
- "What code is in this screenshot?" → Read and explain the code
- "[Voice note transcript: Hey, what's the weather like?]" → Respond to the transcribed question
- "Explain what's happening in this video" → Analyze the key frames and describe the action

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
  // Must have either base64 or url
  if (!att.base64 && !att.url) return false;
  // Check base64 size (rough estimate: 4/3 ratio for base64)
  if (att.base64) {
    const approxSize = (att.base64.length * 3) / 4;
    if (approxSize > MAX_IMAGE_SIZE_BYTES) return false;
  }
  return true;
}

// ── Build Multimodal Content ───────────────────────────────────────

function buildUserContent(message: string, attachments?: Attachment[]): string | any[] {
  // If no valid attachments, return plain text
  if (!attachments || attachments.length === 0) return message;

  const contentParts: any[] = [];

  // Add the text message first
  if (message && message.trim()) {
    contentParts.push({ type: 'text', text: message });
  }

  for (const att of attachments) {
    if (att.type === 'image' || att.type === 'video_frame') {
      // Image or video frame → GPT-4o vision
      const mimeType = att.mimeType || (att.type === 'video_frame' ? 'image/jpeg' : 'image/jpeg');
      const imageUrl = att.url || `data:${mimeType};base64,${att.base64}`;
      contentParts.push({
        type: 'image_url',
        image_url: { url: imageUrl },
      });
    } else if (att.type === 'audio') {
      // Audio → use client-provided transcript (on-device STT)
      // GPT-4o chat completions API doesn't accept audio input directly.
      // The client transcribes the voice note on-device and sends the transcript.
      const transcript = att.transcript || '[Audio attachment — no transcript available]';
      contentParts.push({
        type: 'text',
        text: `🎙️ [Voice note transcript]: ${transcript}`,
      });
    }
  }

  // If only text parts (no images), return as plain string for efficiency
  const hasImages = contentParts.some((p) => p.type === 'image_url');
  if (!hasImages) {
    // Flatten to plain text
    return contentParts.map((p) => p.text).join('\n');
  }

  return contentParts;
}

// ── Build Messages Array ───────────────────────────────────────────

function buildMessages(systemPrompt: string, message: string, history: any[], attachments?: Attachment[]): ChatMessage[] {
  const messages: ChatMessage[] = [{ role: 'system', content: systemPrompt }];

  // Add conversation history (text only — history doesn't include attachments)
  const validHistory = (history || [])
    .slice(-MAX_HISTORY_DEPTH)
    .filter((m: any) => m.text && m.text.trim() !== '' && m.text.length <= MAX_MESSAGE_LENGTH);

  for (const m of validHistory) {
    messages.push({
      role: m.isMe ? 'user' : 'assistant',
      content: m.text,
    });
  }

  // Add current message (with multimodal content if attachments exist)
  const userContent = buildUserContent(message, attachments);
  messages.push({ role: 'user', content: userContent });

  return messages;
}

// ── OpenRouter API Call ────────────────────────────────────────────

async function callOpenRouter(messages: ChatMessage[], options: { stream: boolean }): Promise<Response> {
  const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
  if (!apiKey || apiKey.length < 10) {
    throw { status: 500, message: 'OpenRouter API key is missing or invalid', code: 'MISSING_API_KEY' } as ApiError;
  }
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
  console.log(`[Kora AI] Attempting fallback model: ${fallbackModel}`);
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
    console.error('[Kora AI] Unexpected response:', JSON.stringify(data).slice(0, 500));
    return corsResponse({ success: false, error: 'Unexpected AI response format', reply: null }, 500);
  } catch (e) {
    const apiError = e as ApiError;
    try {
      const fallbackReply = await callOpenRouterFallback(messages);
      return corsResponse({ success: true, reply: fallbackReply, fallback: true });
    } catch (fallbackErr) { console.error(`[Kora AI] Fallback failed: ${fallbackErr}`); }
    const errorDetail = e instanceof Error ? e.message : apiError?.message || String(e);
    console.error(`[Kora AI] Request failed: ${errorDetail}`);
    return corsResponse({ success: false, error: errorDetail, reply: "I'm having trouble connecting right now. Please try again in a moment! 🤖" }, 500);
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
    const errorDetail = e instanceof Error ? e.message : apiError?.message || String(e);
    console.error(`[Kora AI] Streaming failed: ${errorDetail}`);
    return corsResponse({ success: false, error: errorDetail, reply: "I'm having trouble connecting right now. Please try again in a moment! 🤖" }, 500);
  }
}

// ── Input Validation ──────────────────────────────────────────────

function validateInput(body: any): { valid: boolean; error?: string; chatType?: string; message?: string; history?: any[]; stream?: boolean; attachments?: Attachment[] } {
  if (!body || typeof body !== 'object') return { valid: false, error: 'Invalid request body' };
  const { chatType, message, history, stream, attachments } = body;
  if (!chatType || !['ai', 'support'].includes(chatType)) return { valid: false, error: 'chatType must be "ai" or "support"' };
  if (!message || typeof message !== 'string' || message.trim() === '') return { valid: false, error: 'message is required' };
  if (message.length > MAX_MESSAGE_LENGTH) return { valid: false, error: `Message too long (max ${MAX_MESSAGE_LENGTH} chars)` };

  // Validate attachments
  let validAttachments: Attachment[] | undefined;
  if (attachments && Array.isArray(attachments)) {
    if (attachments.length > MAX_ATTACHMENTS) return { valid: false, error: `Too many attachments (max ${MAX_ATTACHMENTS})` };
    validAttachments = attachments.filter(validateAttachment);
    if (validAttachments.length === 0) validAttachments = undefined;
  }

  return {
    valid: true,
    chatType,
    message: message.trim(),
    history: Array.isArray(history) ? history : [],
    stream: stream === true,
    attachments: validAttachments,
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

  const systemPrompt = input.chatType === 'support' ? SUPPORT_PROMPT : AI_PROMPT;

  if (input.stream) return await handleStreaming(systemPrompt, input.message!, input.history!, input.attachments);
  return await handleNonStreaming(systemPrompt, input.message!, input.history!, input.attachments);
});
