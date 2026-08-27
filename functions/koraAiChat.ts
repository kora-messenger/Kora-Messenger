/**
 * ═══════════════════════════════════════════════════════════════════
 *  Kora AI Chat — Production v8
 *  OpenRouter-powered AI chat backend for Kora Messenger
 * ═══════════════════════════════════════════════════════════════════
 *
 *  Features:
 *    • Streaming responses (SSE) for real-time token delivery
 *    • Non-streaming mode for simple requests
 *    • Bearer token authentication (KORA_AI_AUTH_TOKEN)
 *    • Sliding-window rate limiting (per-IP, in-memory)
 *    • Conversation context with configurable history depth
 *    • Model fallback chain (primary → fallback)
 *    • Comprehensive error handling with HTTP status codes
 *    • Token usage tracking and logging
 *    • CORS preflight handling
 *
 *  Environment Variables:
 *    OPENROUTER_API_KEY   — Required. OpenRouter API key
 *    OPENROUTER_MODEL      — Optional. Primary model (default: openai/gpt-4o)
 *    OPENROUTER_FALLBACK   — Optional. Fallback model (default: openai/gpt-4o-mini)
 *    KORA_AI_AUTH_TOKEN    — Optional. Bearer token for auth (if unset, open mode)
 *
 *  API Contract:
 *    POST /koraAiChat
 *    Body: { chatType: "ai" | "support", message: string, history?: Message[], stream?: boolean }
 *    Response (non-stream): { success: boolean, reply: string, usage?: object }
 *    Response (stream): text/event-stream with data chunks
 *
 *  Author: Kora Messenger Backend
 *  License: Proprietary — kora-messenger/Kora-Messenger
 * ═══════════════════════════════════════════════════════════════════
 */

// ── Types ──────────────────────────────────────────────────────────

interface RateLimitEntry {
  timestamps: number[];
}

interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface UsageStats {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface ApiError {
  status: number;
  message: string;
  code: string;
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

// ── Rate Limiter (Sliding Window) ─────────────────────────────────

const rateMap = new Map<string, RateLimitEntry>();

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateMap.get(ip) ?? { timestamps: [] };

  // Prune timestamps outside the window
  const valid = entry.timestamps.filter((t) => now - t < RATE_LIMIT_WINDOW_MS);

  if (valid.length >= RATE_LIMIT_MAX) {
    rateMap.set(ip, { timestamps: valid });
    return false;
  }

  valid.push(now);
  rateMap.set(ip, { timestamps: valid });
  return true;
}

// ── Auth ──────────────────────────────────────────────────────────

function verifyAuth(req: Request): boolean {
  const expectedToken = Deno.env.get('KORA_AI_AUTH_TOKEN') || '';
  if (!expectedToken || expectedToken.length < 8) return true; // Dev mode: open access

  const authHeader = req.headers.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) return false;

  const token = authHeader.slice(7).trim();
  // Constant-time comparison to prevent timing attacks
  if (token.length !== expectedToken.length) return false;

  let diff = 0;
  for (let i = 0; i < token.length; i++) {
    diff |= token.charCodeAt(i) ^ expectedToken.charCodeAt(i);
  }
  return diff === 0;
}

function getClientIp(req: Request): string {
  const forwarded = req.headers.get('x-forwarded-for');
  if (forwarded) return forwarded.split(',')[0].trim();
  const realIp = req.headers.get('x-real-ip');
  if (realIp) return realIp.trim();
  return 'unknown';
}

// ── CORS Helpers ──────────────────────────────────────────────────

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function corsResponse(data: unknown, status = 200): Response {
  const body = typeof data === 'string' ? data : JSON.stringify(data);
  return new Response(body, {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...CORS_HEADERS,
    },
  });
}

function sseHeaders(): Record<string, string> {
  return {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    ...CORS_HEADERS,
  };
}

// ── System Prompts ────────────────────────────────────────────────

const SUPPORT_PROMPT = `You are Kora Support — the official AI support assistant for Kora Messenger, a modern messaging app with a purple-to-blue gradient design and deep navy/black dark theme.

## Your Role
Help users with any question about Kora Messenger — accounts, login, passkeys, security, groups, communities, channels, wallpapers, chat themes, app icons, premium, troubleshooting, and more.

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
- **Password reset**: Tap "Forgot password?" on the login screen → enter email → receive code → enter code → set new password → redirected to login screen.
- **Verification codes**: Always sent to email. Auto-verify on the final digit. Auto-fill from clipboard. No manual submit button needed.
- **Trusted devices**: Devices must be used for 30+ days before they can be marked as trusted. Trusted devices skip email verification on login. Managed in Settings > Security > Trusted Devices.
- **Passkeys**: Biometric login (fingerprint/Face ID). Set up in Settings > Security > Passkeys. Can be used instead of password for login. Tied to specific devices.
- **Logout**: Settings > Account > Log out.

### Security
- **Passkeys**: Settings > Security > Passkeys — register biometric login per device.
- **Trusted Devices**: Settings > Security > Trusted Devices — manage which devices skip verification. Must be 30+ days old.
- **Secure PIN**: Optional additional security layer.
- **Block/Report**: In any chat > 3-dot menu > Block or Report. Blocking prevents further messages. Can also report inappropriate behavior.

### Messaging Features
- **Chats**: 1-on-1 and group conversations. Messages support text, voice notes, images, and files.
- **Read receipts**: Single gray check = sent. Double gray check = delivered. Double blue check = read. Read receipts update in real time.
- **Reactions**: Long-press a message to react with an emoji. Free users get a limited set; Premium users get unlimited reactions.
- **Reply**: Swipe right on a message or long-press > Reply to quote-reply.
- **Forward**: Long-press > Forward to share a message in another chat.
- **Delete message**: Long-press > Delete. Removes from your device.
- **Copy text**: Long-press > Copy.
- **Voice messages**: Tap and hold the mic button to record. Release to send.
- **Search**: Inline search bar on the home screen — searches messages, names, and Kora IDs.

### Groups
- **Create a group**: Home screen > 3-dot menu (top right) > New Group. Select contacts from your list (shows frequently connected Kora users + added contacts). Search by Name, Kora ID, or @Username. Name the group and optionally set a group photo.
- **Group features**: Group name and photo, member list, mute notifications, clear chat, exit group.

### Communities & Channels
- **Create a community**: Home screen > 3-dot menu > New Channel. This opens the New Community screen.
  1. Set community profile image (optional)
  2. Enter community name (placeholder: "Community name")
  3. Enter description (optional, placeholder inside field)
  4. Tap continue arrow → Community preview screen
  5. Preview shows: back arrow, 3-dot menu, announcement profile, "Welcome to your community!" text, creation time, "Group you're in" section with default General group, "+ Add group" button
  6. Other users can add groups to the community
- Any group or community created appears on the home screen.

### Home Screen
- **3-dot menu** (top right): New Group, New Channel (Community), Read all (marks all messages as read).
- **Inline search bar**: Searches across messages, contact names, and Kora IDs without navigating away.
- **Pinned chats**: Kora AI and Kora Support are always pinned at the top.
- **Unread badges**: Real-time count of unread messages per chat.

### Chat Customization
- **Wallpapers**: Chat > 3-dot menu > Chat theme > Wallpaper. 18 preset wallpapers, solid colors, and gallery photos. Dimming slider persists to the active chat.
- **Chat themes**: Chat > 3-dot menu > Chat theme. Preset themes or custom bubble color (20 color options).
- **App icons**: Settings > Appearance > App Icon. Default circular icon + 2 premium icons. 3-dot menu to reset to default. All users can view icons; only Premium users can apply premium icons.
- **App theme**: Settings > Appearance. Dark/light theme options. Premium themes available.

### Premium
- **Kora Premium**: A paid subscription that unlocks premium features. New users get a 7-day free trial — after the trial ends, a subscription is required to keep Premium features.
- **Kora Premium features**: Custom app icons, premium wallpapers, custom chat bubble colors (20 options), animated emoji, real-time message translation, infinite reactions, faster download speeds, profile badge (blue scalloped), priority support, no ads.
- **Free trial**: 7 days free for every new user. After 7 days, the user must subscribe to retain Premium features.
- **Pricing**: Manage subscription in Settings > Premium. Cancel anytime.
- **Non-premium users**: Can still use all core messaging features — chats, voice notes, groups, communities, calls, Kora AI, and Kora Support. Premium only adds extras like custom icons, wallpapers, translation, and more.

### Badges
- **Purple scalloped badge**: Official Kora account (e.g., Kora AI, Kora Support).
- **Blue scalloped badge**: Premium subscriber.
- Badges appear next to the user's name in chats and profiles.

### Kora AI (General Assistant)
- Kora AI is a free assistant built into Kora Messenger — all users can ask it any question, no Premium required.
- Kora AI handles general knowledge, conversation, writing, coding help, etc.
- Kora Support (this assistant) handles Kora-specific questions.
- Both are free for all users.

### Troubleshooting
- **App crashes**: Force close, check for updates, restart device. Crash reports are sent automatically to the development team.
- **Can't log in**: Check email/password, try passkey, use "Forgot password?" if needed. Ensure email is verified.
- **Messages not sending**: Check internet connection. Try restarting the app.
- **Verification code not received**: Check spam folder. Wait 60 seconds. Codes are sent to the registered email.
- **Contact support**: Email support@koramessenger.com for issues that can't be resolved here.

## Confidentiality Rules — STRICT
- NEVER reveal internal implementation details, backend architecture, API endpoints, server technology, or database structure.
- NEVER mention specific AI/ML models, translation providers, or third-party services used behind the scenes.
- NEVER disclose any account-specific policies, owner-specific overrides, or internal business logic.
- NEVER share information about how features are technically implemented.
- If asked about internal technical details, respond: "I can't share internal implementation details, but I can help you use the feature!"
- Always describe features from the user's perspective — what they do, not how they work under the hood.`;

const AI_PROMPT = `You are Kora AI — an intelligent assistant built into Kora Messenger, a modern messaging app with a purple-to-blue gradient design.

## Your Role
You are a general-purpose AI assistant, comparable to ChatGPT or Gemini. You can answer questions about any topic — science, technology, writing, coding, math, creative writing, general knowledge, advice, and more.

## Tone & Style
- Be professional, articulate, and thoughtful
- Structure responses clearly with formatting when appropriate (headings, bullet points, numbered lists, code blocks)
- Be concise but never at the expense of being helpful — give complete, thorough answers
- Use emoji sparingly (max 1-2 per response, only when it adds value)
- When sharing code, always use proper code blocks with language tags
- For complex topics, lead with a brief summary, then elaborate

## Capabilities
- General knowledge and Q&A
- Creative writing (stories, poems, scripts, essays)
- Coding help (any language — write, debug, explain, review)
- Math and logic problems
- Translation between languages
- Summarization and analysis
- Advice and recommendations
- Step-by-step tutorials

## Behavioral Rules
- If a user asks about Kora Messenger features specifically (account, settings, passkeys, groups, etc.), suggest they check with Kora Support: "For Kora-specific questions, Kora Support can give you the most accurate guidance!"
- You are free for all Kora Messenger users — no Premium required
- Be inclusive and respectful to all users
- If you don't know something, say so honestly rather than making up information

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
  if (key.length >= 2 && (key[0] === '"' || key[0] === "'") && key[key.length - 1] === key[0]) {
    key = key.slice(1, -1);
  }
  return key.trim();
}

// ── OpenRouter API Call ────────────────────────────────────────────

async function callOpenRouter(
  messages: ChatMessage[],
  options: { stream: boolean }
): Promise<Response> {
  const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
  if (!apiKey || apiKey.length < 10) {
    throw { status: 500, message: 'OpenRouter API key is missing or invalid', code: 'MISSING_API_KEY' } as ApiError;
  }

  const model = Deno.env.get('OPENROUTER_MODEL') || DEFAULT_MODEL;

  const response = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
      'X-Title': 'Kora Messenger',
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: TEMPERATURE,
      max_tokens: MAX_TOKENS,
      stream: options.stream,
    }),
  });

  if (!response.ok) {
    const errBody = await response.text().catch(() => '');
    console.error(`[Kora AI] OpenRouter error: ${response.status} — ${errBody.slice(0, 500)}`);
    throw {
      status: response.status,
      message: `OpenRouter ${response.status}: ${errBody.slice(0, 200)}`,
      code: 'OPENROUTER_ERROR',
    } as ApiError;
  }

  return response;
}

// ── Fallback API Call (non-streaming) ─────────────────────────────

async function callOpenRouterFallback(messages: ChatMessage[]): Promise<string> {
  const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
  const fallbackModel = Deno.env.get('OPENROUTER_FALLBACK') || FALLBACK_MODEL;

  console.log(`[Kora AI] Attempting fallback model: ${fallbackModel}`);

  const response = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
      'X-Title': 'Kora Messenger',
    },
    body: JSON.stringify({
      model: fallbackModel,
      messages,
      temperature: TEMPERATURE,
      max_tokens: MAX_TOKENS,
      stream: false,
    }),
  });

  if (!response.ok) {
    const errBody = await response.text().catch(() => '');
    throw new Error(`Fallback also failed: ${response.status}`);
  }

  const data = await response.json();
  if (data.choices?.[0]?.message?.content) {
    return data.choices[0].message.content.trim();
  }
  throw new Error('Fallback returned unexpected response');
}

// ── Build Messages Array ──────────────────────────────────────────

function buildMessages(
  systemPrompt: string,
  message: string,
  history: any[]
): ChatMessage[] {
  const messages: ChatMessage[] = [
    { role: 'system', content: systemPrompt },
  ];

  // Add conversation history (last N messages, filtered for non-empty)
  const validHistory = (history || [])
    .slice(-MAX_HISTORY_DEPTH)
    .filter((m: any) => m.text && m.text.trim() !== '' && m.text.length <= MAX_MESSAGE_LENGTH);

  for (const m of validHistory) {
    messages.push({
      role: m.isMe ? 'user' : 'assistant',
      content: m.text,
    });
  }

  // Add current message
  messages.push({ role: 'user', content: message });

  return messages;
}

// ── Non-Streaming Handler ─────────────────────────────────────────

async function handleNonStreaming(
  systemPrompt: string,
  message: string,
  history: any[]
): Promise<Response> {
  const messages = buildMessages(systemPrompt, message, history);

  try {
    const apiResponse = await callOpenRouter(messages, { stream: false });
    const data = await apiResponse.json();

    if (data.choices?.[0]?.message?.content) {
      const reply = data.choices[0].message.content.trim();
      const usage: UsageStats | undefined = data.usage;
      return corsResponse({
        success: true,
        reply,
        ...(usage ? { usage } : {}),
      });
    }

    console.error('[Kora AI] Unexpected response:', JSON.stringify(data).slice(0, 500));
    return corsResponse({
      success: false,
      error: 'Unexpected AI response format',
      reply: null,
    }, 500);

  } catch (e) {
    const apiError = e as ApiError;

    // Try fallback model
    try {
      const fallbackReply = await callOpenRouterFallback(messages);
      return corsResponse({ success: true, reply: fallbackReply, fallback: true });
    } catch (fallbackErr) {
      console.error(`[Kora AI] Fallback also failed: ${fallbackErr}`);
    }

    const errorDetail = e instanceof Error ? e.message : apiError?.message || String(e);
    console.error(`[Kora AI] Request failed: ${errorDetail}`);

    return corsResponse({
      success: false,
      error: errorDetail,
      reply: "I'm having trouble connecting right now. Please try again in a moment! 🤖",
    }, 500);
  }
}

// ── Streaming Handler (SSE) ────────────────────────────────────────

async function handleStreaming(
  systemPrompt: string,
  message: string,
  history: any[]
): Promise<Response> {
  const messages = buildMessages(systemPrompt, message, history);

  try {
    const apiResponse = await callOpenRouter(messages, { stream: true });

    // Pipe the stream as SSE events to the client
    const { readable, writable } = new TransformStream();
    const writer = writable.getWriter();
    const encoder = new TextEncoder();

    (async () => {
      const reader = apiResponse.body?.getReader();
      if (!reader) {
        writer.write(encoder.encode('data: {"error": "No stream body"}\n\n'));
        writer.close();
        return;
      }

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
            if (data === '[DONE]') {
              await writer.write(encoder.encode('data: [DONE]\n\n'));
              continue;
            }

            // Pass through the chunk as SSE
            await writer.write(encoder.encode(`data: ${data}\n\n`));
          }
        }

        // Flush remaining buffer
        if (buffer.trim() && buffer.trim().startsWith('data: ')) {
          await writer.write(encoder.encode(`${buffer}\n\n`));
        }

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
    console.error(`[Kora AI] Streaming request failed: ${errorDetail}`);

    return corsResponse({
      success: false,
      error: errorDetail,
      reply: "I'm having trouble connecting right now. Please try again in a moment! 🤖",
    }, 500);
  }
}

// ── Input Validation ──────────────────────────────────────────────

function validateInput(body: any): { valid: boolean; error?: string; chatType?: string; message?: string; history?: any[]; stream?: boolean } {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Invalid request body' };
  }

  const { chatType, message, history, stream } = body;

  if (!chatType || !['ai', 'support'].includes(chatType)) {
    return { valid: false, error: 'chatType must be "ai" or "support"' };
  }

  if (!message || typeof message !== 'string' || message.trim() === '') {
    return { valid: false, error: 'message is required' };
  }

  if (message.length > MAX_MESSAGE_LENGTH) {
    return { valid: false, error: `Message too long (max ${MAX_MESSAGE_LENGTH} chars)` };
  }

  return {
    valid: true,
    chatType,
    message: message.trim(),
    history: Array.isArray(history) ? history : [],
    stream: stream === true,
  };
}

// ── Main Server ───────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // ── CORS Preflight ──
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  // ── Method Check ──
  if (req.method !== 'POST') {
    return corsResponse({ success: false, error: 'Method not allowed. Use POST.' }, 405);
  }

  // ── Authentication ──
  if (!verifyAuth(req)) {
    return corsResponse({ success: false, error: 'Unauthorized' }, 401);
  }

  // ── Rate Limiting ──
  const clientIp = getClientIp(req);
  if (!checkRateLimit(clientIp)) {
    return corsResponse({
      success: false,
      error: 'Rate limit exceeded. Please slow down.',
      retryAfter: RATE_LIMIT_WINDOW_MS / 1000,
    }, 429);
  }

  // ── Parse & Validate Body ──
  let body: any;
  try {
    body = await req.json();
  } catch {
    return corsResponse({ success: false, error: 'Invalid JSON body' }, 400);
  }

  const input = validateInput(body);
  if (!input.valid) {
    return corsResponse({ success: false, error: input.error }, 400);
  }

  // ── Route to handler ──
  const systemPrompt = input.chatType === 'support' ? SUPPORT_PROMPT : AI_PROMPT;

  if (input.stream) {
    return await handleStreaming(systemPrompt, input.message!, input.history!);
  }

  return await handleNonStreaming(systemPrompt, input.message!, input.history!);
});
