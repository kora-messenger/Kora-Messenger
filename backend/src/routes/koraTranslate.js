const express = require('express');

const router = express.Router();

/**
 * Kora Translate — Batch text translation
 * Used by TranslationService for message-by-message translation.
 *
 * Fallback chain: Google Translate → MyMemory → OpenRouter LLM
 * Uses OPENROUTER_API_KEY from environment when available.
 */

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
  if (/[ñ¿¡]/.test(text)) return 'es';
  if (/[äöüß]/.test(text)) return 'de';
  if (/[àâéèêëîïôöùûüç]/.test(text)) return 'fr';
  if (/[ãõçáâéêíôó]/.test(text)) return 'pt';
  if (/[àèéìòù]/.test(text)) return 'it';
  return 'en';
}

// ── Google Translate (free endpoint) ─────────────────────────────────
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

// ── MyMemory fallback ────────────────────────────────────────────────
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

// ── OpenRouter LLM fallback ───────────────────────────────────────────
async function llmTranslate(text, sourceLang, targetLang, apiKey) {
  try {
    const model = process.env.OPENROUTER_MODEL || 'openai/gpt-4o-mini';
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
          {
            role: 'system',
            content: `Translate the following text to ${targetLang}. Only output the translation. Preserve formatting and emoji.`,
          },
          { role: 'user', content: text },
        ],
        temperature: 0.3,
        max_tokens: 1000,
      }),
    });
    if (!response.ok) return null;
    const data = await response.json();
    return data.choices?.[0]?.message?.content?.trim() || null;
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
    const { text, targetLang, sourceLang } = body;

    if (!text || !text.trim()) {
      return res.status(400).json({ success: false, error: 'Missing or empty "text" field.', translatedText: null });
    }
    if (!targetLang) {
      return res.status(400).json({ success: false, error: 'Missing "targetLang" field.', translatedText: null });
    }

    const detected = sourceLang || detectLanguage(text);

    // Same language — no translation needed
    if (detected === targetLang) {
      return res.json({
        success: true,
        translatedText: text,
        detectedLanguage: detected,
        provider: 'none',
      });
    }

    // Try Google Translate first (free, no API key needed)
    let provider = 'google';
    let translated = await googleTranslate(text, targetLang, detected);

    // Fallback: MyMemory
    if (!translated) {
      provider = 'mymemory';
      translated = await myMemoryTranslate(text, targetLang, detected);
    }

    // Fallback: OpenRouter LLM
    if (!translated) {
      const apiKey = (process.env.OPENROUTER_API_KEY || '').trim();
      if (apiKey.length > 10) {
        provider = 'llm';
        translated = await llmTranslate(text, detected, targetLang, apiKey);
      }
    }

    if (!translated) {
      return res.status(502).json({
        success: false,
        error: 'All translation providers failed',
        translatedText: null,
      });
    }

    return res.json({
      success: true,
      translatedText: translated,
      detectedLanguage: detected,
      provider,
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: String(e), translatedText: null });
  }
});

module.exports = router;
