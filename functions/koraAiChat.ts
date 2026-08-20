// Kora AI Chat backend function — v2.
// Handles two AI assistants:
//   - "support": Kora Support — answers questions about Kora Messenger
//   - "ai": Kora AI — answers any question, inside or outside Kora
//
// Uses Google Gemini API (free tier) with gemini-3.6-flash.
// Falls back to an intelligent knowledge-based response system on errors.

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}

// ── Comprehensive Kora knowledge base for Support AI ──────────────────

const KORA_KNOWLEDGE = `
Kora Messenger — Feature Knowledge Base

ACCOUNT & SETUP:
- Sign up: Email + password on the Create Account screen. After signup, Kora Support sends a welcome message with 7 days free Premium.
- Login: Email + password, or passkey. Verification codes are auto-verified when the last digit is entered — no submit button.
- Password reset: Tap "Forgot password?" on login screen → enter email → get verification code → set new PIN → redirect to login.
- Profile: Go to Settings > Profile to set name, bio, avatar, and username. Your Kora ID is unique and shareable.
- Logout: Settings > Account > Log out.

SECURITY:
- Passkeys: Settings > Security > Passkeys. Set up biometric login (fingerprint/face) for faster, more secure access.
- Trusted Devices: Devices must be used for 30+ days before they can be marked as trusted (bypasses verification on login).
- Backup PIN: A 6-digit PIN used to secure your account backup. Set in Settings > Security > Backup PIN.
- 2-Step Verification: Optional extra layer. Settings > Security > 2-Step Verification.
- Security Notifications: Kora Support sends alerts for suspicious activity, terms violations, or account changes.
- QR Code: Share your Kora ID via QR code. Settings > QR Code or Contacts > New Contact > Scan QR.

MESSAGING:
- Text messages: Type and send in any chat. Messages are persisted locally and synced when backend is connected.
- Voice messages: Hold the mic button to record. Release to send.
- Replies: Long-press a message → Reply. Quote preview shows above the composer.
- Reactions: Long-press a message → pick an emoji. Premium = infinite reactions.
- Translation: Long-press message → Translate. Premium feature with real-time translation.
- Attachments: Tap the attachment clip for photos, files, and more.

CHATS & GROUPS:
- New group: Home > 3-dot menu > New Group. Select contacts, name the group, set a group photo.
- New channel/community: Home > 3-dot menu > New Channel. Multi-stage flow: name, description, preview, then create.
- New contact: Contacts > New Contact. Add by phone number or scan QR code.
- Mute/Block: Chat > 3-dot menu > Mute notifications or Block.
- Clear chat: Chat > 3-dot menu > Clear chat. Removes messages but keeps the chat.
- Search: Inline search bar on Home screen. Searches messages, names, and Kora IDs.

CUSTOMIZATION:
- Chat theme: Chat > 3-dot menu > Chat theme. Pick from presets, create with AI, or customize bubble color and wallpaper.
- Wallpaper: Chat theme > Wallpaper. Choose from gallery, solid colors, or 18 bundled presets. Dimming supported.
- Chat bubble color: Chat theme > Chat bubble. 20 colors to choose from.
- App theme: Settings > Appearance > App theme color. 20 colors (Premium).
- App icon: Settings > Appearance > App Icon. Default + 2 premium icons (Premium). 3-dot menu to reset to default.

PREMIUM FEATURES:
- Custom app icons (2 premium icons)
- Premium wallpapers
- Custom chat bubble colors
- Animated emoji
- Real-time translation
- Infinite reactions
- Faster download speeds
- Profile badge (blue scalloped badge)
- Priority support
- No ads
- Free 7-day trial for new users. After expiry, Kora Support sends a message with a "Subscribe to Kora Premium" button.

BADGES:
- Purple scalloped badge: Official Kora accounts (Kora Support, Kora AI).
- Blue scalloped badge: Kora Premium subscribers.
- No badge: Regular users.

TROUBLESHOOTING:
- App won't open: Force close and reopen. Check for updates.
- Messages not sending: Check internet connection. Messages queue and send when back online.
- Can't log in: Check email/password. Use "Forgot password?" or try passkey login.
- Verification code not received: Check spam folder. Wait 60 seconds before requesting again.
- Build/crash issues: App has built-in crash reporting. Go to Settings > Help for support.

OWNER PERKS:
- Kora Messenger owner accounts get Premium free forever — no subscription needed.
- Owner emails are whitelisted in the app.

VISUAL IDENTITY:
- Purple-to-blue gradient branding.
- Deep navy / pure black dark surface.
- Scalloped verified-style badges (not circular).
`;

const SUPPORT_SYSTEM_PROMPT = `You are Kora Support, the official AI support assistant for Kora Messenger — a modern messaging app with a purple-to-blue gradient visual identity.

Your role:
- Help users with anything related to Kora: account setup, profile, verification, contacts, groups, channels, privacy, security, premium features, app settings, troubleshooting.
- Be warm, friendly, and concise. Use short paragraphs. No walls of text.
- If a user asks about something completely outside Kora, gently redirect them to Kora AI (a separate chat in the app) for general questions.
- If a user reports a bug or issue, acknowledge it and suggest they check the Help section in Settings, or tell them the team is working on it.
- Never invent features that don't exist.
- Keep responses under 150 words unless the user asks for detail.
- Use emoji sparingly — one or two max per message.

Here is your knowledge base about Kora Messenger features:
${KORA_KNOWLEDGE}`;

const AI_SYSTEM_PROMPT = `You are Kora AI, a friendly, capable AI assistant built into Kora Messenger. You can answer any question — about Kora or anything else in the world. You're knowledgeable, warm, and concise.

Guidelines:
- Be helpful and direct. Short paragraphs, no walls of text.
- You can answer questions about any topic: science, technology, history, cooking, health, entertainment, coding, math, advice, and more.
- If someone asks about Kora Messenger features specifically (account, settings, billing), suggest they also check with Kora Support (a separate chat in the app) for specialized help.
- Be conversational and natural — like chatting with a smart friend.
- If you don't know something, say so honestly rather than making things up.
- Keep responses under 200 words unless the user asks for more detail.
- Use emoji sparingly.`;

// ── Intelligent fallback knowledge base for Kora Support ──────────────
// Used when the AI API is unreachable — pattern-matches common questions.

interface FallbackEntry {
  keywords: string[];
  response: string;
}

const SUPPORT_FALLBACKS: FallbackEntry[] = [
  {
    keywords: ['premium', 'subscribe', 'subscription', 'upgrade', 'pay', 'billing'],
    response: 'Kora Premium gives you: custom app icons, premium wallpapers, custom chat bubbles, animated emoji, real-time translation, infinite reactions, faster downloads, a profile badge, priority support, and no ads.\n\nNew users get 7 days free! After that, tap "Subscribe to Kora Premium" to keep your features. You can subscribe from Settings > Premium or from the message Kora Support sent you. 💜',
  },
  {
    keywords: ['password', 'reset', 'forgot'],
    response: 'To reset your password:\n1. Tap "Forgot password?" on the login screen\n2. Enter your email address\n3. Check your email for the verification code\n4. Enter the code and set a new password\n\nYou\'ll be redirected to the login screen after resetting. If you don\'t get the code, check your spam folder. 🔐',
  },
  {
    keywords: ['passkey', 'biometric', 'fingerprint', 'face id', 'face unlock'],
    response: 'Passkeys let you log in with your fingerprint or face — faster and more secure than a password.\n\nSet up in Settings > Security > Passkeys. You can also use passkey login directly from the login screen. 🔐',
  },
  {
    keywords: ['group', 'create group', 'new group'],
    response: 'To create a group:\n1. Tap the 3-dot menu on the Home screen\n2. Select "New group"\n3. Pick contacts from your list (search by name or Kora ID)\n4. Name your group and set a group photo\n\nGroups support text, voice messages, reactions, and more. 👥',
  },
  {
    keywords: ['channel', 'community', 'create channel'],
    response: 'To create a channel/community:\n1. Tap the 3-dot menu on Home\n2. Select "New channel"\n3. Enter a community name and optional description\n4. Preview and create\n\nYour community starts with a General group. Others can add groups to it. Any community you create shows on your Home screen. 📢',
  },
  {
    keywords: ['wallpaper', 'background', 'chat background'],
    response: 'To change your chat wallpaper:\n1. Open any chat\n2. Tap the 3-dot menu > Chat theme\n3. Tap "Wallpaper" to choose from 18 presets, solid colors, or your gallery\n4. Adjust brightness with the dim slider\n\nYour wallpaper shows in all chats. 🖼️',
  },
  {
    keywords: ['theme', 'chat theme', 'bubble color', 'customize chat'],
    response: 'To customize your chat theme:\n1. Open any chat > 3-dot menu > Chat theme\n2. Pick from the preset themes grid\n3. Or tap "Chat bubble" to choose from 20 colors\n4. Tap "Wallpaper" for background options\n\nThe bubble and wallpaper both change together. ✨',
  },
  {
    keywords: ['app icon', 'icon', 'app logo'],
    response: 'To change your app icon:\n1. Go to Settings > Appearance > App Icon\n2. Choose from Default, or two premium icon designs\n3. Tap the 3-dot menu to reset to default\n\nApp icons are a Premium feature — you can preview all icons, but applying premium ones requires Kora Premium. 🎨',
  },
  {
    keywords: ['avatar', 'profile picture', 'profile photo'],
    response: 'To change your profile picture:\n1. Go to Settings > Profile\n2. Tap your avatar\n3. Choose from gallery or take a photo\n\nYour profile picture is visible to your contacts and in groups. 📸',
  },
  {
    keywords: ['qr', 'qr code', 'scan'],
    response: 'Share your Kora ID via QR code:\n1. Go to Settings > QR Code\n2. Show your code to someone, or scan theirs\n3. Or go to Contacts > New Contact > Scan QR\n\nQR sharing is a quick way to add contacts without typing. 📱',
  },
  {
    keywords: ['verify', 'verification', 'code', 'otp'],
    response: 'Verification codes are sent to your email during signup and password reset. The code auto-verifies when you enter the last digit — no submit button needed!\n\nCodes also auto-fill from your clipboard. If you don\'t receive a code within 60 seconds, check your spam folder or request a new one. ✅',
  },
  {
    keywords: ['trusted device', 'device', 'login device'],
    response: 'Trusted devices skip verification on login. A device must be used for at least 30 days before it can be marked as trusted.\n\nManage devices in Settings > Security > Trusted Devices. 🔒',
  },
  {
    keywords: ['block', 'report', 'spam', 'abuse'],
    response: 'To block or report someone:\n1. Open the chat with that person\n2. Tap the 3-dot menu\n3. Select "Block" or "Report"\n\nBlocked users can\'t message you. Reports help keep Kora safe. If someone is violating Kora\'s terms, Kora AI Support will send them a warning. 🚫',
  },
  {
    keywords: ['mute', 'notifications', 'silent'],
    response: 'To mute a chat:\n1. Open the chat\n2. Tap the 3-dot menu\n3. Select "Mute notifications"\n\nMuted chats show a muted icon. You\'ll still receive messages but won\'t get notifications. 🔕',
  },
  {
    keywords: ['delete', 'clear', 'remove message'],
    response: 'To clear or delete messages:\n- Clear chat: Chat > 3-dot menu > Clear chat (removes all messages, keeps the chat)\n- Delete single message: Long-press the message > Delete\n- Delete account: Settings > Account > Delete account (permanent) 🗑️',
  },
  {
    keywords: ['translate', 'translation', 'language'],
    response: 'Translation is a Premium feature that lets you translate messages in real-time.\n\nTo use: Long-press any message > Translate. The message is translated to your device language. 🌍',
  },
  {
    keywords: ['badge', 'verified', 'official'],
    response: 'Kora has two badge types:\n\n💜 Purple scalloped badge — Official Kora accounts (like Kora Support and Kora AI)\n💙 Blue scalloped badge — Kora Premium subscribers\n\nBadges appear next to names in chats, groups, and your profile. Badges are scalloped (not circular) — part of Kora\'s unique visual identity. ✨',
  },
  {
    keywords: ['crash', 'bug', 'error', 'not working', 'broken', 'issue', 'problem'],
    response: 'Sorry about that! 🙏 Try these steps:\n1. Force close and reopen the app\n2. Check for updates in your app store\n3. Restart your device\n4. If it persists, the Kora team is notified automatically via crash reports\n\nYou can also check Settings > Help for more troubleshooting tips.',
  },
  {
    keywords: ['logout', 'log out', 'sign out'],
    response: 'To log out: Settings > Account > Log out.\n\nYou can log back in anytime with your email and password or passkey. 👋',
  },
  {
    keywords: ['hello', 'hi', 'hey', 'help', 'start'],
    response: 'Hi there! 👋 I\'m Kora Support — I can help with anything about Kora Messenger.\n\nAsk me about: account setup, passwords, passkeys, groups, channels, wallpapers, themes, premium, security, and more!',
  },
  {
    keywords: ['free', 'trial', '7 days', 'expired'],
    response: 'Every new user gets 7 days of Kora Premium for free! 🎉\n\nAfter 7 days, your Premium features expire and Kora Support sends you a message with a "Subscribe to Kora Premium" button to re-activate.\n\nKora Messenger owner accounts get Premium free forever — no subscription needed. 💜',
  },
];

const AI_FALLBACKS: FallbackEntry[] = [
  {
    keywords: ['hello', 'hi', 'hey', 'sup', 'yo'],
    response: 'Hey! 👋 I\'m Kora AI — I can answer questions about pretty much anything. What\'s on your mind?',
  },
  {
    keywords: ['who are you', 'what are you', 'about you'],
    response: 'I\'m Kora AI — a friendly assistant built into Kora Messenger. I can help with questions about anything, inside or outside of Kora. For Kora-specific support (account, settings, billing), you can also chat with Kora Support! 🤖',
  },
  {
    keywords: ['kora', 'app', 'messenger', 'feature'],
    response: 'Kora Messenger is a modern messaging app with a purple-to-blue gradient design. It supports text/voice messaging, groups, channels, communities, chat themes, wallpapers, passkeys, and more!\n\nFor detailed questions about Kora features, try asking Kora Support — they\'re the experts on all things Kora. 💜',
  },
  {
    keywords: ['thank', 'thanks', 'appreciate'],
    response: 'Anytime! 😊 I\'m always here if you need more help.',
  },
];

function findFallback(entries: FallbackEntry[], message: string): string | null {
  const lower = message.toLowerCase();
  let bestMatch: FallbackEntry | null = null;
  let bestScore = 0;
  for (const entry of entries) {
    let score = 0;
    for (const kw of entry.keywords) {
      if (lower.includes(kw)) score += kw.length;
    }
    if (score > bestScore) {
      bestScore = score;
      bestMatch = entry;
    }
  }
  return bestScore > 0 ? bestMatch.response : null;
}

// ── Main handler ──────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ success: false, error: 'Invalid JSON body' }, 400);
  }

  const { chatType, message, history } = body;
  if (!message || message.trim() === '') {
    return jsonResponse({ success: false, error: 'Message is required' }, 400);
  }

  const isSupport = chatType === 'support';
  const systemPrompt = isSupport ? SUPPORT_SYSTEM_PROMPT : AI_SYSTEM_PROMPT;

  // Build conversation history for the LLM (last 10 messages)
  const messages = [
    { role: 'system', content: systemPrompt },
  ];

  const conversationHistory = (history || [])
    .slice(-10)
    .filter((m: any) => m.text && m.text.trim() !== '');

  for (const m of conversationHistory) {
    messages.push({
      role: m.isMe ? 'user' : 'assistant',
      content: m.text,
    });
  }

  messages.push({ role: 'user', content: message });

  // ── Try Google Gemini API (free tier) ────────────────────────
  const geminiKey = Deno.env.get('GOOGLE_API_KEY') || '';
  if (geminiKey) {
    try {
      // Convert messages to Gemini format
      const contents = messages.map((m: any) => ({
        role: m.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: m.content }],
      }));

      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${geminiKey}`;

      const response = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents,
          generationConfig: {
            temperature: 0.8,
            maxOutputTokens: 1000,
            topP: 0.9,
          },
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const reply = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (reply && reply.trim()) {
          return jsonResponse({ success: true, reply: reply.trim() });
        }
      }
    } catch (e) {
      // Fall through to knowledge-based fallback
    }
  }

  // ── Fallback: intelligent knowledge-based responses ──────────
  const fallbacks = isSupport ? SUPPORT_FALLBACKS : AI_FALLBACKS;
  const match = findFallback(fallbacks, message);

  if (match) {
    return jsonResponse({ success: true, reply: match, isFallback: true });
  }

  if (isSupport) {
    return jsonResponse({
      success: true,
      reply: "I'd love to help with that! Could you give me a bit more detail? You can ask me about:\n\n• Account & login issues\n• Passwords & passkeys\n• Groups & channels\n• Wallpapers & themes\n• Premium features\n• Security & privacy\n• Troubleshooting",
      isFallback: true,
    });
  } else {
    return jsonResponse({
      success: true,
      reply: "That's a great question! I'm having trouble connecting to my full AI right now, but I can still help with common topics.\n\nTry asking me about Kora features, general knowledge, or check back in a moment! 🤖",
      isFallback: true,
    });
  }
});