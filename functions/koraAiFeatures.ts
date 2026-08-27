/**
 * ═══════════════════════════════════════════════════════════════════
 *  Kora AI Features — Production v2
 *  Writing Assistant · Reply Suggestions · Chat Summary
 * ═══════════════════════════════════════════════════════════════════
 *
 *  Features:
 *    • Writing Assistant — 10 modes (improve, rewrite, grammar, tone, translate, etc.)
 *    • Reply Suggestions — context-aware, 3 varied suggestions
 *    • Chat Summary — full summary + "catch me up" mode
 *    • Bearer token authentication
 *    • Sliding-window rate limiting (20 req/min per IP)
 *    • Model fallback chain
 *    • Comprehensive error handling
 *
 *  Environment Variables:
 *    OPENROUTER_API_KEY   — Required
 *    OPENROUTER_MODEL      — Optional (default: openai/gpt-4o)
 *    OPENROUTER_FALLBACK   — Optional (default: openai/gpt-4o-mini)
 *    KORA_AI_AUTH_TOKEN    — Optional (if unset, open mode)
 *
 *  API Contract:
 *    POST /koraAiFeatures
 *    Body: { feature: "writing" | "reply_suggestions" | "summarize", ... }
 * ═══════════════════════════════════════════════════════════════════
 */

// ── Types ──────────────────────────────────────────────────────────

interface ApiError {
  status: number;
  message: string;
  code: string;
}

// ── Constants ──────────────────────────────────────────────────────

const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 20;
const MAX_TEXT_LENGTH = 4000;
const MAX_MESSAGES = 100;
const MAX_TOKENS_WRITING = 1000;
const MAX_TOKENS_REPLY = 500;
const MAX_TOKENS_SUMMARY = 800;
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_MODEL = 'openai/gpt-4o';
const FALLBACK_MODEL = 'openai/gpt-4o-mini';

// ── Rate Limiter ───────────────────────────────────────────────────

const rateMap = new Map<string, { timestamps: number[] }>();

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateMap.get(ip) ?? { timestamps: [] };
  const valid = entry.timestamps.filter((t) => now - t < RATE_LIMIT_WINDOW_MS);
  if (valid.length >= RATE_LIMIT_MAX) {
    rateMap.set(ip, { timestamps: valid });
    return false;
  }
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
  for (let i = 0; i < token.length; i++) {
    diff |= token.charCodeAt(i) ^ expectedToken.charCodeAt(i);
  }
  return diff === 0;
}

function getClientIp(req: Request): string {
  return req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
}

// ── CORS ──────────────────────────────────────────────────────────

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function corsResponse(data: unknown, status = 200): Response {
  return new Response(typeof data === 'string' ? data : JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

// ── API Key ───────────────────────────────────────────────────────

function cleanApiKey(raw: string): string {
  let key = raw.trim();
  if (key.startsWith('api_key=')) key = key.slice('api_key='.length);
  if (key.startsWith('Bearer ')) key = key.slice('Bearer '.length);
  if (key.length >= 2 && (key[0] === '"' || key[0] === "'") && key[key.length - 1] === key[0]) {
    key = key.slice(1, -1);
  }
  return key.trim();
}

// ── OpenRouter Call ────────────────────────────────────────────────

async function callOpenRouter(
  systemPrompt: string,
  userMessage: string,
  maxTokens: number,
  temperature = 0.7,
): Promise<string> {
  const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
  if (!apiKey || apiKey.length < 10) {
    throw { status: 500, message: 'API key missing', code: 'MISSING_API_KEY' } as ApiError;
  }

  const model = Deno.env.get('OPENROUTER_MODEL') || DEFAULT_MODEL;

  const response = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
      'X-Title': 'Kora Messenger AI Features',
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userMessage },
      ],
      temperature,
      max_tokens: maxTokens,
      stream: false,
    }),
  });

  if (!response.ok) {
    const errBody = await response.text().catch(() => '');
    throw {
      status: response.status,
      message: `OpenRouter ${response.status}: ${errBody.slice(0, 200)}`,
      code: 'OPENROUTER_ERROR',
    } as ApiError;
  }

  const data = await response.json();
  if (data.choices?.[0]?.message?.content) {
    return data.choices[0].message.content.trim();
  }
  throw new Error('Unexpected OpenRouter response');
}

// ── Fallback ──────────────────────────────────────────────────────

async function callWithFallback(
  systemPrompt: string,
  userMessage: string,
  maxTokens: number,
  temperature?: number,
): Promise<string> {
  try {
    return await callOpenRouter(systemPrompt, userMessage, maxTokens, temperature);
  } catch (e) {
    const apiError = e as ApiError;
    if (apiError?.code === 'MISSING_API_KEY') throw e;

    // Try fallback model
    const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
    const fallbackModel = Deno.env.get('OPENROUTER_FALLBACK') || FALLBACK_MODEL;
    console.log(`[Kora AI Features] Trying fallback: ${fallbackModel}`);

    const response = await fetch(OPENROUTER_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'X-Title': 'Kora Messenger AI Features',
      },
      body: JSON.stringify({
        model: fallbackModel,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userMessage },
        ],
        temperature: temperature ?? 0.7,
        max_tokens: maxTokens,
        stream: false,
      }),
    });

    if (!response.ok) throw e; // Re-throw original error

    const data = await response.json();
    if (data.choices?.[0]?.message?.content) {
      return data.choices[0].message.content.trim();
    }
    throw e;
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FEATURE: WRITING ASSISTANT
// ═══════════════════════════════════════════════════════════════════

const WRITING_PROMPTS: Record<string, string> = {
  improve: `You are a skilled writing assistant for Kora Messenger. Improve the following text for clarity, flow, and impact while preserving the original meaning.

Rules:
- Return ONLY the improved text — no explanations, no preamble
- Fix awkward phrasing and improve word choice
- Maintain the original language (English stays English, French stays French, etc.)
- Keep it natural and conversational — this is for a messaging app, not an essay`,

  rewrite: `You are a writing assistant for Kora Messenger. Rewrite the following text in a different way while keeping the same meaning.

Rules:
- Return ONLY the rewritten text — no explanations
- Use different sentence structure and word choice
- Maintain the original language
- Keep it natural for a messaging context`,

  fix_grammar: `You are a grammar and spelling editor. Fix any grammar, spelling, or punctuation errors in the following text.

Rules:
- Return ONLY the corrected text — no explanations
- Preserve the original meaning and tone
- Don't rewrite — only fix errors
- Maintain the original language`,

  friendly: `You are a writing assistant for Kora Messenger. Rewrite the following text in a warm, friendly, casual tone — like texting a good friend.

Rules:
- Return ONLY the rewritten text — no explanations
- Keep it natural and conversational
- Don't overdo the enthusiasm — authentic warmth, not corporate cheerfulness
- Maintain the original language`,

  professional: `You are a writing assistant. Rewrite the following text in a professional, formal tone — suitable for a workplace message.

Rules:
- Return ONLY the rewritten text — no explanations
- Be polished but not stiff
- Remove slang and overly casual phrasing
- Maintain the original language`,

  romantic: `You are a writing assistant. Rewrite the following text in a romantic, affectionate tone — sincere, not cheesy.

Rules:
- Return ONLY the rewritten text — no explanations
- Be genuine and heartfelt
- Avoid clichés and over-the-top declarations
- Maintain the original language`,

  funny: `You are a writing assistant. Rewrite the following text in a humorous, witty tone — funny but not offensive.

Rules:
- Return ONLY the rewritten text — no explanations
- Keep it light and tasteful
- The humor should come from wordplay or observation, not at anyone's expense
- Maintain the original language`,

  shorter: `You are a writing assistant. Make the following text shorter while keeping the key message intact.

Rules:
- Return ONLY the shortened text — no explanations
- Cut filler, not substance
- Aim for roughly half the length
- Maintain the original language`,

  longer: `You are a writing assistant. Expand the following text with more detail and context while keeping the same meaning.

Rules:
- Return ONLY the expanded text — no explanations
- Add meaningful detail, not padding
- Keep it natural — don't repeat the same idea in different words
- Maintain the original language`,

  translate: `You are a professional translator. Translate the following text into the specified language.

Rules:
- Return ONLY the translation — no explanations, no transliteration notes
- Translate naturally, not word-for-word
- Preserve tone and intent
- Use the most common written form of the target language`,
};

async function handleWriting(body: any): Promise<Response> {
  const { text, mode, targetLanguage } = body;

  if (!text || typeof text !== 'string' || text.trim() === '') {
    return corsResponse({ success: false, error: 'text is required' }, 400);
  }
  if (text.length > MAX_TEXT_LENGTH) {
    return corsResponse({ success: false, error: `Text too long (max ${MAX_TEXT_LENGTH} chars)` }, 400);
  }
  if (!mode || !WRITING_PROMPTS[mode]) {
    return corsResponse({
      success: false,
      error: `Invalid mode. Valid: ${Object.keys(WRITING_PROMPTS).join(', ')}`,
    }, 400);
  }

  const prompt = WRITING_PROMPTS[mode];
  let userMessage = text;
  if (mode === 'translate' && targetLanguage) {
    userMessage = `Translate to ${targetLanguage}:\n\n${text}`;
  }

  try {
    const result = await callWithFallback(prompt, userMessage, MAX_TOKENS_WRITING, 0.7);
    return corsResponse({ success: true, result });
  } catch (e) {
    const err = e instanceof Error ? e.message : (e as ApiError)?.message || String(e);
    console.error(`[Kora AI] Writing failed — mode=${mode}: ${err}`);
    return corsResponse({ success: false, error: err, result: null }, 500);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FEATURE: REPLY SUGGESTIONS
// ═══════════════════════════════════════════════════════════════════

const REPLY_SUGGESTIONS_PROMPT = `You are a messaging assistant for Kora Messenger. The user received a message and needs 3 short reply suggestions.

Rules:
- Generate exactly 3 reply options — no more, no less
- Each reply must be natural and concise (1-2 sentences max)
- Vary the tone across the 3 options:
  1. Casual & friendly (how you'd text a close friend)
  2. Direct & practical (gets straight to the point)
  3. Thoughtful or creative (adds something interesting)
- Return ONLY the 3 suggestions, one per line, numbered: 1. 2. 3.
- No explanations, no extra text, no preamble
- Match the language of the received message (English → English, French → French, etc.)
- Keep it appropriate for a messaging context
- Don't include quotation marks around the suggestions`;

async function handleReplySuggestions(body: any): Promise<Response> {
  const { receivedMessage, contextMessages } = body;

  if (!receivedMessage || typeof receivedMessage !== 'string' || receivedMessage.trim() === '') {
    return corsResponse({ success: false, error: 'receivedMessage is required' }, 400);
  }
  if (receivedMessage.length > MAX_TEXT_LENGTH) {
    return corsResponse({ success: false, error: 'Message too long' }, 400);
  }

  let userMessage = `Received message: "${receivedMessage}"`;

  if (contextMessages && Array.isArray(contextMessages) && contextMessages.length > 0) {
    const context = contextMessages
      .slice(-5)
      .filter((m: any) => m && (m.text || m.content))
      .map((m: any) => {
        const sender = m.sender || m.senderName || (m.isMe ? 'You' : 'Contact');
        return `${sender}: ${m.text || m.content || ''}`;
      })
      .join('\n');

    if (context) {
      userMessage = `Conversation context:\n${context}\n\nReceived message: "${receivedMessage}"`;
    }
  }

  try {
    const result = await callWithFallback(
      REPLY_SUGGESTIONS_PROMPT,
      userMessage,
      MAX_TOKENS_REPLY,
      0.8,
    );

    const suggestions = result
      .split('\n')
      .map((line: string) => line.replace(/^\d+\.\s*/, '').trim())
      .filter((line: string) => line.length > 0)
      .slice(0, 3);

    return corsResponse({ success: true, suggestions });
  } catch (e) {
    const err = e instanceof Error ? e.message : (e as ApiError)?.message || String(e);
    console.error(`[Kora AI] Reply suggestions failed: ${err}`);
    return corsResponse({ success: false, error: err, suggestions: [] }, 500);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FEATURE: CHAT SUMMARY
// ═══════════════════════════════════════════════════════════════════

const SUMMARY_PROMPT = `You are a chat summarizer for Kora Messenger. Summarize the following chat messages for the user.

Rules:
- Be concise but capture all key points
- Use bullet points for highlights
- Note any decisions made, action items, or important questions asked
- Mention who said what when it matters
- Keep it under 200 words
- Return ONLY the summary — no preamble, no "Here's your summary:" intro
- Maintain the original language of the conversation`;

const CATCH_ME_UP_PROMPT = `You are a chat assistant for Kora Messenger. The user has been away and needs to catch up on what they missed.

Rules:
- Focus on what the user missed — new messages, decisions, questions directed at them
- Highlight anything that needs their attention or response
- Use bullet points for clarity
- Be brief — they want the gist, not a transcript
- Keep it under 200 words
- Return ONLY the summary — no preamble
- If nothing important happened, say "You're all caught up! Nothing major missed."
- Maintain the original language of the conversation`;

async function handleSummarize(body: any): Promise<Response> {
  const { messages, summaryType } = body;

  if (!messages || !Array.isArray(messages) || messages.length === 0) {
    return corsResponse({ success: false, error: 'messages array is required' }, 400);
  }
  if (messages.length > MAX_MESSAGES) {
    return corsResponse({ success: false, error: `Too many messages (max ${MAX_MESSAGES})` }, 400);
  }

  const type = summaryType === 'catch_me_up' ? 'catch_me_up' : 'full';
  const prompt = type === 'catch_me_up' ? CATCH_ME_UP_PROMPT : SUMMARY_PROMPT;

  const formatted = messages
    .filter((m: any) => m && (m.text || m.content))
    .map((m: any) => {
      const sender = m.sender || m.senderName || (m.isMe ? 'You' : 'Contact');
      return `${sender}: ${m.text || m.content || ''}`;
    })
    .join('\n');

  if (!formatted.trim()) {
    return corsResponse({ success: false, error: 'No valid messages to summarize' }, 400);
  }

  const userMessage = type === 'catch_me_up'
    ? `The user has been away. Here's what happened:\n\n${formatted}`
    : `Summarize this conversation:\n\n${formatted}`;

  try {
    const summary = await callWithFallback(prompt, userMessage, MAX_TOKENS_SUMMARY, 0.5);
    return corsResponse({ success: true, summary, type });
  } catch (e) {
    const err = e instanceof Error ? e.message : (e as ApiError)?.message || String(e);
    console.error(`[Kora AI] Summarize failed: ${err}`);
    return corsResponse({ success: false, error: err, summary: null }, 500);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  MAIN SERVER
// ═══════════════════════════════════════════════════════════════════

Deno.serve(async (req: Request) => {
  // ── CORS Preflight ──
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  // ── Method Check ──
  if (req.method !== 'POST') {
    return corsResponse({ success: false, error: 'Method not allowed. Use POST.' }, 405);
  }

  // ── Auth ──
  if (!verifyAuth(req)) {
    return corsResponse({ success: false, error: 'Unauthorized' }, 401);
  }

  // ── Rate Limit ──
  const clientIp = getClientIp(req);
  if (!checkRateLimit(clientIp)) {
    return corsResponse({
      success: false,
      error: 'Rate limit exceeded. Please slow down.',
    }, 429);
  }

  // ── Parse Body ──
  let body: any;
  try {
    body = await req.json();
  } catch {
    return corsResponse({ success: false, error: 'Invalid JSON body' }, 400);
  }

  // ── Route ──
  const { feature } = body;
  if (!feature) {
    return corsResponse({
      success: false,
      error: 'feature is required: writing | reply_suggestions | summarize',
    }, 400);
  }

  switch (feature) {
    case 'writing':
      return await handleWriting(body);
    case 'reply_suggestions':
      return await handleReplySuggestions(body);
    case 'summarize':
      return await handleSummarize(body);
    default:
      return corsResponse({
        success: false,
        error: `Unknown feature: ${feature}. Valid: writing | reply_suggestions | summarize`,
      }, 400);
  }
});
