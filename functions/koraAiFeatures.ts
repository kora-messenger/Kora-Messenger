/**
 * Kora AI Features — Production v3 (Multimodal)
 * Writing Assistant · Reply Suggestions · Chat Summary · Media Analysis
 *
 * v3 Changes:
 *   - NEW FEATURE: analyze_media — image and video frame analysis via GPT-4o vision
 *   - Accepts base64-encoded images and video frames
 *   - Returns detailed description, text extraction, code reading, etc.
 *
 * Features:
 *   writing            — 10 modes (improve, rewrite, grammar, tone, translate, etc.)
 *   reply_suggestions  — context-aware, 3 varied suggestions
 *   summarize           — full summary + "catch me up" mode
 *   analyze_media      — image/video frame analysis (NEW)
 *   transcribe_audio   — returns client-provided transcript with AI enhancement (NEW)
 */

// ── Types ──────────────────────────────────────────────────────────
interface ApiError { status: number; message: string; code: string; }
interface MediaAttachment {
  type: 'image' | 'video_frame';
  base64?: string;
  mimeType?: string;
  url?: string;
}

// ── Constants ──────────────────────────────────────────────────────
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 20;
const MAX_TEXT_LENGTH = 4000;
const MAX_MESSAGES = 100;
const MAX_TOKENS_WRITING = 1000;
const MAX_TOKENS_REPLY = 500;
const MAX_TOKENS_SUMMARY = 800;
const MAX_TOKENS_MEDIA = 1500;
const MAX_TOKENS_TRANSCRIBE = 1000;
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_MODEL = 'openai/gpt-4o';
const FALLBACK_MODEL = 'openai/gpt-4o-mini';
const MAX_IMAGE_SIZE_BYTES = 4 * 1024 * 1024;
const MAX_MEDIA_ATTACHMENTS = 5;

// ── Rate Limiter ───────────────────────────────────────────────────
const rateMap = new Map<string, { timestamps: number[] }>();
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
  return new Response(typeof data === 'string' ? data : JSON.stringify(data), {
    status, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

// ── API Key ───────────────────────────────────────────────────────
function cleanApiKey(raw: string): string {
  let key = raw.trim();
  if (key.startsWith('api_key=')) key = key.slice('api_key='.length);
  if (key.startsWith('Bearer ')) key = key.slice('Bearer '.length);
  if (key.length >= 2 && (key[0] === '"' || key[0] === "'") && key[key.length - 1] === key[0]) { key = key.slice(1, -1); }
  return key.trim();
}

// ── OpenRouter Call (text) ─────────────────────────────────────────
async function callOpenRouter(systemPrompt: string, userMessage: string, maxTokens: number, temperature = 0.7): Promise<string> {
  const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
  if (!apiKey || apiKey.length < 10) { throw { status: 500, message: 'API key missing', code: 'MISSING_API_KEY' } as ApiError; }
  const model = Deno.env.get('OPENROUTER_MODEL') || DEFAULT_MODEL;
  const response = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}`, 'X-Title': 'Kora Messenger AI Features' },
    body: JSON.stringify({ model, messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userMessage }], temperature, max_tokens: maxTokens, stream: false }),
  });
  if (!response.ok) {
    const errBody = await response.text().catch(() => '');
    throw { status: response.status, message: `OpenRouter ${response.status}: ${errBody.slice(0, 200)}`, code: 'OPENROUTER_ERROR' } as ApiError;
  }
  const data = await response.json();
  if (data.choices?.[0]?.message?.content) { return data.choices[0].message.content.trim(); }
  throw new Error('Unexpected OpenRouter response');
}

// ── OpenRouter Call (multimodal) ───────────────────────────────────
async function callOpenRouterMultimodal(systemPrompt: string, userContent: any[], maxTokens: number, temperature = 0.7): Promise<string> {
  const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
  if (!apiKey || apiKey.length < 10) { throw { status: 500, message: 'API key missing', code: 'MISSING_API_KEY' } as ApiError; }
  const model = Deno.env.get('OPENROUTER_MODEL') || DEFAULT_MODEL;
  const response = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}`, 'X-Title': 'Kora Messenger AI Features' },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userContent },
      ],
      temperature,
      max_tokens: maxTokens,
      stream: false,
    }),
  });
  if (!response.ok) {
    const errBody = await response.text().catch(() => '');
    throw { status: response.status, message: `OpenRouter ${response.status}: ${errBody.slice(0, 200)}`, code: 'OPENROUTER_ERROR' } as ApiError;
  }
  const data = await response.json();
  if (data.choices?.[0]?.message?.content) { return data.choices[0].message.content.trim(); }
  throw new Error('Unexpected OpenRouter response');
}

// ── Fallback ──────────────────────────────────────────────────────
async function callWithFallback(systemPrompt: string, userMessage: string, maxTokens: number, temperature?: number): Promise<string> {
  try {
    return await callOpenRouter(systemPrompt, userMessage, maxTokens, temperature);
  } catch (e) {
    const apiError = e as ApiError;
    if (apiError?.code === 'MISSING_API_KEY') throw e;
    const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
    const fallbackModel = Deno.env.get('OPENROUTER_FALLBACK') || FALLBACK_MODEL;
    console.log(`[Kora AI Features] Trying fallback: ${fallbackModel}`);
    const response = await fetch(OPENROUTER_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}`, 'X-Title': 'Kora Messenger AI Features' },
      body: JSON.stringify({ model: fallbackModel, messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userMessage }], temperature: temperature ?? 0.7, max_tokens: maxTokens, stream: false }),
    });
    if (!response.ok) throw e;
    const data = await response.json();
    if (data.choices?.[0]?.message?.content) { return data.choices[0].message.content.trim(); }
    throw e;
  }
}

// ── WRITING ────────────────────────────────────────────────────────
const WRITING_PROMPTS: Record<string, string> = {
  improve: `You are a skilled writing assistant for Kora Messenger. Improve the following text for clarity, flow, and impact while preserving the original meaning.\n\nRules:\n- Return ONLY the improved text — no explanations, no preamble\n- Fix awkward phrasing and improve word choice\n- Maintain the original language\n- Keep it natural and conversational`,
  rewrite: `You are a writing assistant for Kora Messenger. Rewrite the following text in a different way while keeping the same meaning.\n\nRules:\n- Return ONLY the rewritten text — no explanations\n- Use different sentence structure and word choice\n- Maintain the original language`,
  fix_grammar: `You are a grammar and spelling editor. Fix any grammar, spelling, or punctuation errors in the following text.\n\nRules:\n- Return ONLY the corrected text — no explanations\n- Preserve the original meaning and tone\n- Don't rewrite — only fix errors\n- Maintain the original language`,
  friendly: `You are a writing assistant for Kora Messenger. Rewrite the following text in a warm, friendly, casual tone — like texting a good friend.\n\nRules:\n- Return ONLY the rewritten text — no explanations\n- Keep it natural and conversational\n- Don't overdo the enthusiasm — authentic warmth, not corporate cheerfulness\n- Maintain the original language`,
  professional: `You are a writing assistant. Rewrite the following text in a professional, formal tone — suitable for a workplace message.\n\nRules:\n- Return ONLY the rewritten text — no explanations\n- Be polished but not stiff\n- Remove slang and overly casual phrasing\n- Maintain the original language`,
  romantic: `You are a writing assistant. Rewrite the following text in a romantic, affectionate tone — sincere, not cheesy.\n\nRules:\n- Return ONLY the rewritten text — no explanations\n- Be genuine and heartfelt\n- Avoid clichés and over-the-top declarations\n- Maintain the original language`,
  funny: `You are a writing assistant. Rewrite the following text in a humorous, witty tone — funny but not offensive.\n\nRules:\n- Return ONLY the rewritten text — no explanations\n- Keep it light and tasteful\n- The humor should come from wordplay or observation, not at anyone's expense\n- Maintain the original language`,
  shorter: `You are a writing assistant. Make the following text shorter while keeping the key message intact.\n\nRules:\n- Return ONLY the shortened text — no explanations\n- Cut filler, not substance\n- Aim for roughly half the length\n- Maintain the original language`,
  longer: `You are a writing assistant. Expand the following text with more detail and context while keeping the same meaning.\n\nRules:\n- Return ONLY the expanded text — no explanations\n- Add meaningful detail, not padding\n- Keep it natural — don't repeat the same idea in different words\n- Maintain the original language`,
  translate: `You are a professional translator. Translate the following text into the specified language.\n\nRules:\n- Return ONLY the translation — no explanations\n- Translate naturally, not word-for-word\n- Preserve tone and intent\n- Use the most common written form of the target language`,
};

async function handleWriting(body: any): Promise<Response> {
  const { text, mode, targetLanguage } = body;
  if (!text || typeof text !== 'string' || text.trim() === '') return corsResponse({ success: false, error: 'text is required' }, 400);
  if (text.length > MAX_TEXT_LENGTH) return corsResponse({ success: false, error: `Text too long (max ${MAX_TEXT_LENGTH} chars)` }, 400);
  if (!mode || !WRITING_PROMPTS[mode]) return corsResponse({ success: false, error: `Invalid mode. Valid: ${Object.keys(WRITING_PROMPTS).join(', ')}` }, 400);
  const prompt = WRITING_PROMPTS[mode];
  let userMessage = text;
  if (mode === 'translate' && targetLanguage) { userMessage = `Translate to ${targetLanguage}:\n\n${text}`; }
  try {
    const result = await callWithFallback(prompt, userMessage, MAX_TOKENS_WRITING, 0.7);
    return corsResponse({ success: true, result });
  } catch (e) {
    const err = e instanceof Error ? e.message : (e as ApiError)?.message || String(e);
    console.error(`[Kora AI] Writing failed — mode=${mode}: ${err}`);
    return corsResponse({ success: false, error: err, result: null }, 500);
  }
}

// ── REPLY SUGGESTIONS ─────────────────────────────────────────────
const REPLY_SUGGESTIONS_PROMPT = `You are a messaging assistant for Kora Messenger. The user received a message and needs 3 short reply suggestions.\n\nRules:\n- Generate exactly 3 reply options — no more, no less\n- Each reply must be natural and concise (1-2 sentences max)\n- Vary the tone: 1. Casual & friendly 2. Direct & practical 3. Thoughtful or creative\n- Return ONLY the 3 suggestions, one per line, numbered: 1. 2. 3.\n- No explanations, no extra text, no preamble\n- Match the language of the received message\n- Keep it appropriate for a messaging context\n- Don't include quotation marks around the suggestions`;

async function handleReplySuggestions(body: any): Promise<Response> {
  const { receivedMessage, contextMessages } = body;
  if (!receivedMessage || typeof receivedMessage !== 'string' || receivedMessage.trim() === '') return corsResponse({ success: false, error: 'receivedMessage is required' }, 400);
  if (receivedMessage.length > MAX_TEXT_LENGTH) return corsResponse({ success: false, error: 'Message too long' }, 400);
  let userMessage = `Received message: "${receivedMessage}"`;
  if (contextMessages && Array.isArray(contextMessages) && contextMessages.length > 0) {
    const context = contextMessages.slice(-5).filter((m: any) => m && (m.text || m.content)).map((m: any) => { const sender = m.sender || m.senderName || (m.isMe ? 'You' : 'Contact'); return `${sender}: ${m.text || m.content || ''}`; }).join('\n');
    if (context) { userMessage = `Conversation context:\n${context}\n\nReceived message: "${receivedMessage}"`; }
  }
  try {
    const result = await callWithFallback(REPLY_SUGGESTIONS_PROMPT, userMessage, MAX_TOKENS_REPLY, 0.8);
    const suggestions = result.split('\n').map((line: string) => line.replace(/^\d+\.\s*/, '').trim()).filter((line: string) => line.length > 0).slice(0, 3);
    return corsResponse({ success: true, suggestions });
  } catch (e) {
    const err = e instanceof Error ? e.message : (e as ApiError)?.message || String(e);
    console.error(`[Kora AI] Reply suggestions failed: ${err}`);
    return corsResponse({ success: false, error: err, suggestions: [] }, 500);
  }
}

// ── CHAT SUMMARY ──────────────────────────────────────────────────
const SUMMARY_PROMPT = `You are a chat summarizer for Kora Messenger. Summarize the following chat messages.\n\nRules:\n- Be concise but capture all key points\n- Use bullet points for highlights\n- Note any decisions, action items, or important questions\n- Mention who said what when it matters\n- Keep it under 200 words\n- Return ONLY the summary — no preamble\n- Maintain the original language of the conversation`;

const CATCH_ME_UP_PROMPT = `You are a chat assistant for Kora Messenger. The user has been away and needs to catch up.\n\nRules:\n- Focus on what the user missed — new messages, decisions, questions directed at them\n- Highlight anything that needs their attention or response\n- Use bullet points for clarity\n- Be brief — they want the gist, not a transcript\n- Keep it under 200 words\n- Return ONLY the summary — no preamble\n- If nothing important happened, say "You're all caught up! Nothing major missed."\n- Maintain the original language of the conversation`;

async function handleSummarize(body: any): Promise<Response> {
  const { messages, summaryType } = body;
  if (!messages || !Array.isArray(messages) || messages.length === 0) return corsResponse({ success: false, error: 'messages array is required' }, 400);
  if (messages.length > MAX_MESSAGES) return corsResponse({ success: false, error: `Too many messages (max ${MAX_MESSAGES})` }, 400);
  const type = summaryType === 'catch_me_up' ? 'catch_me_up' : 'full';
  const prompt = type === 'catch_me_up' ? CATCH_ME_UP_PROMPT : SUMMARY_PROMPT;
  const formatted = messages.filter((m: any) => m && (m.text || m.content)).map((m: any) => { const sender = m.sender || m.senderName || (m.isMe ? 'You' : 'Contact'); return `${sender}: ${m.text || m.content || ''}`; }).join('\n');
  if (!formatted.trim()) return corsResponse({ success: false, error: 'No valid messages to summarize' }, 400);
  const userMessage = type === 'catch_me_up' ? `The user has been away. Here's what happened:\n\n${formatted}` : `Summarize this conversation:\n\n${formatted}`;
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
//  FEATURE: ANALYZE MEDIA (image / video frames)
// ═══════════════════════════════════════════════════════════════════

const ANALYZE_MEDIA_PROMPT = `You are a visual AI assistant for Kora Messenger. The user has shared an image or video frame for you to analyze.

## Your Role
Analyze the visual content and provide a helpful, detailed response.

## What to Describe
- **Scene**: What's happening in the image? Where does it appear to be?
- **Objects**: What objects, people, animals, or text are visible?
- **Text extraction**: If there's readable text (signs, documents, code, screenshots), transcribe it exactly
- **Context**: What might the context be? (e.g., a screenshot of an app, a photo of nature, a diagram)
- **Details**: Colors, lighting, style, mood — mention relevant visual details

## Rules
- Be thorough but organized — use sections or bullet points for clarity
- If there's text, always transcribe it (especially for screenshots or documents)
- If it's a code screenshot, identify the language and explain what the code does
- If it's a chat screenshot, summarize the conversation
- If you're unsure about something, say so — don't hallucinate details
- If the user asked a specific question, answer it directly
- Keep it concise but complete — aim for 3-8 sentences unless more detail is needed
- Use emoji sparingly (max 1-2)`;

async function handleAnalyzeMedia(body: any): Promise<Response> {
  const { attachments, question } = body;

  if (!attachments || !Array.isArray(attachments) || attachments.length === 0) {
    return corsResponse({ success: false, error: 'attachments array is required' }, 400);
  }
  if (attachments.length > MAX_MEDIA_ATTACHMENTS) {
    return corsResponse({ success: false, error: `Too many attachments (max ${MAX_MEDIA_ATTACHMENTS})` }, 400);
  }

  // Filter valid media attachments
  const validAttachments: MediaAttachment[] = attachments.filter((att: any) => {
    if (!att || typeof att !== 'object') return false;
    if (!att.type || !['image', 'video_frame'].includes(att.type)) return false;
    if (!att.base64 && !att.url) return false;
    if (att.base64) {
      const approxSize = (att.base64.length * 3) / 4;
      if (approxSize > MAX_IMAGE_SIZE_BYTES) return false;
    }
    return true;
  });

  if (validAttachments.length === 0) {
    return corsResponse({ success: false, error: 'No valid image or video frame attachments found' }, 400);
  }

  // Build multimodal content array
  const contentParts: any[] = [];

  if (question && question.trim()) {
    contentParts.push({ type: 'text', text: question });
  } else {
    contentParts.push({ type: 'text', text: 'Please analyze this image and describe what you see.' });
  }

  for (const att of validAttachments) {
    const mimeType = att.mimeType || 'image/jpeg';
    const imageUrl = att.url || `data:${mimeType};base64,${att.base64}`;
    contentParts.push({
      type: 'image_url',
      image_url: { url: imageUrl },
    });
  }

  try {
    const result = await callOpenRouterMultimodal(ANALYZE_MEDIA_PROMPT, contentParts, MAX_TOKENS_MEDIA, 0.5);
    return corsResponse({ success: true, result, mediaCount: validAttachments.length });
  } catch (e) {
    const err = e instanceof Error ? e.message : (e as ApiError)?.message || String(e);
    console.error(`[Kora AI] Media analysis failed: ${err}`);

    // Try fallback model
    try {
      const apiKey = cleanApiKey(Deno.env.get('OPENROUTER_API_KEY') || '');
      const fallbackModel = Deno.env.get('OPENROUTER_FALLBACK') || FALLBACK_MODEL;
      const response = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}`, 'X-Title': 'Kora Messenger AI Features' },
        body: JSON.stringify({
          model: fallbackModel,
          messages: [
            { role: 'system', content: ANALYZE_MEDIA_PROMPT },
            { role: 'user', content: contentParts },
          ],
          temperature: 0.5,
          max_tokens: MAX_TOKENS_MEDIA,
          stream: false,
        }),
      });
      if (response.ok) {
        const data = await response.json();
        if (data.choices?.[0]?.message?.content) {
          return corsResponse({ success: true, result: data.choices[0].message.content.trim(), mediaCount: validAttachments.length, fallback: true });
        }
      }
    } catch (fallbackErr) {
      console.error(`[Kora AI] Media fallback failed: ${fallbackErr}`);
    }

    return corsResponse({ success: false, error: err, result: null }, 500);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FEATURE: TRANSCRIBE AUDIO (enhance client-provided transcript)
// ═══════════════════════════════════════════════════════════════════

const TRANSCRIBE_PROMPT = `You are a transcript enhancer for Kora Messenger. The user has transcribed a voice note on their device. Your job is to clean up the transcript.

Rules:
- Fix any obvious transcription errors (misheard words, missing punctuation)
- Add proper capitalization and punctuation
- Remove filler words if they make the text hard to read (um, uh, like)
- Do NOT change the meaning — only improve readability
- Return ONLY the cleaned transcript — no explanations
- If the transcript is empty or just noise, return "[No speech detected]"
- Maintain the original language`;

async function handleTranscribeAudio(body: any): Promise<Response> {
  const { transcript } = body;

  if (!transcript || typeof transcript !== 'string' || transcript.trim() === '') {
    return corsResponse({ success: false, error: 'transcript is required' }, 400);
  }
  if (transcript.length > MAX_TEXT_LENGTH) {
    return corsResponse({ success: false, error: `Transcript too long (max ${MAX_TEXT_LENGTH} chars)` }, 400);
  }

  try {
    const result = await callWithFallback(TRANSCRIBE_PROMPT, transcript, MAX_TOKENS_TRANSCRIBE, 0.3);
    return corsResponse({ success: true, result: result, original: transcript });
  } catch (e) {
    const err = e instanceof Error ? e.message : (e as ApiError)?.message || String(e);
    console.error(`[Kora AI] Transcribe failed: ${err}`);
    // Return the original transcript as fallback
    return corsResponse({ success: true, result: transcript, original: transcript, fallback: true });
  }
}

// ── MAIN SERVER ───────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST') return corsResponse({ success: false, error: 'Method not allowed. Use POST.' }, 405);
  if (!verifyAuth(req)) return corsResponse({ success: false, error: 'Unauthorized' }, 401);
  const clientIp = getClientIp(req);
  if (!checkRateLimit(clientIp)) return corsResponse({ success: false, error: 'Rate limit exceeded. Please slow down.' }, 429);
  let body: any;
  try { body = await req.json(); } catch { return corsResponse({ success: false, error: 'Invalid JSON body' }, 400); }
  const { feature } = body;
  if (!feature) return corsResponse({ success: false, error: 'feature is required: writing | reply_suggestions | summarize | analyze_media | transcribe_audio' }, 400);
  switch (feature) {
    case 'writing': return await handleWriting(body);
    case 'reply_suggestions': return await handleReplySuggestions(body);
    case 'summarize': return await handleSummarize(body);
    case 'analyze_media': return await handleAnalyzeMedia(body);
    case 'transcribe_audio': return await handleTranscribeAudio(body);
    case 'analyze_image': return await handleAnalyzeMedia(body); // alias
    case 'analyze_file': return await handleAnalyzeMedia(body); // alias
    default: return corsResponse({ success: false, error: `Unknown feature: ${feature}. Valid: writing | reply_suggestions | summarize | analyze_media | transcribe_audio` }, 400);
  }
});
