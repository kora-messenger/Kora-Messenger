// Kora AI Chat — v6
// Kora AI: Google Search grounding + professional responses (ChatGPT/Gemini-level)
// Kora Support: Complaint detection → issue list → guided troubleshooting
function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' },
  });
}

// ── Kora Support: Professional support prompt ─────────────────────────

const SUPPORT_PROMPT = `You are Kora Support, the official AI support assistant for Kora Messenger — a premium messaging app with a purple-to-blue gradient identity.

## Your Role
You are a knowledgeable, empathetic support specialist. Your goal is to resolve user issues efficiently while making them feel heard and valued.

## Response Style
- Be professional yet warm — like a skilled human support agent
- Use clear, structured responses with numbered steps for instructions
- Be concise but thorough — answer completely without unnecessary filler
- Use formatting (bullet points, bold for key terms) to make answers scannable
- Acknowledge the user's frustration before diving into solutions
- Use emoji sparingly and purposefully (max 1-2 per message)
- Never say "I understand your frustration" — instead, show it through your response

## Knowledge Base
- Sign up = email + password. Login = email or passkey.
- Verification codes auto-verify on the last digit. Auto-fill from clipboard.
- Passkeys: Settings > Security > Passkeys. Biometric login.
- Trusted devices: Must be 30+ days old. Settings > Security > Trusted Devices.
- Groups: Home > 3-dot menu > New Group. Select contacts, name, photo.
- Communities: Home > 3-dot menu > New Channel. Name, description, preview, create.
- Wallpapers: 18 presets + colors + gallery. Dimming supported.
- Chat bubbles: 20 color options. Chat theme screen.
- App theme & custom icons: Premium feature.
- Premium includes: custom icons, premium wallpapers, custom chat bubbles, animated emoji, real-time translation, infinite reactions, faster downloads, profile badge, priority support, no ads. 7-day free trial. Owner = free Premium.
- Badges: purple scalloped = Official Kora, blue scalloped = Premium subscriber.

## When to Escalate
If an issue requires account-level changes you cannot perform (data loss, payment disputes, persistent bugs), suggest "Contact Live Support" with the action label.

## Issue Selection Mode
When a user describes a problem, you'll receive their selected issue prefixed with "[ISSUE]". Provide clear, step-by-step guidance. If the issue can't be self-resolved, include the action label "Contact Live Support".

## Boundaries
- Never invent features that don't exist in Kora
- For non-Kora questions, suggest Kora AI
- Don't ask users to do anything that could compromise their security`;

// ── Kora AI: Professional assistant prompt with deep search ──────────

const AI_PROMPT = `You are Kora AI, an intelligent assistant integrated into Kora Messenger. You have Google Search capability and can retrieve real-time information from the web.

## Your Role
You are a knowledgeable, professional AI assistant — comparable to ChatGPT or Gemini. Your goal is to provide accurate, well-structured, and genuinely helpful answers to any question.

## Response Style
- Be professional and articulate — write with clarity and precision
- Structure complex answers with headings, bullet points, or numbered lists
- Be comprehensive but concise — cover the key points without padding
- Use formatting (bold for emphasis, bullet points for lists) to improve readability
- Match the user's tone — casual questions get casual answers, technical questions get detailed answers
- When discussing facts you searched for, naturally weave in "Based on the latest information..." or "According to current sources..."
- Use emoji very sparingly (0-1 per message, only when it adds genuine warmth)
- For code or technical content, use proper formatting
- If you're unsure, say so honestly rather than guessing

## Knowledge & Search
- You have Google Search grounding enabled — use it to give accurate, up-to-date answers
- For current events, prices, news, or factual questions, rely on search results
- For general knowledge, reasoning, or creative tasks, use your own capabilities
- When you search the web, mention it naturally (e.g., "I searched for the latest info and...")

## For Kora App Questions
If users ask about Kora Messenger features, suggest they chat with Kora Support for app-specific help.

## Boundaries
- Be honest about limitations
- Don't fabricate sources or facts
- Keep responses under 200 words unless the question genuinely requires more detail`;

// ── Common issues for Kora Support complaint detection ────────────────

interface SupportIssue {
  id: string;
  label: string;
  keywords: string[];
  guidance: string;
  needsLiveSupport: boolean;
}

const SUPPORT_ISSUES: SupportIssue[] = [
  {
    id: 'login',
    label: "Can't log in / Forgot password",
    keywords: ['login', 'log in', 'sign in', "can't access", 'locked out', 'forgot password', 'reset password'],
    guidance: "Here's how to reset your password:\n\n1. On the login screen, tap **\"Forgot password?\"**\n2. Enter your registered email address\n3. Check your email for a verification code\n4. Enter the code — it auto-verifies on the last digit\n5. Set your new password\n6. You'll be redirected to the login screen\n\n**If you're not receiving the email:**\n• Check your spam/junk folder\n• Make sure you used the correct email address\n• Wait up to 2 minutes for delivery\n\n🔐 Need more help? Contact Live Support.",
    needsLiveSupport: false,
  },
  {
    id: 'verification',
    label: 'Not receiving verification codes',
    keywords: ['verification', 'code', 'otp', 'not receiving', 'no code', "didn't get", 'email code'],
    guidance: "If you're not receiving verification codes:\n\n1. **Check your spam/junk folder** — emails sometimes land there\n2. **Verify your email address** — make sure it's correct\n3. **Wait up to 2 minutes** — codes can take a moment to arrive\n4. **Clipboard auto-fill** — if you copy the code from your email, it auto-fills in the app\n5. **Auto-verification** — the code verifies automatically when you enter the last digit\n\nIf you still don't get a code after 5 minutes, there may be an email delivery issue. ✅\n\nContact Live Support if the problem persists.",
    needsLiveSupport: true,
  },
  {
    id: 'passkey',
    label: 'Passkey / biometric login not working',
    keywords: ['passkey', 'biometric', 'fingerprint', 'face id', 'face unlock', 'touch id'],
    guidance: "If your passkey isn't working:\n\n1. Go to **Settings > Security > Passkeys**\n2. Check if your device is listed\n3. If not, tap **\"Add Passkey\"** and follow the prompts\n4. Make sure your device supports biometric authentication\n5. Try **removing and re-adding** the passkey\n\n**Note:** Trusted devices must be active for 30+ days before they can skip verification.\n\n🔐 This ensures your account stays secure.",
    needsLiveSupport: false,
  },
  {
    id: 'messages',
    label: 'Messages not sending',
    keywords: ['message not sending', "can't send", 'stuck', 'not delivered', 'sending failed'],
    guidance: "If your messages aren't sending:\n\n1. **Check your internet connection** — messages need a network to send\n2. **Read the status icons:**\n   • ⏳ = Sending\n   • ✓ = Sent\n   • ✓✓ = Delivered\n   • ✓✓ (blue) = Read\n3. If you see a ⬇️ arrow, there's no network — the message will auto-send when you reconnect\n4. Try **force-closing and reopening** the app\n5. Check if you're in an active conversation\n\nMessages sent without network will automatically deliver once you reconnect. 📡",
    needsLiveSupport: false,
  },
  {
    id: 'crash',
    label: 'App crashing or freezing',
    keywords: ['crash', 'freeze', 'frozen', 'not responding', 'force close', 'bug', 'error', 'broken'],
    guidance: "If the app is crashing or freezing:\n\n1. **Force close** the app and reopen it\n2. **Check for updates** in your app store\n3. **Restart your device**\n4. **Clear the app cache** (Android: Settings > Apps > Kora > Clear Cache)\n5. If it keeps happening, note what you were doing when it crashed\n\nCrash reports are sent automatically to help our team fix issues. 🙏\n\nIf the problem persists, Contact Live Support with details about what you were doing when the crash occurred.",
    needsLiveSupport: true,
  },
  {
    id: 'group',
    label: "Can't create group or community",
    keywords: ['group', 'community', 'channel', 'create group', 'new group', "can't create"],
    guidance: "To create a group or community:\n\n**For a Group:**\n1. Open the **Home screen**\n2. Tap the **3-dot menu** (top right)\n3. Tap **\"New Group\"**\n4. Select contacts from your list\n5. Name your group and set a photo\n\n**For a Community:**\n1. Tap the **3-dot menu** > **\"New Channel\"**\n2. Name your community and add a description\n3. Preview the community\n4. Create — it starts with a **General** group\n5. You can add more groups later\n\nIf the button isn't responding, try restarting the app. 👥",
    needsLiveSupport: false,
  },
  {
    id: 'premium',
    label: 'Premium subscription issues',
    keywords: ['premium', 'subscribe', 'subscription', 'upgrade', 'pay', 'billing', 'trial', 'expired'],
    guidance: "For Premium subscription issues:\n\n**What you get with Premium:**\n• Custom app icons & premium wallpapers\n• Custom chat bubbles & animated emoji\n• Real-time translation\n• Infinite reactions & faster downloads\n• Profile badge & priority support\n• No ads\n\n**Pricing:**\n• New users get **7 days free**\n• After the trial, subscribe via Settings > Premium\n• Owner accounts get Premium for free\n\nIf your trial ended early or a payment failed, Contact Live Support. 💜",
    needsLiveSupport: true,
  },
  {
    id: 'security',
    label: 'Account security concerns',
    keywords: ['security', 'hacked', 'compromised', 'unauthorized', 'someone else', 'suspicious'],
    guidance: "For account security:\n\n1. **Change your password immediately** — Settings > Account > Change Password\n2. **Enable passkeys** for biometric security — Settings > Security > Passkeys\n3. **Check trusted devices** — Settings > Security > Trusted Devices\n4. **Remove any unrecognized devices** from the list\n5. **Enable your secure PIN** if you haven't already\n\nIf you believe your account is compromised, **Contact Live Support immediately** for emergency assistance. 🔒",
    needsLiveSupport: true,
  },
  {
    id: 'profile',
    label: "Can't change profile picture or name",
    keywords: ['profile', 'picture', 'avatar', 'name', 'change name', 'photo', 'profile picture'],
    guidance: "To change your profile:\n\n1. Go to **Settings > Profile**\n2. **Tap your avatar** to change your photo (gallery or camera)\n3. **Tap your name** to edit it\n4. Add a **bio** to tell people about yourself\n5. Set up your **Kora ID** and **username**\n\nIf the photo won't upload:\n• Check your internet connection\n• Try a smaller image (under 5MB)\n• Make sure the image is in JPG or PNG format\n\n📸 Your profile is how people recognize you on Kora!",
    needsLiveSupport: false,
  },
  {
    id: 'notifications',
    label: 'Notifications not working',
    keywords: ['notification', 'notifications', 'not getting', 'alert', 'no sound', 'mute'],
    guidance: "If notifications aren't working:\n\n1. **Check if the chat is muted** — Chat > 3-dot menu > Mute notifications\n2. **Clear badges** — Home screen > 3-dot menu > \"Read all\"\n3. **Check device settings** — make sure Kora is allowed to send notifications\n4. **Disable Do Not Disturb** on your device\n5. **Restart the app** if notifications still don't appear\n\nIf only one chat is affected, it's likely muted. 🔕\n\nContact Live Support if notifications never appear across all chats.",
    needsLiveSupport: false,
  },
];

// ── Fallback knowledge base ───────────────────────────────────────────

interface FallbackEntry { keywords: string[]; response: string; }

const SUPPORT_FALLBACKS: FallbackEntry[] = [
  { keywords: ['premium','subscribe','subscription','upgrade','pay','billing'], response: '**Kora Premium** includes:\n\n• Custom app icons\n• Premium wallpapers\n• Custom chat bubbles\n• Animated emoji\n• Real-time translation\n• Infinite reactions\n• Faster downloads\n• Profile badge\n• Priority support\n• No ads\n\n**7 days free** for new users! Owner accounts get Premium for free. 💜' },
  { keywords: ['password','reset','forgot'], response: '**Reset your password:**\n\n1. Tap "Forgot password?" on the login screen\n2. Enter your registered email\n3. Check your email for a verification code\n4. Enter the code (auto-verifies on the last digit)\n5. Set your new password\n6. You'll be redirected to the login screen 🔐' },
  { keywords: ['passkey','biometric','fingerprint','face id'], response: '**Passkeys** let you log in with fingerprint or face recognition.\n\nSet up: **Settings > Security > Passkeys** 🔐' },
  { keywords: ['group','new group'], response: '**Create a group:**\n\nHome > 3-dot menu > New Group\n\nSelect contacts, name your group, set a photo. 👥' },
  { keywords: ['channel','community'], response: '**Create a community:**\n\nHome > 3-dot menu > New Channel\n\nName it, add a description, preview, then create. Starts with a General group. 📢' },
  { keywords: ['wallpaper','background'], response: '**Wallpaper:** Chat > 3-dot menu > Chat theme > Wallpaper\n\n18 presets, colors, and gallery options. Dimming supported. 🖼️' },
  { keywords: ['theme','bubble color'], response: '**Chat theme:** Chat > 3-dot menu > Chat theme\n\nPresets or custom bubble color (20 options). ✨' },
  { keywords: ['app icon'], response: '**App icon:** Settings > Appearance > App Icon\n\nDefault + 2 premium icons. 3-dot menu to reset. Premium icons require Kora Premium. 🎨' },
  { keywords: ['avatar','profile picture'], response: '**Change avatar:** Settings > Profile > tap avatar\n\nChoose from gallery or camera. 📸' },
  { keywords: ['qr','scan'], response: '**QR code:** Settings > QR Code, or Contacts > New Contact > Scan QR. 📱' },
  { keywords: ['verify','verification','code','otp'], response: '**Verification codes:**\n\n• Sent to your email\n• Auto-verify on the last digit — no submit button\n• Auto-fill from clipboard ✅' },
  { keywords: ['trusted device','device'], response: '**Trusted devices** skip verification on login.\n\nMust be 30+ days old. Settings > Security > Trusted Devices. 🔒' },
  { keywords: ['block','report'], response: '**Block/Report:** Chat > 3-dot menu > Block or Report. 🚫' },
  { keywords: ['mute','notifications'], response: '**Mute:** Chat > 3-dot menu > Mute notifications. 🔕' },
  { keywords: ['delete','clear'], response: '**Clear chat:** Chat > 3-dot > Clear chat\n**Delete message:** Long-press > Delete. 🗑️' },
  { keywords: ['translate','translation'], response: '**Translation** is a Premium feature. Long-press message > Translate. 🌍' },
  { keywords: ['badge','verified'], response: '💜 Purple scalloped = Official Kora account\n💙 Blue scalloped = Premium subscriber ✨' },
  { keywords: ['crash','bug','error','broken','problem'], response: "Try these steps:\n\n1. Force close the app\n2. Check for updates\n3. Restart your device\n\nCrash reports are sent automatically. 🙏" },
  { keywords: ['logout','sign out'], response: '**Log out:** Settings > Account > Log out. 👋' },
  { keywords: ['hello','hi','hey','help'], response: "Hi! I'm Kora Support. I can help with:\n\n• Account & login\n• Passwords & passkeys\n• Groups & communities\n• Wallpapers & themes\n• Premium & billing\n• Security\n\nWhat do you need help with?" },
  { keywords: ['free','trial','expired'], response: '**7 days free Premium** for new users! 🎉\n\nAfter the trial, tap "Subscribe to Kora Premium". Owner accounts = free forever. 💜' },
  { keywords: ['ai','kora ai','smart'], response: "**Kora AI** is a free assistant in Kora Messenger — ask it anything! It can even search the web for real-time answers. 🤖\n\nI (Kora Support) handle Kora-specific questions." },
];

const AI_FALLBACKS: FallbackEntry[] = [
  { keywords: ['hello','hi','hey'], response: "Hey! I'm Kora AI — ask me anything. I can search the web for the latest information too. 🔍" },
  { keywords: ['who are you','what are you'], response: "I'm Kora AI — an intelligent assistant built into Kora Messenger. I can answer questions, search the web for real-time info, and help with anything you need. 🤖" },
  { keywords: ['kora','messenger'], response: "Kora Messenger is a modern messaging app with a purple-to-blue gradient design. For app-specific questions, try chatting with Kora Support! 💜" },
  { keywords: ['thank'], response: 'Anytime! 😊' },
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

// ── Complaint detection for Kora Support ──────────────────────────────

const COMPLAINT_KEYWORDS = [
  'not working', "doesn't work", "can't", 'cant', 'unable', 'broken', 'crash',
  'frozen', 'freeze', 'stuck', 'error', 'problem', 'issue', 'help', 'wrong',
  'bug', 'glitch', 'failed', "won't", 'wont', "doesn't", 'doesnt',
  'trouble', 'difficult', 'frustrating', 'annoying', 'complaint', 'complain',
  'not receiving', 'not getting', 'missing', 'lost', 'hacked', 'compromised',
  "can't log in", "can't send", 'not sending', 'not showing',
];

function isComplaint(message: string): boolean {
  const lower = message.toLowerCase().trim();
  if (lower.split(/\s+/).length < 3) return false;
  for (const kw of COMPLAINT_KEYWORDS) {
    if (lower.includes(kw)) return true;
  }
  if (lower.endsWith('?')) {
    const problemWords = ['how', 'why', 'where', 'fix', 'reset', 'recover', 'restore'];
    for (const pw of problemWords) {
      if (lower.includes(pw) && lower.length > 10) return true;
    }
  }
  return false;
}

function findMatchingIssues(message: string): { label: string; id: string }[] {
  const lower = message.toLowerCase();
  const scored = SUPPORT_ISSUES
    .map(issue => {
      let score = 0;
      for (const kw of issue.keywords) {
        if (lower.includes(kw)) score += kw.length;
      }
      return { issue, score };
    })
    .filter(s => s.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, 5);
  return scored.map(s => ({ label: s.issue.label, id: s.issue.id }));
}

// ── Gemini API calls ─────────────────────────────────────────────────

async function callGemini(model: string, apiKey: string, systemPrompt: string, message: string, history: any[], useSearch: boolean = false) {
  const contents: any[] = [];
  for (const m of history.slice(-6).filter((m: any) => m.text && m.text.trim() !== '')) {
    contents.push({ role: m.isMe ? 'user' : 'model', parts: [{ text: m.text }] });
  }
  contents.push({ role: 'user', parts: [{ text: message }] });

  const body: any = {
    systemInstruction: { parts: [{ text: systemPrompt }] },
    contents,
    generationConfig: { temperature: 0.8, maxOutputTokens: 800, topP: 0.9, topK: 40 },
  };

  if (useSearch) {
    body.tools = [{ google_search: {} }];
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!response.ok) return null;
  const data = await response.json();

  const text = data.candidates?.[0]?.content?.parts?.[0]?.text || null;
  if (!text) return null;

  const groundingMetadata = data.candidates?.[0]?.groundingMetadata;
  const searchSources: string[] = [];
  if (groundingMetadata?.groundingChunks) {
    for (const chunk of groundingMetadata.groundingChunks) {
      if (chunk.web?.uri) {
        searchSources.push(chunk.web.uri);
      }
    }
  }

  return { text: text.trim(), searchSources };
}

// ── Main handler ─────────────────────────────────────────────────────

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
  const apiKey = Deno.env.get('GOOGLE_API_KEY') || '';

  // ── Kora Support: Complaint detection → issue list ──────────────────
  if (isSupport) {
    // If the message is an [ISSUE] selection, provide guided troubleshooting
    if (message.startsWith('[ISSUE]')) {
      const issueId = message.replace('[ISSUE]', '').trim();
      const issue = SUPPORT_ISSUES.find(i => i.id === issueId);
      if (issue) {
        const response: any = {
          success: true,
          reply: issue.guidance,
          isGuided: true,
        };
        if (issue.needsLiveSupport) {
          response.actionLabel = 'Contact Live Support';
          response.actionType = 'contact_support';
        }
        return jsonResponse(response);
      }
    }

    // Detect if this is a complaint and show issue list
    if (isComplaint(message)) {
      const matchingIssues = findMatchingIssues(message);
      if (matchingIssues.length > 0) {
        let introText = "I can see you're having an issue. I've pulled up some common problems — does any of these match what you're experiencing?";
        if (apiKey) {
          try {
            const aiIntro = await callGemini('gemini-flash-lite-latest', apiKey, SUPPORT_PROMPT, `A user said: "${message}". Acknowledge the user issue in ONE short sentence (under 15 words). Do NOT give any solutions or steps. End by saying you will show some common solutions. Be warm and professional.`, [], false);
            if (aiIntro?.text) introText = aiIntro.text;
          } catch {}
        }
        return jsonResponse({
          success: true,
          reply: introText,
          issueList: matchingIssues,
        });
      }
    }
  }

  // ── Kora AI: Deep search with Google Search grounding ──────────────
  if (!isSupport && apiKey) {
    try {
      const result = await callGemini('gemini-2.0-flash', apiKey, AI_PROMPT, message, hist, true);
      if (result?.text) {
        return jsonResponse({
          success: true,
          reply: result.text,
          isWebSearch: true,
          searchSources: result.searchSources || [],
        });
      }
    } catch {}
    try {
      const result = await callGemini('gemini-flash-lite-latest', apiKey, AI_PROMPT, message, hist, false);
      if (result?.text) return jsonResponse({ success: true, reply: result.text });
    } catch {}
    try {
      const result = await callGemini('gemini-3.6-flash', apiKey, AI_PROMPT, message, hist, false);
      if (result?.text) return jsonResponse({ success: true, reply: result.text });
    } catch {}
  }

  // ── Kora Support: Regular AI response ───────────────────────────────
  if (isSupport && apiKey) {
    try {
      const result = await callGemini('gemini-flash-lite-latest', apiKey, SUPPORT_PROMPT, message, hist, false);
      if (result?.text) return jsonResponse({ success: true, reply: result.text });
    } catch {}
    try {
      const result = await callGemini('gemini-3.6-flash', apiKey, SUPPORT_PROMPT, message, hist, false);
      if (result?.text) return jsonResponse({ success: true, reply: result.text });
    } catch {}
  }

  // ── Knowledge-based fallback ────────────────────────────────────────
  const fallbacks = isSupport ? SUPPORT_FALLBACKS : AI_FALLBACKS;
  const match = findFallback(fallbacks, message);
  if (match) return jsonResponse({ success: true, reply: match, isFallback: true });
  if (isSupport) {
    return jsonResponse({ success: true, reply: "I'd love to help! Tell me what's going on and I'll show you some common solutions. You can also ask about: account, passwords, passkeys, groups, wallpapers, themes, premium, or security.", isFallback: true });
  }
  return jsonResponse({ success: true, reply: "I'm having trouble connecting right now. Please try again in a moment! 🤖", isFallback: true });
});
