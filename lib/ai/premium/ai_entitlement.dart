import 'package:flutter/foundation.dart';
import '../../services/payment_service.dart';

/// AI features that can be gated by premium status.
enum AIFeature {
  basicConversation,      // free
  advancedAI,              // premium
  higherAILimits,         // premium
  chatSummary,            // free
  catchMeUp,              // free
  advancedTranslation,    // premium
  voiceAI,                // premium
  fileAnalysis,           // premium
  imageUnderstanding,     // free
  writingAssistant,       // free
  replySuggestions,       // free
}

/// Premium entitlement checks for AI features.
/// Queries the existing PaymentService — does NOT create a separate premium system.
class AIEntitlement {
  static const _freeFeatures = {
    AIFeature.basicConversation,
    AIFeature.chatSummary,
    AIFeature.catchMeUp,
    AIFeature.imageUnderstanding,
    AIFeature.writingAssistant,
    AIFeature.replySuggestions,
  };

  static const _premiumFeatures = {
    AIFeature.advancedAI,
    AIFeature.higherAILimits,
    AIFeature.advancedTranslation,
    AIFeature.voiceAI,
    AIFeature.fileAnalysis,
  };

  /// Check if the current user can use a feature.
  static Future<bool> canUseFeature(AIFeature feature) async {
    if (_freeFeatures.contains(feature)) return true;
    if (_premiumFeatures.contains(feature)) {
      try { return await PaymentService.isPremium(); } catch (_) { return false; }
    }
    return false;
  }

  /// Get remaining usage for a feature (approximate, server enforces actual limits).
  static Future<int> getRemainingUsage(AIFeature feature) async {
    final isPremium = await PaymentService.isPremium();
    final limits = isPremium ? _premiumLimits : _freeLimits;
    return limits[feature] ?? 50;
  }

  /// Track usage locally (server tracks actual usage for enforcement).
  static Future<void> trackUsage(AIFeature feature, {int tokens = 1}) async {
    debugPrint('[AIEntitlement] Tracked usage: ${feature.name} ($tokens tokens)');
  }

  static const _freeLimits = {
    AIFeature.basicConversation: 50,
    AIFeature.chatSummary: 20,
    AIFeature.catchMeUp: 20,
    AIFeature.imageUnderstanding: 30,
    AIFeature.writingAssistant: 30,
    AIFeature.replySuggestions: 40,
    AIFeature.advancedAI: 0,
    AIFeature.higherAILimits: 0,
    AIFeature.advancedTranslation: 0,
    AIFeature.voiceAI: 0,
    AIFeature.fileAnalysis: 0,
  };

  static const _premiumLimits = {
    AIFeature.basicConversation: 200,
    AIFeature.chatSummary: 50,
    AIFeature.catchMeUp: 50,
    AIFeature.imageUnderstanding: 100,
    AIFeature.writingAssistant: 100,
    AIFeature.replySuggestions: 100,
    AIFeature.advancedAI: 100,
    AIFeature.higherAILimits: 500,
    AIFeature.advancedTranslation: 100,
    AIFeature.voiceAI: 50,
    AIFeature.fileAnalysis: 50,
  };
}
