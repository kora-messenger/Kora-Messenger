import 'package:flutter/material.dart';

/// Kora's own visual identity — a purple-to-blue gradient
/// inspired by the app icon, paired with a deep, near-black surface.
class KoraColors {
  static const Color purple = Color(0xFF8B5CF6);
  static const Color blue = Color(0xFF3B82F6);

  // Welcome/splash screen — pure near-black background
  static const Color trueBlack = Color(0xFF050508);

  static const Color deepNavy = Color(0xFF0A0A14);
  static const Color darkSurface = Color(0xFF13131F);
  static const Color darkCard = Color(0xFF1A1A2E);

  // Secondary "dark pill" button surface (Create Account on Welcome screen)
  static const Color darkPill = Color(0xFF1C1C2B);

  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color lightCard = Color(0xFFFFFFFF);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, blue],
  );
}
