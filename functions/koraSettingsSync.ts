/**
 * Kora Settings Sync — Telegram-style cloud settings.
 *
 * Every user preference (theme, notifications, privacy, wallpapers,
 * per-chat settings, ...) is stored as a merged JSON blob keyed by
 * userEmail. Log in on any device and all settings appear — no
 * restore flow needed.
 *
 * Actions:
 * 1. "save" — merge {settings: {key: {_t, _v}}} into the stored blob
 *             (per-key last write wins across devices)
 * 2. "load" — return the merged settings blob + updatedAt
 *
 * Entity: UserSettings
 */
import { createClientFromRequest } from "npm:@base44/sdk@0.8.31";

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  const base44 = createClientFromRequest(req);
  const body = await req.json().catch(() => ({}));
  const { action, userEmail } = body;

  if (!userEmail) {
    return jsonResponse({ success: false, error: "userEmail is required" }, 400);
  }

  try {
    const db = base44;

    // ── SAVE (merge) ────────────────────────────────────
    // Client pushes { settings: { key: { _t: 'b'|'i'|'d'|'s'|'l', _v } } } —
    // each key is merged into the stored blob (per-key last write wins).
    if (action === "save") {
      const settings = body.settings;
      if (!settings || typeof settings !== "object") {
        return jsonResponse({ success: false, error: "settings object required" }, 400);
      }

      const existing = await db.entities.UserSettings.filter(
        { userEmail },
        undefined,
        1
      );

      let merged: Record<string, any> = {};
      if (existing && existing.length > 0) {
        try {
          merged = JSON.parse(existing[0].settingsJson || "{}");
        } catch {
          merged = {};
        }
        Object.assign(merged, settings);
        await db.entities.UserSettings.update(existing[0].id, {
          settingsJson: JSON.stringify(merged),
          keyCount: Object.keys(merged).length,
          updatedAt: new Date().toISOString(),
          deviceName: body.deviceName || existing[0].deviceName,
        });
      } else {
        merged = { ...settings };
        await db.entities.UserSettings.create({
          userEmail,
          settingsJson: JSON.stringify(merged),
          keyCount: Object.keys(merged).length,
          updatedAt: new Date().toISOString(),
          deviceName: body.deviceName || "unknown",
        });
      }

      return jsonResponse({
        success: true,
        updatedAt: new Date().toISOString(),
        keyCount: Object.keys(merged).length,
      });
    }

    // ── LOAD ────────────────────────────────────────────
    if (action === "load") {
      const existing = await db.entities.UserSettings.filter(
        { userEmail },
        undefined,
        1
      );
      if (!existing || existing.length === 0) {
        return jsonResponse({ success: true, settings: {}, updatedAt: null });
      }
      let settings = {};
      try {
        settings = JSON.parse(existing[0].settingsJson || "{}");
      } catch {
        settings = {};
      }
      return jsonResponse({
        success: true,
        settings,
        updatedAt: existing[0].updatedAt,
      });
    }

    return jsonResponse({ success: false, error: "Unknown action: " + action }, 400);
  } catch (e: any) {
    return jsonResponse({ success: false, error: e?.message || "Internal server error" }, 500);
  }
});
