import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global chat font-size scale (WhatsApp "Font size" parity).
/// Small = 0.85, Medium = 1.0, Large = 1.15.
///
/// The chat screen wraps its body with a MediaQuery textScaler bound to
/// this notifier so every chat text scales live, including bubbles,
/// timestamps and the input field.
class FontScaleService {
  FontScaleService._();
  static final FontScaleService instance = FontScaleService._();

  static const _kPref = 'kora_font_scale';

  /// Notifies listeners whenever the user changes the chat font size.
  final ValueNotifier<double> scale = ValueNotifier<double>(1.0);

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_kPref);
    if (v != null && v > 0 && v <= 2.0) {
      scale.value = v;
    }
    _loaded = true;
  }

  Future<void> setScale(double value) async {
    scale.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPref, value);
  }

  /// 0 = Small, 1 = Medium, 2 = Large
  static const sizes = <double>[0.85, 1.0, 1.15];
  static const labels = <String>['Small', 'Medium', 'Large'];

  int get index {
    final v = scale.value;
    var best = 1;
    var bestDist = double.infinity;
    for (var i = 0; i < sizes.length; i++) {
      final d = (sizes[i] - v).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  Future<void> setIndex(int i) => setScale(sizes[i]);
}
