const express = require('express');

const router = express.Router();

// Kora GPT Translation — streaming + batch
// Models AI Phone's /phone/ai/call/v3/gptTrans/stream architecture.
//
// Pipeline: text → language detection → GPT streaming translation → response
// Fallback: Google Translate → MyMemory → OpenRouter LLM
//
// Uses OPENROUTER_API_KEY from environment.

// Language detection by Unicode ranges (fast, offline)
function detectLanguage(text) {
  if (!text || !text.trim()) return 'en';
  if (/[\u0600-\u06FF]/.test(text)) return 'ar';
  if (/[\u0590-\u05FF]/.test(text)) return 'he';
  if (/[\u0400-\u04FF]/.test(text)) return 'ru';
  if (/[\u4E00-\u9FFF]/.test(text)) return 'zh';
  if (/[\u3040-\u309F\u30A0-\u30FF]/.test(text)) return 'ja';
  if (/[\uAC00-\uD7AF]/.test(text)) return 'ko';
  if (/[\u0E00-\u0E7F]/.test(text)) return 'th';
  if (/[\u0900-\u097F]/.test(text)) return 'hi';
  if (/[\u0980-\u09FF]/.test(text)) return 'bn';
  if (/[\u0B80-\u0BFF]/.test(text)) return 'ta';
  if (/[\u0C00-\u0C7F]/.test(text)) return 'te';
  if (/[\u1200-\u137F]/.test(text)) return 'am';
  if (/[\u0370-\u03FF]/.test(text)) return 'el';
  if (/[\u0E00-\u0E7F]/.test(text)) return 'th';
  if (/[ñ¿¡]/.test(text)) return 'es';
  if (/[äöüß]/.test(text)) return 'de';
  if (/[àâéèêëîïôöùûüç]/.test(text)) return 'fr';
  if (/[ãõçáâéêíôó]/.test(text)) return 'pt';
  if (/[àèéìòù]/.test(text)) return 'it';
  return 'en';
}

const LANGUAGE_NAMES = {
  en: 'English', es: 'Spanish', fr: 'French', de: 'German', it: 'Italian',
  pt: 'Portuguese', 'pt-BR': 'Portuguese (Brazil)', nl: 'Dutch', ru: 'Russian',
  pl: 'Polish', uk: 'Ukrainian', tr: 'Turkish', ar: 'Arabic', he: 'Hebrew',
  fa: 'Persian', ur: 'Urdu', hi: 'Hindi', bn: 'Bengali', ta: 'Tamil',
  te: 'Telugu', ml: 'Malayalam', kn: 'Kannada', mr: 'Marathi', gu: 'Gujarati',
  pa: 'Punjabi', th: 'Thai', vi: 'Vietnamese', id: 'Indonesian', ms: 'Malay',
  zh: 'Chinese', 'zh-TW': 'Chinese (Traditional)', ja: 'Japanese', ko: 'Korean',
  sw: 'Swahili', yo: 'Yoruba', ig: 'Igbo', ha: 'Hausa', am: 'Amharic',
};

// ── GPT Streaming Translation (like AI Phone's gptTrans/stream) ─────────
async function gptStreamTranslate(text, sourceLang, targetLang, apiKey, streamCallback) {
  const model = process.env.OPENROUTER_MODEL || 'openai/gpt-4o-mini';
  const sourceName = LANGUAGE_NAMES[sourceLang] || sourceLang;
  const targetName = LANGUAGE_NAMES[targetLang] || targetLang;

  const systemPrompt = `You are a professional translator. Translate the following text from ${sourceName} to ${targetName}. 
Rules:
- Only output the translation, nothing else.
- Preserve formatting, emoji, and line breaks.
- Maintain the original tone (formal/informal).
- If the text is already in ${targetName}, return it unchanged.
- For slang or idioms, provide the most natural equivalent in ${targetName}.`;

  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
      'HTTP-Referer': 'https://kora-messenger.app',
      'X-Title': 'Kora Messenger',
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: text },
      ],
      stream: !!streamCallback,
      temperature: 0.3,
      max_tokens: 1000,
    }),
  });

  if (!response.ok) throw new Error(`GPT translation failed: ${response.status}`);

  if (!streamCallback) {
    const data = await response.json();
    const translated = data.choices?.[0]?.message?.content || text;
    return translated.trim();
  }

  // Streaming response — accumulate chunks
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let fullText = '';
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const jsonStr = line.slice(6).trim();
        if (jsonStr === '[DONE]') continue;
        try {
          const parsed = JSON.parse(jsonStr);
          const delta = parsed.choices?.[0]?.delta?.content;
          if (delta) {
            fullText += delta;
            streamCallback(delta);
          }
        } catch { /* skip malformed */ }
      }
    }
  }

  return fullText.trim() || text;
}

// ── Google Translate fallback ──────────────────────────────────────────
async function googleTranslate(text, target, source) {
  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${source}&tl=${target}&dt=t&q=${encodeURIComponent(text)}`;
    const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    if (!res.ok) return null;
    const data = await res.json();
    if (Array.isArray(data) && data[0]) {
      return data[0].map((s) => s[0]).join('');
    }
  } catch { /* ignore */ }
  return null;
}

// ── MyMemory fallback ───────────────────────────────────────────────────
async function myMemoryTranslate(text, target, source) {
  try {
    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${source}|${target}`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const data = await res.json();
    return data.responseData?.translatedText || null;
  } catch { /* ignore */ }
  return null;
}

// ── Route Handlers ─────────────────────────────────────────────────────
router.options('/', (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  return res.sendStatus(204);
});

router.post('/', async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  try {
    const body = req.body || {};
    const { text, targetLang, sourceLang, stream, transactionId } = body;

    if (!text || !targetLang) {
      return res.status(400).json({ success: false, error: 'Missing text or targetLang' });
    }

    // Auto-detect source language
    const detected = sourceLang || detectLanguage(text);
    const detectedName = LANGUAGE_NAMES[detected] || detected;
    const targetName = LANGUAGE_NAMES[targetLang] || targetLang;

    // Same language — no translation needed
    if (detected === targetLang) {
      return res.json({
        success: true,
        translatedText: text,
        detectedLanguage: detected,
        detectedLanguageName: detectedName,
        targetLanguageName: targetName,
        provider: 'none',
      });
    }

    const apiKey = (process.env.OPENROUTER_API_KEY || '').trim();

    // ── Streaming mode (for live call translation) ────────────────────
    if (stream && apiKey.length > 10) {
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*',
      });

      const sendChunk = (obj) => {
        res.write(`data: ${JSON.stringify(obj)}\n\n`);
      };

      sendChunk({
        type: 'start',
        transactionId: transactionId || Date.now().toString(),
        detectedLanguage: detected,
        detectedLanguageName: detectedName,
        targetLanguage: targetLang,
        targetLanguageName: targetName,
      });

      try {
        const translated = await gptStreamTranslate(text, detected, targetLang, apiKey, (chunk) => {
          sendChunk({ type: 'delta', text: chunk });
        });
        sendChunk({ type: 'done', translatedText: translated });
      } catch (e) {
        // Fallback to Google
        const googleResult = await googleTranslate(text, targetLang, detected);
        if (googleResult) {
          sendChunk({ type: 'delta', text: googleResult });
          sendChunk({ type: 'done', translatedText: googleResult, provider: 'google' });
        } else {
          sendChunk({ type: 'error', error: String(e) });
        }
      }

      return res.end();
    }

    // ── Batch mode (for message translation) ──────────────────────────
    // Try GPT first, then Google, then MyMemory
    let provider = 'gpt';
    let translated = null;

    if (apiKey.length > 10) {
      try {
        translated = await gptStreamTranslate(text, detected, targetLang, apiKey);
      } catch { /* fall through */ }
    }

    if (!translated) {
      provider = 'google';
      translated = await googleTranslate(text, targetLang, detected);
    }

    if (!translated) {
      provider = 'mymemory';
      translated = await myMemoryTranslate(text, targetLang, detected);
    }

    if (!translated) {
      return res.status(502).json({
        success: false,
        error: 'All translation providers failed',
      });
    }

    return res.json({
      success: true,
      translatedText: translated,
      detectedLanguage: detected,
      detectedLanguageName: detectedName,
      targetLanguageName: targetName,
      provider,
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: String(e) });
  }
});

module.exports = router;
