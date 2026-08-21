import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Data Saver service for Kora Messenger.
///
/// Reduces mobile data consumption by:
/// - Limiting the in-memory image cache size
/// - Setting lower decode resolution for network images (memCacheWidth)
/// - Disabling auto-download of media on cellular (future)
/// - Capping image quality for uploads
///
/// Also exposes a user-facing "Data Saver" toggle (stored in prefs)
/// that, when on, enforces stricter limits.
class DataSaverService {
  static const _kDataSaverKey = 'kora_data_saver_enabled';

  /// Whether Data Saver is on. When enabled, images download at even
  /// lower resolution and auto-download of media is disabled.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDataSaverKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDataSaverKey, value);
  }

  /// Call once at app startup to cap the in-memory image cache.
  /// Flutter's default is 100MB / 1000 images — way too much for
  /// a messaging app with lots of small avatars and thumbnails.
  static void tuneImageCache() {
    PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024; // 30MB
    PaintingBinding.instance.imageCache.maximumSize = 250; // 250 images max
  }

  /// Returns the optimal memCacheWidth for network images.
  /// Uses a smaller width when Data Saver is on.
  static Future<int> optimalImageWidth({double devicePixelRatio = 3.0}) async {
    final saver = await isEnabled();
    // Data saver: 200px max for avatars/thumbnails
    // Normal: 400px (still small enough to save data vs full-res)
    return saver ? 200 : 400;
  }

  /// Default CachedNetworkImage options used across the app.
  /// Centralized here so every image widget gets the same data-saving
  /// treatment without repeating the config.
  static Map<String, dynamic> cachedImageDefaults({
    required double displaySize,
    required bool dataSaver,
  }) {
    final cacheWidth = (displaySize * (dataSaver ? 1.5 : 2.0)).toInt();
    return {
      'memCacheWidth': cacheWidth,
      'maxWidthDiskCache': cacheWidth,
      'cacheManager': null,
    };
  }
}
