/**
 * ═══════════════════════════════════════════════════════════════════
 *  Kora AI Orchestrator — Central AI Operation Coordinator
 *  
 *  Routes AI requests to the appropriate handler based on intent:
 *  - conversation (general chat)
 *  - translation
 *  - summarization
 *  - writing (writing assistant)
 *  - reply_suggestions
 *  - catch_me_up (catch up on messages)
 *  - voice_transcribe
 *  - file_analysis
 *  - image_understanding
 *  
 *  Uses Model Adapter pattern — can switch providers without app changes.
 *  Provider keys are NEVER exposed to the client.
 * ═══════════════════════════════════════════════════════════════════
 */

import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

// ── Types ──────────────────────────────────────────────────────────

type AIIntent = 'conversation' | 'translation' | 'summarization' | 'writing' | 
                 'reply_suggestions' | 'catch_me_up' | 'voice_transcribe' | 'file_analysis' | 'image_understanding';

interface AIRequest {
  intent: AIIntent;
  message: string;
  conversationId?: string;
  history?: Array<{ role: string; content: string }>;
  targetLanguage?: string;
  sourceLanguage?: string;
  mode?: string; // for writing: improve, rewrite, fix_grammar, etc.
  attachments?: Array<{
    type: string;
    base64?: string;
    mimeType?: string;
    transcript?: string;
    fileName?: string;
  }>;
  userContext?: {
    fullName?: string;
    username?: string;
    email?: string;
    koraId?: string;
    isPremium?: boolean;
    bio?: string;
  };
  stream?: boolean;
}

// ── Constants ──────────────────────────────────────────────────────

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-api-key',
};

const AI_AUTH_TOKEN = Deno.env.get('KORA_AI_AUTH_TOKEN') ?? '';
const OPENROUTER_KEY = (Deno.env.get('OPENROUTER_API_KEY') ?? '').trim().replace(/^Bearer\s+/i, '');
const PRIMARY_MODEL = 'meta-llama/llama-3.3-70b-instruct';
const FALLBACK_MODEL = 'meta-llama/llama-3.1-8b-instruct:free';

// ── Kora AI Configuration (Versioned, Server-side) ────────────────

const KORA_AI_CONFIG = {
  assistant_name: 'Kora AI',
  personality: 'helpful, intelligent, friendly and concise',
  version: '1.0',
  safety_rules: [
    'Never disclose internal implementation details, specific translation providers, or owner-specific account policies',
    'Never generate harmful, illegal, or inappropriate content',
    'Respect user privacy — never ask for sensitive personal data',
    'Keep responses concise and natural',
  ],
};

// ── Auth & CORS ────────────────────────────────────────────────────

function verifyAuth(req: Request): boolean {
  if (!AI_AUTH_TOKEN) return true;
  const auth = req.headers.get('Authorization');
  if (auth?.startsWith('Bearer ')) return auth.slice(7) === AI_AUTH_TOKEN;
  return req.headers.get('x-api-key') === AI_AUTH_TOKEN;
}

function corsResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function sseHeaders(): Record<string, string> {
  return { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive', ...CORS_HEADERS };
}

// ── Model Provider Adapter ────────────────────────────────────────

interface AIModelProvider {
  name: string;
  model: string;
  generate(messages: any[], options?: any): Promise<any>;
  stream(messages: any[], options?: any): Promise<Response>;
}

function getProvider(model?: string): AIModelProvider {
  return {
    name: 'openrouter',
    model: model ?? PRIMARY_MODEL,
    async generate(messages: any[], options: any = {}) {
      const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${OPENROUTER_KEY}`,
          'HTTP-Referer': 'https://kora-messenger.github.io',
        },
        body: JSON.stringify({
          model: options.model ?? PRIMARY_MODEL,
          messages,
          temperature: options.temperature ?? 0.7,
          max_tokens: options.maxTokens ?? 1000,
          stream: false,
        }),
      });
      if (!res.ok) {
        // Fallback to free model
        const fb = await fetch('https://openrouter.ai/api/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${OPENROUTER_KEY}`,
            'HTTP-Referer': 'https://kora-messenger.github.io',
          },
          body: JSON.stringify({
            model: FALLBACK_MODEL,
            messages,
            temperature: options.temperature ?? 0.7,
            max_tokens: options.maxTokens ?? 800,
            stream: false,
          }),
        });
        if (!fb.ok) throw new Error(`AI provider error: ${fb.status}`);
        return fb.json();
      }
      return res.json();
    },
    async stream(messages: any[], options: any = {}) {
      const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${OPENROUTER_KEY}`,
          'HTTP-Referer': 'https://kora-messenger.github.io',
        },
        body: JSON.stringify({
          model: options.model ?? PRIMARY_MODEL,
          messages,
          temperature: options.temperature ?? 0.7,
          max_tokens: options.maxTokens ?? 1000,
          stream: true,
        }),
      });
      if (!res.ok) throw new Error(`AI stream error: ${res.status}`);
      return res;
    },
  };
}

// ── Context Manager ───────────────────────────────────────────────

function buildOptimizedContext(
  history: Array<{ role: string; content: string }>,
  currentMessage: string,
  maxMessages: number = 10,
): Array<{ role: string; content: string }> {
  if (history.length <= maxMessages) {
    return [...history, { role: 'user', content: currentMessage }];
  }
  // Keep recent messages + summarize marker for older ones
  const recent = history.slice(-maxMessages);
  return [
    { role: 'system', content: `[Earlier conversation context — ${history.length - maxMessages} older messages omitted for brevity]` },
    ...recent,
    { role: 'user', content: currentMessage },
  ];
}

// ── Intent-specific System Prompts ───────────────────────────────

function getSystemPrompt(intent: AIIntent, userContext?: any): string {
  const baseParts: string[] = [
    `You are ${KORA_AI_CONFIG.assistant_name}, the AI assistant in Kora Messenger.`,
    `Personality: ${KORA_AI_CONFIG.personality}.`,
  ];
  
  KORA_AI_CONFIG.safety_rules.forEach(rule => baseParts.push(`- ${rule}`));
  
  if (userContext) {
    if (userContext.fullName) baseParts.push(`\nThe user's name is ${userContext.fullName}.`);
    if (userContext.isPremium) baseParts.push(`The user is a Premium subscriber.`);
  }
  
  switch (intent) {
    case 'conversation':
      baseParts.push('\nYou are in a general conversation. Be helpful, friendly, and concise.');
      break;
    case 'translation':
      baseParts.push('\nYou are a translation engine. Translate the given text accurately. Only output the translation, nothing else.');
      break;
    case 'summarization':
      baseParts.push('\nYou are a summarization engine. Provide a concise summary of the given text. Capture key points only.');
      break;
    case 'writing':
      baseParts.push('\nYou are a writing assistant. Help the user improve their writing based on the specified mode. Output only the improved text.');
      break;
    case 'reply_suggestions':
      baseParts.push('\nYou are a reply suggestion engine. Given a message, suggest 3 short, natural replies the user might send. Output each on a new line with a number prefix.');
      break;
    case 'catch_me_up':
      baseParts.push('\nYou are a catch-up assistant. Given a list of recent messages, provide a brief summary of what the user missed. Highlight mentions, questions, and important topics.');
      break;
    case 'voice_transcribe':
      baseParts.push('\nYou are a transcription assistant. Clean up the given transcript, fix grammar, and add punctuation. Output only the cleaned text.');
      break;
    case 'file_analysis':
      baseParts.push('\nYou are a document analysis assistant. Analyze the provided file content and answer questions about it.');
      break;
    case 'image_understanding':
      baseParts.push('\nYou are an image understanding assistant. Describe and analyze the provided image. Answer questions about its content.');
      break;
  }
  
  return baseParts.join('\n');
}

// ── Usage Tracking ────────────────────────────────────────────────

const usageStore = new Map<string, { count: number; windowStart: number }>();
const USAGE_WINDOW = 3600_000; // 1 hour

const FREE_LIMITS: Record<string, number> = {
  conversation: 50, translation: 30, summarization: 20, writing: 30,
  reply_suggestions: 40, catch_me_up: 20, voice_transcribe: 15,
  file_analysis: 10, image_understanding: 30,
};
const PREMIUM_LIMITS: Record<string, number> = {
  conversation: 200, translation: 100, summarization: 50, writing: 100,
  reply_suggestions: 100, catch_me_up: 50, voice_transcribe: 50,
  file_analysis: 50, image_understanding: 100,
};

function checkUsage(userId: string, intent: AIIntent, isPremium: boolean): { allowed: boolean; remaining: number; limit: number } {
  const key = `${userId}:${intent}`;
  const now = Date.now();
  const limits = isPremium ? PREMIUM_LIMITS : FREE_LIMITS;
  const limit = limits[intent] ?? 50;
  
  const record = usageStore.get(key);
  if (!record || now - record.windowStart > USAGE_WINDOW) {
    usageStore.set(key, { count: 1, windowStart: now });
    return { allowed: true, remaining: limit - 1, limit };
  }
  if (record.count >= limit) return { allowed: false, remaining: 0, limit };
  record.count++;
  return { allowed: true, remaining: limit - record.count, limit };
}

// ── Premium Entitlement Check ─────────────────────────────────────

const PREMIUM_ONLY_FEATURES: AIIntent[] = ['file_analysis', 'voice_transcribe' /* voice AI is premium */];
// Note: basic conversation, image understanding, writing, reply, summary, catch_me_up, translation are FREE

async function checkEntitlement(req: Request, intent: AIIntent, userEmail?: string): Promise<{ allowed: boolean; isPremium: boolean; reason?: string }> {
  // If no email, allow with free limits
  if (!userEmail) return { allowed: true, isPremium: false };
  
  // Check if feature requires premium
  if (!PREMIUM_ONLY_FEATURES.includes(intent)) return { allowed: true, isPremium: false };
  
  // Check database for premium status
  try {
    const client = createClientFromRequest(req);
    const users = await client.entities.KoraUser.list({ filter: { email: userEmail } });
    if (users.length > 0 && users[0].isPremium === true) {
      return { allowed: true, isPremium: true };
    }
    return { allowed: false, isPremium: false, reason: 'This feature requires Kora Premium.' };
  } catch {
    // If DB check fails, allow (fail open for user experience)
    return { allowed: true, isPremium: false };
  }
}

// ── Build Messages ────────────────────────────────────────────────

function buildMessages(
  systemPrompt: string,
  request: AIRequest,
): any[] {
  const messages: any[] = [{ role: 'system', content: systemPrompt }];
  
  // Add history (optimized)
  if (request.history && request.history.length > 0) {
    const optimized = buildOptimizedContext(request.history, request.message);
    for (const msg of optimized) {
      if (msg.role === 'system' && messages[0].role === 'system') {
        // Skip system messages from history (already have our own)
        continue;
      }
      messages.push({ role: msg.role === 'user' ? 'user' : 'assistant', content: msg.content });
    }
  } else {
    messages.push({ role: 'user', content: request.message });
  }
  
  // Handle attachments for image understanding
  if (request.attachments && request.attachments.length > 0 && request.intent === 'image_understanding') {
    const content: any[] = [{ type: 'text', text: request.message }];
    for (const att of request.attachments) {
      if (att.type === 'image' && att.base64) {
        content.push({
          type: 'image_url',
          image_url: { url: `data:${att.mimeType ?? 'image/jpeg'};base64,${att.base64}` },
        });
      }
    }
    // Replace last user message with multimodal content
    if (messages.length > 0 && messages[messages.length - 1].role === 'user') {
      messages[messages.length - 1] = { role: 'user', content };
    }
  }
  
  return messages;
}

// ── Streaming Handler ─────────────────────────────────────────────

async function handleStreaming(messages: any[]): Promise<Response> {
  const provider = getProvider();
  try {
    const apiResponse = await provider.stream(messages);
    const { readable, writable } = new TransformStream();
    const writer = writable.getWriter();
    const encoder = new TextEncoder();
    
    (async () => {
      const reader = apiResponse.body?.getReader();
      if (!reader) {
        await writer.write(encoder.encode('data: {"error": "No stream body"}\n\n'));
        await writer.close();
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
            await writer.write(encoder.encode(`data: ${data}\n\n`));
          }
        }
        await writer.write(encoder.encode('data: [DONE]\n\n'));
        await writer.close();
      } catch (err) {
        console.error('[Kora AI Orchestrator] Stream error:', err);
        await writer.write(encoder.encode(`data: {"error": "Stream interrupted"}\n\n`));
        await writer.close();
      }
    })();
    
    return new Response(readable, { headers: sseHeaders() });
  } catch (e) {
    const err = e instanceof Error ? e.message : String(e);
    console.error('[Kora AI Orchestrator] Streaming failed:', err);
    return corsResponse({ success: false, error: err, reply: 'Kora AI couldn\'t complete that request. Please try again.' }, 500);
  }
}

// ── Non-streaming Handler ─────────────────────────────────────────

async function handleNonStreaming(messages: any[]): Promise<Response> {
  const provider = getProvider();
  try {
    const data = await provider.generate(messages);
    if (data.choices?.[0]?.message?.content) {
      const reply = data.choices[0].message.content.trim();
      return corsResponse({ success: true, reply, usage: data.usage });
    }
    return corsResponse({ success: false, error: 'Unexpected AI response format', reply: null }, 500);
  } catch (e) {
    const err = e instanceof Error ? e.message : String(e);
    console.error('[Kora AI Orchestrator] Request failed:', err);
    return corsResponse({ success: false, error: err, reply: 'Kora AI couldn\'t complete that request. Please try again.' }, 500);
  }
}

// ── Input Validation ──────────────────────────────────────────────

function validateRequest(body: any): { valid: boolean; error?: string; request?: AIRequest } {
  if (!body || typeof body !== 'object') return { valid: false, error: 'Invalid request body' };
  
  const validIntents: AIIntent[] = ['conversation', 'translation', 'summarization', 'writing', 
    'reply_suggestions', 'catch_me_up', 'voice_transcribe', 'file_analysis', 'image_understanding'];
  
  const intent = body.intent as AIIntent;
  if (!intent || !validIntents.includes(intent)) return { valid: false, error: `Invalid intent. Must be one of: ${validIntents.join(', ')}` };
  
  if (!body.message || typeof body.message !== 'string' || body.message.trim() === '') {
    return { valid: false, error: 'message is required' };
  }
  
  if (body.message.length > 8000) return { valid: false, error: 'Message too long (max 8000 chars)' };
  
  return {
    valid: true,
    request: {
      intent,
      message: body.message.trim(),
      conversationId: body.conversationId,
      history: Array.isArray(body.history) ? body.history : [],
      targetLanguage: body.targetLanguage,
      sourceLanguage: body.sourceLanguage,
      mode: body.mode,
      attachments: Array.isArray(body.attachments) ? body.attachments : undefined,
      userContext: body.userContext,
      stream: body.stream === true,
    },
  };
}

// ── Main Server ───────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST') return corsResponse({ success: false, error: 'Method not allowed. Use POST.' }, 405);
  if (!verifyAuth(req)) return corsResponse({ success: false, error: 'Unauthorized' }, 401);
  
  let body: any;
  try { body = await req.json(); } catch { return corsResponse({ success: false, error: 'Invalid JSON body' }, 400); }
  
  const input = validateRequest(body);
  if (!input.valid || !input.request) return corsResponse({ success: false, error: input.error }, 400);
  
  const request = input.request;
  const userEmail = request.userContext?.email;
  
  // ── Premium entitlement check ──
  const entitlement = await checkEntitlement(req, request.intent, userEmail);
  if (!entitlement.allowed) {
    return corsResponse({ success: false, error: entitlement.reason ?? 'Premium required for this feature.', premium: true }, 403);
  }
  
  // ── Usage limit check ──
  const usage = checkUsage(userEmail ?? 'anonymous', request.intent, entitlement.isPremium);
  if (!usage.allowed) {
    return corsResponse({ 
      success: false, 
      error: `Rate limit reached for ${request.intent}. Try again later or upgrade to Premium for higher limits.`,
      rateLimited: true,
      limit: usage.limit,
      remaining: 0,
    }, 429);
  }
  
  // ── Build system prompt based on intent ──
  const systemPrompt = getSystemPrompt(request.intent, request.userContext);
  
  // ── Build messages with context management ──
  const messages = buildMessages(systemPrompt, request);
  
  // ── Route to streaming or non-streaming ──
  if (request.stream) {
    return await handleStreaming(messages);
  }
  return await handleNonStreaming(messages);
});
