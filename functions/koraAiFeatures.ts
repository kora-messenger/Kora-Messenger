// Kora AI Features — Writing Assistant, Reply Suggestions, Chat Summary
// Uses OPENROUTER_API_KEY, OPENROUTER_MODEL, and KORA_AI_AUTH_TOKEN from environment.
// Replaces the old localhost:5000 dev server endpoints.

// ── Rate limiting ──
const rateMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 20; // 20 requests per minute per IP for feature endpoints

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateMap.get(ip);
  if (!entry || now > entry.resetAt) {
    rateMap.set(ip, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return true;
  }
  if (entry.count >= RATE_LIMIT_MAX) return false;
  entry.count++;
  return true;
}

function verifyAuth(req: Request): boolean {
  const expectedToken = Deno.env.get('KORA_AI_AUTH_TOKEN') || '';
  if (!expectedToken || expectedToken.length < 8) return true; // dev mode
  const authHeader = req.headers.get('Authorization') || '';
  if (authHeader.startsWith('Bearer ')) {
    return authHeader.slice(7).trim() === expectedToken;
  }
  return false;
}

function getClientIp(req: Request): string {
  return req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
}

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  });
}

function cleanApiKey(raw: string): string {
  let key = raw.trim();
  if (key.startsWith('api_key=')) key = key.slice('api_key='.length);
  if (key.startsWith('Bearer ')) key = key.slice('Bearer '.length);
  if (key.length >= 2 && (key[0] === '"' || key[0] === "'") && key[key.length - 1] === key[0]) {
    key = key.slice(1, -1);
  }
  return key.trim();
}

async function callOpenRouter(systemPrompt: string, userMessage: string): Promise<string> {
  const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
  if (!apiKey || apiKey.length < 10) throw new Error('OPENROUTER_API_KEY is missing or too short');

  const model = Deno.env.get('OPENROUTER_MODEL') || 'openai/gpt-4o';

  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
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
      temperature: 0.7,
      max_tokens: 1000,
    }),
  });

  if (!response.ok) {
    const errBody = await response.text().catch(() => '');
    throw new Error(`OpenRouter ${response.status}: ${errBody.slice(0, 200)}`);
  }

  const data = await response.json();
  if (data.choices?.[0]?.message?.content) {
    return data.choices[0].message.content.trim();
  }
  throw new Error('Unexpected OpenRouter response');
}

// ── Mode prompts for Writing Assistant ──
const WRITING_PROMPTS: Record<string, string> = {
  improve: 'You are a writing assistant. Improve the following text for clarity, flow, and impact. Keep the original meaning. Return ONLY the improved text, no explanations.',
  rewrite: 'You are a writing assistant. Rewrite the following text in a different way while keeping the same meaning. Return ONLY the rewritten text, no explanations.',
  fix_grammar: 'You are a grammar editor. Fix any grammar, spelling, or punctuation errors in the following text. Return ONLY the corrected text, no explanations.',
  friendly: 'You are a writing assistant. Rewrite the following text in a warm, friendly, casual tone. Return ONLY the rewritten text, no explanations.',
  professional: 'You are a writing assistant. Rewrite the following text in a professional, formal tone. Return ONLY the rewritten text, no explanations.',
  romantic: 'You are a writing assistant. Rewrite the following text in a romantic, affectionate tone. Return ONLY the rewritten text, no explanations.',
  funny: 'You are a writing assistant. Rewrite the following text in a humorous, funny tone. Keep it tasteful. Return ONLY the rewritten text, no explanations.',
  shorter: 'You are a writing assistant. Make the following text shorter while keeping the key message. Return ONLY the shortened text, no explanations.',
  longer: 'You are a writing assistant. Expand the following text with more detail and context while keeping the same meaning. Return ONLY the expanded text, no explanations.',
  translate: 'You are a translator. Translate the following text into the specified language. Return ONLY the translation, no explanations.',
};

const REPLY_SUGGESTIONS_PROMPT = `You are a messaging assistant. The user received a message and needs 3 short reply suggestions.

Rules:
- Generate exactly 3 reply options
- Each reply should be natural, concise (1-2 sentences max)
- Vary the tone: one casual/friendly, one direct/practical, one thoughtful/creative
- Return ONLY the 3 suggestions, one per line, numbered 1. 2. 3.
- No explanations, no extra text
- Match the language of the received message`;

const SUMMARY_PROMPT = `You are a chat summarizer. Summarize the following chat messages.

Rules:
- Be concise but capture key points
- Use bullet points for highlights
- Note any decisions, action items, or important questions
- If "catch me up" mode, focus on what the user missed and what needs their attention
- Keep it under 200 words
- Return ONLY the summary, no preamble`;

// ── Handlers ──

async function handleWriting(body: any): Promise<Response> {
  const { text, mode, targetLanguage } = body;
  if (!text || !text.trim()) return jsonResponse({ success: false, error: 'Text is required' }, 400);
  if (!mode) return jsonResponse({ success: false, error: 'Mode is required' }, 400);

  let prompt = WRITING_PROMPTS[mode] || WRITING_PROMPTS.improve;
  let userMessage = text;
  if (mode === 'translate' && targetLanguage) {
    userMessage = `Translate to ${targetLanguage}:\n\n${text}`;
  }

  try {
    const result = await callOpenRouter(prompt, userMessage);
    return jsonResponse({ success: true, result });
  } catch (e) {
    const err = e instanceof Error ? e.message : String(e);
    console.error(`[Kora AI Features] Writing failed — mode=${mode}, error=${err}`);
    return jsonResponse({ success: false, error: err, result: null }, 500);
  }
}

async function handleReplySuggestions(body: any): Promise<Response> {
  const { receivedMessage, contextMessages } = body;
  if (!receivedMessage || !receivedMessage.trim()) {
    return jsonResponse({ success: false, error: 'receivedMessage is required' }, 400);
  }

  let userMessage = `Received message: "${receivedMessage}"`;
  if (contextMessages && Array.isArray(contextMessages) && contextMessages.length > 0) {
    const context = contextMessages.slice(-5).map((m: any) => {
      const sender = m.sender || m.senderName || (m.isMe ? 'You' : 'Contact');
      return `${sender}: ${m.text || m.content || ''}`;
    }).join('\n');
    userMessage = `Conversation context:\n${context}\n\nReceived message: "${receivedMessage}"`;
  }

  try {
    const result = await callOpenRouter(REPLY_SUGGESTIONS_PROMPT, userMessage);
    // Parse numbered suggestions
    const suggestions = result
      .split('\n')
      .map((line: string) => line.replace(/^\d+\.\s*/, '').trim())
      .filter((line: string) => line.length > 0)
      .slice(0, 3);
    return jsonResponse({ success: true, suggestions });
  } catch (e) {
    const err = e instanceof Error ? e.message : String(e);
    console.error(`[Kora AI Features] Reply suggestions failed: ${err}`);
    return jsonResponse({ success: false, error: err, suggestions: [] }, 500);
  }
}

async function handleSummarize(body: any): Promise<Response> {
  const { messages, summaryType } = body;
  if (!messages || !Array.isArray(messages) || messages.length === 0) {
    return jsonResponse({ success: false, error: 'messages array is required' }, 400);
  }

  const type = summaryType || 'full';
  const formatted = messages.map((m: any) => {
    const sender = m.sender || m.senderName || (m.isMe ? 'You' : 'Contact');
    return `${sender}: ${m.text || m.content || ''}`;
  }).join('\n');

  const userMessage = type === 'catch_me_up'
    ? `The user has been away. Summarize what they missed (catch me up mode):\n\n${formatted}`
    : `Summarize this conversation:\n\n${formatted}`;

  try {
    const summary = await callOpenRouter(SUMMARY_PROMPT, userMessage);
    return jsonResponse({ success: true, summary });
  } catch (e) {
    const err = e instanceof Error ? e.message : String(e);
    console.error(`[Kora AI Features] Summarize failed: ${err}`);
    return jsonResponse({ success: false, error: err, summary: null }, 500);
  }
}

// ── Main server ──
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    });
  }

  // Auth
  if (!verifyAuth(req)) {
    return jsonResponse({ success: false, error: 'Unauthorized' }, 401);
  }

  // Rate limit
  const clientIp = getClientIp(req);
  if (!checkRateLimit(clientIp)) {
    return jsonResponse({ success: false, error: 'Rate limit exceeded. Please slow down.' }, 429);
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ success: false, error: 'Invalid JSON body' }, 400);
  }

  const { feature } = body;
  if (!feature) return jsonResponse({ success: false, error: 'feature is required (writing | reply_suggestions | summarize)' }, 400);

  switch (feature) {
    case 'writing':
      return await handleWriting(body);
    case 'reply_suggestions':
      return await handleReplySuggestions(body);
    case 'summarize':
      return await handleSummarize(body);
    default:
      return jsonResponse({ success: false, error: `Unknown feature: ${feature}. Valid: writing | reply_suggestions | summarize` }, 400);
  }
});
