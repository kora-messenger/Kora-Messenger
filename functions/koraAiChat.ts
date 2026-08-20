// Kora AI Chat — v5 (OpenAI gpt-5.4-mini, free for all users)
function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' },
  });
}

const SUPPORT_PROMPT = `You are Kora Support — the official AI support assistant for Kora Messenger, a modern messaging app with a purple-to-blue gradient design and deep navy/black dark theme.

Your role: Help users with any question about Kora Messenger — accounts, login, passkeys, security, groups, communities, channels, wallpapers, chat themes, app icons, premium, troubleshooting, and more.

Tone: Be professional, clear, and genuinely helpful — like a knowledgeable support agent. Be concise but thorough. Use formatting (bullet points, numbered steps) when it helps clarity. Use emoji sparingly and only when it adds warmth. Never invent features that don't exist in Kora. If a question is completely unrelated to Kora, politely redirect the user to Kora AI for general questions.

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
- **Kora Premium features**: Custom app icons, premium wallpapers, custom chat bubble colors (20 options), animated emoji, real-time message translation, infinite reactions, faster download speeds, profile badge (blue scalloped), priority support, no ads.
- **Free trial**: 7 days free for new users.
- **Owner account**: The Kora Messenger owner gets Premium free forever without payment — a built-in override.
- **Pricing**: Manage subscription in Settings > Premium. Cancel anytime.

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
- **Contact support**: Email support@koramessenger.com for issues that can't be resolved here.`;

const AI_PROMPT = `You are Kora AI — an intelligent assistant built into Kora Messenger, a modern messaging app with a purple-to-blue gradient design.

Your role: You are a general-purpose AI assistant. You can answer questions about any topic — science, technology, writing, coding, math, creative writing, general knowledge, advice, and more. Think of yourself as comparable to ChatGPT or Gemini — professional, knowledgeable, and genuinely helpful.

Tone: Be professional, articulate, and thoughtful. Structure your responses clearly with formatting when appropriate (headings, bullet points, numbered lists, code blocks for code). Be concise but never at the expense of being helpful — give complete answers. Use emoji sparingly. If a user asks about Kora Messenger features specifically (account, settings, passkeys, groups, etc.), suggest they check with Kora Support for the most accurate and up-to-date guidance.

You are free for all Kora Messenger users — no Premium required. Be the best assistant you can be.`;

interface FallbackEntry { keywords: string[]; response: string; }

const SUPPORT_FALLBACKS: FallbackEntry[] = [
  { keywords: ['premium','subscribe','subscription','upgrade','pay','billing'], response: '**Kora Premium** includes:\n• Custom app icons\n• Premium wallpapers\n• Custom chat bubble colors\n• Animated emoji\n• Real-time message translation\n• Infinite reactions\n• Faster download speeds\n• Profile badge (blue)\n• Priority support\n• No ads\n\nNew users get **7 days free**! After that, subscribe via Settings > Premium. Cancel anytime. 💜' },
  { keywords: ['password','reset','forgot'], response: '**Reset your password:**\n1. Tap "Forgot password?" on the login screen\n2. Enter your email address\n3. Check your email for a verification code\n4. Enter the code (auto-verifies on the last digit)\n5. Set your new password → you\'ll be redirected to login\n\nIf you don\'t receive the code, check your spam folder. 🔐' },
  { keywords: ['passkey','biometric','fingerprint','face id'], response: '**Passkeys** let you log in with your fingerprint or Face ID instead of a password.\n\n**Set up:** Settings > Security > Passkeys\n\nPasskeys are tied to specific devices, so you\'ll need to set them up on each device you want to use. 🔐' },
  { keywords: ['group','new group'], response: '**Create a group:**\n1. Home screen > 3-dot menu (top right) > New Group\n2. Select contacts from your list\n3. Search by Name, Kora ID, or @Username\n4. Name the group and optionally set a group photo\n\nGroups support text, voice messages, images, and file sharing. 👥' },
  { keywords: ['channel','community'], response: '**Create a community:**\n1. Home screen > 3-dot menu > New Channel\n2. Set a profile image (optional)\n3. Enter the community name\n4. Add a description (optional)\n5. Tap continue to preview\n6. Confirm to create\n\nCommunities start with a default General group. Other users can add their own groups. Any community you create appears on your home screen. 📢' },
  { keywords: ['wallpaper','background'], response: '**Chat wallpapers:**\nChat > 3-dot menu > Chat theme > Wallpaper\n\nOptions:\n• 18 preset wallpapers\n• Solid colors\n• Gallery photos\n• Dimming slider (persists to the active chat)\n\nCustom wallpapers are a Premium feature. 🖼️' },
  { keywords: ['theme','bubble color'], response: '**Chat themes:**\nChat > 3-dot menu > Chat theme\n\nOptions:\n• Preset themes\n• Custom bubble color (20 options)\n\nCustom bubble colors are a Premium feature. ✨' },
  { keywords: ['app icon'], response: '**App icons:**\nSettings > Appearance > App Icon\n\n• Default circular icon (free)\n• 2 premium icons (Premium only)\n• 3-dot menu to reset to default\n\nAll users can view icons, but only Premium subscribers can apply premium ones. 🎨' },
  { keywords: ['avatar','profile picture'], response: '**Change your avatar:**\nSettings > Profile > tap your avatar\n\nChoose from your gallery or take a new photo with your camera. 📸' },
  { keywords: ['qr','scan'], response: '**QR codes:**\n• Generate yours: Settings > QR Code\n• Scan others: Contacts > New Contact > Scan QR\n\nShare your QR code so others can add you instantly. 📱' },
  { keywords: ['verify','verification','code','otp'], response: '**Verification codes:**\n• Sent to your registered email\n• Auto-verify on the last digit — no submit button\n• Auto-fill from clipboard if a code is detected\n\nIf you don\'t receive a code, check your spam folder and wait about 60 seconds. ✅' },
  { keywords: ['trusted device','device'], response: '**Trusted devices** skip email verification on login.\n\n• A device must be used for **30+ days** before it can be trusted\n• Manage in Settings > Security > Trusted Devices\n• You can revoke trusted status anytime\n\nThis keeps your account secure while reducing friction on devices you use regularly. 🔒' },
  { keywords: ['block','report'], response: '**Block or report a user:**\nChat > 3-dot menu > Block or Report\n\n• Blocking prevents the user from sending you further messages\n• You can also report inappropriate behavior\n• "Learn more" links to our blocking & reporting policy\n\nTo unblock: open the chat > 3-dot menu > Unblock. 🚫' },
  { keywords: ['mute','notifications'], response: '**Mute notifications:**\nChat > 3-dot menu > Mute notifications\n\nMuted chats won\'t send push notifications, but you\'ll still see new messages when you open the app. 🔕' },
  { keywords: ['delete','clear'], response: '**Clear or delete:**\n• Clear chat: Chat > 3-dot menu > Clear chat (removes all messages, optionally including starred)\n• Delete message: Long-press a message > Delete\n\nClearing removes messages from your device only. 🗑️' },
  { keywords: ['translate','translation'], response: '**Message translation** is a Premium feature.\n\nLong-press any message > Translate to see it in your language. Real-time translation supports multiple languages. 🌍' },
  { keywords: ['badge','verified'], response: '**Kora badges:**\n• 💜 Purple scalloped = Official Kora account (e.g., Kora AI, Kora Support)\n• 💙 Blue scalloped = Premium subscriber\n\nBadges appear next to the user\'s name in chats and profiles. ✨' },
  { keywords: ['crash','bug','error','broken','problem'], response: '**Troubleshooting:**\n1. Force close the app and reopen it\n2. Check for updates in your app store\n3. Restart your device\n4. If the issue persists, email support@koramessenger.com\n\nCrash reports are sent automatically to our development team. 🙏' },
  { keywords: ['logout','sign out'], response: '**Log out:**\nSettings > Account > Log out\n\nYou\'ll need to sign back in to access your chats. 👋' },
  { keywords: ['hello','hi','hey','help'], response: 'Hi! 👋 I\'m Kora Support. I can help with:\n• Account & login issues\n• Passkeys & security\n• Groups & communities\n• Wallpapers & themes\n• Premium features\n• Troubleshooting\n\nWhat can I help you with?' },
  { keywords: ['free','trial','expired'], response: '**Premium free trial:**\n• 7 days free for new users\n• After the trial, subscribe via Settings > Premium\n• Cancel anytime\n• Owner accounts get Premium free forever 💜' },
  { keywords: ['ai','kora ai','smart'], response: '**Kora AI** is a free general-purpose assistant in Kora Messenger — ask it anything! 🤖\n\nI (Kora Support) handle Kora-specific questions. Kora AI handles general knowledge, writing, coding, and more.\n\nBoth are free for all users.' },
];

const AI_FALLBACKS: FallbackEntry[] = [
  { keywords: ['hello','hi','hey'], response: 'Hello! 👋 I\'m Kora AI. I can help with general questions, writing, coding, analysis, and more. What\'s on your mind?' },
  { keywords: ['who are you','what are you'], response: 'I\'m Kora AI — an intelligent assistant built into Kora Messenger. I can help with general knowledge, writing, coding, math, and much more. Think of me like ChatGPT or Gemini, built right into your messaging app. 🤖' },
  { keywords: ['kora','messenger'], response: 'Kora Messenger is a modern messaging app with a purple-to-blue gradient design. For questions about Kora features (account, settings, groups, etc.), try Kora Support — they\'re the experts on the app! 💜' },
  { keywords: ['thank'], response: 'You\'re welcome! 😊 Feel free to ask me anything else.' },
];

function findFallback(entries: FallbackEntry[], message: string): string | null {
  const lower = message.toLowerCase();
  let bestMatch: FallbackEntry | null = null;
  let bestScore = 0;
  for (const entry of entries) {
    let score = 0;
    for (const kw of entry.keywords) if (lower.includes(kw)) score += kw.length;
    if (score > bestScore) { bestScore = score; bestMatch = entry; }
  }
  return bestScore > 0 ? bestMatch.response : null;
}

/// Clean the API key in case it was stored with a wrapper like api_key="sk-..."
function cleanApiKey(raw: string): string {
  let key = raw.trim();
  if (key.startsWith('api_key=')) {
    key = key.slice('api_key='.length).trim();
    if ((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'") && key.endsWith("'"))) {
      key = key.slice(1, -1);
    }
  }
  return key.trim();
}

/// Calls OpenAI Responses API (gpt-5.4-mini)
async function callOpenAI(systemPrompt: string, message: string, history: any[]): Promise<string | null> {
  const apiKey = cleanApiKey(Deno.env.get('OPENAI_API_KEY') || '');
  if (!apiKey || apiKey.length < 10) return null;

  // Build conversation input from recent history (last 10 messages)
  const input: any[] = [];
  for (const m of (history || []).slice(-10).filter((m: any) => m.text && m.text.trim() !== '')) {
    input.push({
      role: m.isMe ? 'user' : 'assistant',
      content: [{ type: 'input_text', text: m.text }],
    });
  }
  input.push({
    role: 'user',
    content: [{ type: 'input_text', text: message }],
  });

  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: 'gpt-5.4-mini',
      instructions: systemPrompt,
      input,
      store: true,
    }),
  });

  if (!response.ok) {
    const errBody = await response.text().catch(() => '');
    console.error(`OpenAI API error: ${response.status} ${response.statusText} — ${errBody.slice(0, 200)}`);
    return null;
  }

  const data = await response.json();
  // The Responses API returns output_text directly
  const text = data.output_text;
  if (text && typeof text === 'string' && text.trim()) return text.trim();

  // Fallback: extract from output array
  if (data.output && Array.isArray(data.output)) {
    for (const item of data.output) {
      if (item.type === 'message' && item.content && Array.isArray(item.content)) {
        for (const c of item.content) {
          if (c.type === 'output_text' && c.text) return c.text.trim();
        }
      }
    }
  }

  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' } });
  }
  let body: any;
  try { body = await req.json(); }
  catch { return jsonResponse({ success: false, error: 'Invalid JSON body' }, 400); }
  const { chatType, message, history } = body;
  if (!message || message.trim() === '') return jsonResponse({ success: false, error: 'Message is required' }, 400);
  const isSupport = chatType === 'support';
  const systemPrompt = isSupport ? SUPPORT_PROMPT : AI_PROMPT;
  const hist = history || [];

  // OpenAI gpt-5.4-mini for all users (free)
  try {
    const reply = await callOpenAI(systemPrompt, message, hist);
    if (reply && reply.trim()) return jsonResponse({ success: true, reply: reply.trim() });
  } catch (e) {
    console.error('OpenAI call failed:', e);
  }

  // Knowledge-based fallback (only if OpenAI fails)
  const fallbacks = isSupport ? SUPPORT_FALLBACKS : AI_FALLBACKS;
  const match = findFallback(fallbacks, message);
  if (match) return jsonResponse({ success: true, reply: match, isFallback: true });
  if (isSupport) {
    return jsonResponse({ success: true, reply: "I'd love to help! You can ask me about: account & login, passkeys & security, groups & communities, wallpapers & themes, premium features, troubleshooting, and more.", isFallback: true });
  }
  return jsonResponse({ success: true, reply: "I'm having trouble connecting right now. Please try again in a moment! 🤖", isFallback: true });
});
