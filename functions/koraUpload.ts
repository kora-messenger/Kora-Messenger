import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const body = await req.json();
  const { action } = body;

  try {
    // ── UPLOAD AVATAR ─────────────────────────────────
    // Since the Base44 backend SDK doesn't expose a file upload API,
    // we store the avatar as a base64 data URL and return it.
    // The client then saves this data URL to the user's avatarUrl field.
    if (action === 'uploadAvatar') {
      const { imageBase64, fileName, fileType } = body;
      if (!imageBase64) return jsonResponse({ success: false, error: 'No image data provided' });

      const mimeType = fileType || 'image/jpeg';
      const dataUrl = `data:${mimeType};base64,${imageBase64}`;

      return jsonResponse({
        success: true,
        url: dataUrl,
      });
    }

    // ── UPLOAD MEDIA (for chat attachments) ───────────
    if (action === 'uploadMedia') {
      const { imageBase64, fileName, fileType } = body;
      if (!imageBase64) return jsonResponse({ success: false, error: 'No media data provided' });

      const mimeType = fileType || 'application/octet-stream';
      const dataUrl = `data:${mimeType};base64,${imageBase64}`;

      return jsonResponse({
        success: true,
        url: dataUrl,
      });
    }

    return jsonResponse({ success: false, error: 'Unknown action: ' + action });
  } catch (e: any) {
    return jsonResponse({ success: false, error: e?.message || 'Internal server error' }, 500);
  }
});
