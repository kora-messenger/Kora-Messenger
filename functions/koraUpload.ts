import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const db = base44.asServiceRole;
  const body = await req.json();
  const { action } = body;

  try {
    // ── UPLOAD AVATAR ─────────────────────────────────
    if (action === 'uploadAvatar') {
      const { imageBase64, fileName, fileType } = body;
      if (!imageBase64) return jsonResponse({ success: false, error: 'No image data provided' });
      if (!fileName) return jsonResponse({ success: false, error: 'No file name provided' });

      // Decode base64 to binary
      const binaryString = atob(imageBase64);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }

      // Create a Blob and upload to Base44 file storage
      const blob = new Blob([bytes], { type: fileType || 'image/jpeg' });
      const file = new File([blob], fileName, { type: fileType || 'image/jpeg' });

      // Use Base44's built-in file upload
      const uploaded = await base44.files.upload(file);

      // The uploaded object contains a URL we can return to the client
      const url = uploaded.url || uploaded.file_url || uploaded;

      return jsonResponse({
        success: true,
        url: typeof url === 'string' ? url : url.url || url.toString(),
      });
    }

    // ── UPLOAD MEDIA (for chat attachments) ───────────
    if (action === 'uploadMedia') {
      const { imageBase64, fileName, fileType } = body;
      if (!imageBase64) return jsonResponse({ success: false, error: 'No media data provided' });

      const binaryString = atob(imageBase64);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }

      const blob = new Blob([bytes], { type: fileType || 'application/octet-stream' });
      const file = new File([blob], fileName || 'media', { type: fileType || 'application/octet-stream' });

      const uploaded = await base44.files.upload(file);
      const url = uploaded.url || uploaded.file_url || uploaded;

      return jsonResponse({
        success: true,
        url: typeof url === 'string' ? url : url.url || url.toString(),
      });
    }

    return jsonResponse({ success: false, error: 'Unknown action: ' + action });
  } catch (e: any) {
    return jsonResponse({ success: false, error: e?.message || 'Internal server error' }, 500);
  }
});
