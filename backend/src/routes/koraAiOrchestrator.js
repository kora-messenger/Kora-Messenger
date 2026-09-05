const express = require('express');
const User = require('../models/User');

const router = express.Router();

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

// ── Constants ──────────────────────────────────────────────────────

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-api-key',
};

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

function verifyAuth(req) {
  const token = process.env.KORA_AI_AUTH_TOKEN || '';
  if (!token) return true;
  const auth = req.headers['authorization'] || req.headers['Authorization'];
  if (auth && auth.startsWith('Bearer ')) return auth.slice(7) === token;
  const apiKey = req.headers['x-api-key'] || req.headers['X-Api-Key'];
  return apiKey === token;
}

// ── Model Provider Adapter ────────────────────────────────────────

function getProvider(model) {
  const openrouterKey = (process.env.OPENROUTER_API_KEY || '').trim().replace(/^Bearer\s+/i, '');
  return {
    name: 'openrouter',
    model: model ?? PRIMARY_MODEL,
    async generate(messages, options = {}) {
      const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${openrouterKey}`,
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
            'Authorization': `Bearer ${openrouterKey}`,
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
    async stream(messages, options = {}) {
      const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${openrouterKey}`,
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

function buildOptimizedContext(history, currentMessage, maxMessages = 10) {
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

function getSystemPrompt(intent, userContext, request) {
  const baseParts = [
    `You are ${KORA_AI_CONFIG.assistant_name}, the AI assistant in Kora Messenger.`,
    `Personality: ${KORA_AI_CONFIG.personality}.`,
  ];

  KORA_AI_CONFIG.safety_rules.forEach((rule) => baseParts.push(`- ${rule}`));

  if (userContext) {
    if (userContext.fullName) baseParts.push(`\nThe user's name is ${userContext.fullName}.`);
    if (userContext.isPremium) baseParts.push(`The user is a Premium subscriber.`);
  }

  switch (intent) {
    case 'conversation':
      baseParts.push('\nYou are in a general conversation. Be helpful, friendly, and concise.');
      break;
    case 'translation': {
      const target = request?.targetLanguage?.trim();
      const source = request?.sourceLanguage?.trim();
      let langSpec = '';
      if (source && target) {
        langSpec = ` Translate the given text from ${source} into ${target}.`;
      } else if (target) {
        langSpec = ` Translate the given text into ${target}.`;
      } else {
        langSpec = ' Translate the given text. If no target language is specified, respond in the same language as the input.';
      }
      baseParts.push(`\nYou are a translation engine.${langSpec} Only output the translation, nothing else.`);
      break;
    }
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

const usageStore = new Map();
const USAGE_WINDOW = 3600_000; // 1 hour

const FREE_LIMITS = {
  conversation: 50, translation: 30, summarization: 20, writing: 30,
  reply_suggestions: 40, catch_me_up: 20, voice_transcribe: 15,
  file_analysis: 10, image_understanding: 30,
};
const PREMIUM_LIMITS = {
  conversation: 200, translation: 100, summarization: 50, writing: 100,
  reply_suggestions: 100, catch_me_up: 50, voice_transcribe: 50,
  file_analysis: 50, image_understanding: 100,
};

function checkUsage(userId, intent, isPremium) {
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

const PREMIUM_ONLY_FEATURES = ['file_analysis', 'voice_transcribe'];

async function checkEntitlement(req, intent, userEmail) {
  if (!userEmail) return { allowed: true, isPremium: false };
  if (!PREMIUM_ONLY_FEATURES.includes(intent)) return { allowed: true, isPremium: false };

  try {
    const email = String(userEmail).toLowerCase().trim();
    const user = await User.findOne({ email });
    if (user && (User.computeIsPremium ? User.computeIsPremium(user) : user.isPremium === true)) {
      return { allowed: true, isPremium: true };
    }
    return { allowed: false, isPremium: false, reason: 'This feature requires Kora Premium.' };
  } catch {
    return { allowed: true, isPremium: false };
  }
}

// ── Build Messages ────────────────────────────────────────────────

function buildMessages(systemPrompt, request) {
  const messages = [{ role: 'system', content: systemPrompt }];

  if (request.history && request.history.length > 0) {
    const optimized = buildOptimizedContext(request.history, request.message);
    for (const msg of optimized) {
      if (msg.role === 'system' && messages[0].role === 'system') {
        continue;
      }
      messages.push({ role: msg.role === 'user' ? 'user' : 'assistant', content: msg.content });
    }
  } else {
    messages.push({ role: 'user', content: request.message });
  }

  if (request.attachments && request.attachments.length > 0 && request.intent === 'image_understanding') {
    const content = [{ type: 'text', text: request.message }];
    for (const att of request.attachments) {
      if (att.type === 'image' && att.base64) {
        content.push({
          type: 'image_url',
          image_url: { url: `data:${att.mimeType ?? 'image/jpeg'};base64,${att.base64}` },
        });
      }
    }
    if (messages.length > 0 && messages[messages.length - 1].role === 'user') {
      messages[messages.length - 1] = { role: 'user', content };
    }
  }

  return messages;
}

// ── Streaming Handler ─────────────────────────────────────────────

async function handleStreaming(res, messages) {
  const provider = getProvider();
  try {
    const apiResponse = await provider.stream(messages);
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    Object.entries(CORS_HEADERS).forEach(([k, v]) => res.setHeader(k, v));
    if (typeof res.flushHeaders === 'function') res.flushHeaders();

    const reader = apiResponse.body?.getReader();
    if (!reader) {
      res.write('data: {"error": "No stream body"}\n\n');
      res.end();
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
            res.write('data: [DONE]\n\n');
            continue;
          }
          res.write(`data: ${data}\n\n`);
        }
      }
      res.write('data: [DONE]\n\n');
      res.end();
    } catch (err) {
      console.error('[Kora AI Orchestrator] Stream error:', err);
      res.write('data: {"error": "Stream interrupted"}\n\n');
      res.end();
    }
  } catch (e) {
    const err = e instanceof Error ? e.message : String(e);
    console.error('[Kora AI Orchestrator] Streaming failed:', err);
    if (!res.headersSent) {
      return res.status(500).json({ success: false, error: err, reply: "Kora AI couldn't complete that request. Please try again." });
    }
    res.write('data: {"error": "Stream interrupted"}\n\n');
    res.end();
  }
}

// ── Non-streaming Handler ─────────────────────────────────────────

async function handleNonStreaming(res, messages) {
  const provider = getProvider();
  try {
    const data = await provider.generate(messages);
    if (data.choices?.[0]?.message?.content) {
      const reply = data.choices[0].message.content.trim();
      return res.json({ success: true, reply, usage: data.usage });
    }
    return res.status(500).json({ success: false, error: 'Unexpected AI response format', reply: null });
  } catch (e) {
    const err = e instanceof Error ? e.message : String(e);
    console.error('[Kora AI Orchestrator] Request failed:', err);
    return res.status(500).json({ success: false, error: err, reply: "Kora AI couldn't complete that request. Please try again." });
  }
}

// ── Input Validation ──────────────────────────────────────────────

function validateRequest(body) {
  if (!body || typeof body !== 'object') return { valid: false, error: 'Invalid request body' };

  const validIntents = ['conversation', 'translation', 'summarization', 'writing',
    'reply_suggestions', 'catch_me_up', 'voice_transcribe', 'file_analysis', 'image_understanding'];

  const intent = body.intent;
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

// ── Main Server Router ────────────────────────────────────────────

router.options('/', (req, res) => {
  return res.sendStatus(204);
});

router.post('/', async (req, res) => {
  if (!verifyAuth(req)) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const body = req.body;
  const input = validateRequest(body);
  if (!input.valid || !input.request) {
    return res.status(400).json({ success: false, error: input.error });
  }

  const request = input.request;
  const userEmail = request.userContext?.email;

  // Premium entitlement check
  const entitlement = await checkEntitlement(req, request.intent, userEmail);
  if (!entitlement.allowed) {
    return res.status(403).json({ success: false, error: entitlement.reason ?? 'Premium required for this feature.', premium: true });
  }

  // Usage limit check
  const usage = checkUsage(userEmail ?? 'anonymous', request.intent, entitlement.isPremium);
  if (!usage.allowed) {
    return res.status(429).json({
      success: false,
      error: `Rate limit reached for ${request.intent}. Try again later or upgrade to Premium for higher limits.`,
      rateLimited: true,
      limit: usage.limit,
      remaining: 0,
    });
  }

  // Build system prompt based on intent
  const systemPrompt = getSystemPrompt(request.intent, request.userContext, request);

  // Build messages with context management
  const messages = buildMessages(systemPrompt, request);

  // Route to streaming or non-streaming
  if (request.stream) {
    return await handleStreaming(res, messages);
  }
  return await handleNonStreaming(res, messages);
});

router.all('/', (req, res) => {
  return res.status(405).json({ success: false, error: 'Method not allowed. Use POST.' });
});

module.exports = router;
