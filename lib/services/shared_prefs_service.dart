import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences for type-safe access.
/// Used across services that need persistent local storage.
class SharedPrefsService {
  static SharedPreferences? _instance;

  static Future<SharedPreferences> get instance async {
    _instance ??= await SharedPreferences.getInstance();
    return _instance!;
  }
}
