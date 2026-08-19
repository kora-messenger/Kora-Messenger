import 'package:flutter/material.dart';

/// Kora's own visual identity — a purple-to-blue gradient
/// inspired by the app icon, paired with a deep, near-black surface.
class KoraColors {
  static const Color purple = Color(0xFF8B5CF6);
  static const Color blue = Color(0xFF3B82F6);

  // Semantic
  static const Color red = Color(0xFFEF4444);

  // Welcome/splash screen — pure near-black background
  static const Color trueBlack = Color(0xFF050508);

  static const Color deepNavy = Color(0xFF0A0A14);
  static const Color darkSurface = Color(0xFF13131F);
  static const Color darkCard = Color(0xFF1A1A2E);

  // Secondary "dark pill" button surface (Create Account on Welcome screen)
  static const Color darkPill = Color(0xFF1C1C2B);

  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5FA);
  static const Color lightBorder = Color(0xFFE2E2EC);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, blue],
  );

  // ── Adaptive helpers (pick based on Brightness) ────────────

  static Color backgroundFor(Brightness b) =>
      b == Brightness.dark ? trueBlack : lightBackground;

  static Color cardFor(Brightness b) =>
      b == Brightness.dark ? darkCard : lightCard;

  static Color surfaceFor(Brightness b) =>
      b == Brightness.dark ? darkSurface : lightSurface;

  static Color textPrimaryFor(Brightness b) =>
      b == Brightness.dark ? Colors.white : const Color(0xFF1A1A2E);

  static Color textSecondaryFor(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFA0A0B8) : const Color(0xFF6B6B80);

  static Color textMutedFor(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF6B6B80) : const Color(0xFF9A9AB0);

  static Color borderFor(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2E2E42) : lightBorder;

  static Color hintFor(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF4A4A5E) : const Color(0xFFB0B0C0);

  static Color inputFillFor(Brightness b) =>
      b == Brightness.dark ? darkCard : lightCard;
}
