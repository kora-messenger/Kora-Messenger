// Kora AI Chat backend function.
// Handles two AI assistants:
//   - "support": Kora Support — answers questions about Kora Messenger
//   - "ai": Kora AI — answers any question, inside or outside Kora

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

const SUPPORT_SYSTEM_PROMPT = `You are Kora Support, the official AI support assistant for Kora Messenger — a modern messaging app with a purple-to-blue gradient visual identity.

Your role:
- Help users with anything related to Kora: account setup, profile, verification, contacts, groups, channels, privacy, security, premium features, app settings, troubleshooting.
- Be warm, friendly, and concise. Use short paragraphs. No walls of text.
- If a user asks about something outside Kora, gently redirect them to Kora AI (a separate chat in the app) for general questions.
- If a user reports a bug or issue, acknowledge it and suggest they check the Help section in Settings, or tell them the team is working on it.
- Never invent features that don't exist. Kora's features include: text/voice messaging, groups, channels, communities, wallpapers, chat themes, custom app icons (premium), custom chat bubbles (premium), animated emoji (premium), real-time translation (premium), infinite reactions (premium), faster download speeds (premium), profile badge (premium), priority support (premium), no ads (premium), passkeys, trusted devices, backup PIN, QR code contact sharing.
- Keep responses under 150 words unless the user asks for detail.
- Use emoji sparingly — one or two max per message.`;

const AI_SYSTEM_PROMPT = `You are Kora AI, a friendly, capable AI assistant built into Kora Messenger. You can answer any question — about Kora or anything else. You're knowledgeable, warm, and concise.

Guidelines:
- Be helpful and direct. Short paragraphs, no walls of text.
- If someone asks about Kora Messenger features specifically (account, settings, billing), suggest they also check with Kora Support (a separate chat in the app) for specialized help.
- Keep responses under 200 words unless the user asks for more detail.
- Use emoji sparingly.`;

Deno.serve(async (req: Request) => {
  const body = await req.json();
  const { chatType, message, history } = body;

  if (!message || message.trim() === '') {
    return jsonResponse({ success: false, error: 'Message is required' });
  }

  const systemPrompt = chatType === 'support' ? SUPPORT_SYSTEM_PROMPT : AI_SYSTEM_PROMPT;

  // Build conversation context from history (last 10 messages)
  const context = (history || [])
    .slice(-10)
    .map((m: any) => `${m.isMe ? 'User' : 'Assistant'}: ${m.text}`)
    .join('\n');

  const fullPrompt = context
    ? `${context}\nUser: ${message}\nAssistant:`
    : `User: ${message}\nAssistant:`;

  try {
    // Call OpenAI-compatible endpoint for generating responses
    const aiKey = Deno.env.get('OPENAI_API_KEY') || '';
    
    if (aiKey) {
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${aiKey}`,
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: fullPrompt },
          ],
          max_tokens: 500,
          temperature: 0.7,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const reply = data.choices?.[0]?.message?.content ||
                      "I'm here to help! Could you tell me more?";
        return jsonResponse({ success: true, reply: reply.trim() });
      }
    }

    // Fallback: canned response when no AI key is configured
    return jsonResponse({
      success: true,
      reply: chatType === 'support'
        ? "I'm here to help with any Kora-related questions! Could you tell me more about what you need? You can also check the Help section in Settings for detailed guides."
        : "I'd be happy to help with that! Let me know more about what you're looking for and I'll do my best to assist.",
      isFallback: true,
    });
  } catch (error) {
    return jsonResponse({
      success: true,
      reply: chatType === 'support'
        ? "I'm here to help with any Kora-related questions! Could you tell me more about what you need?"
        : "I'd be happy to help! Could you tell me a bit more about what you're looking for?",
      isFallback: true,
    });
  }
});
