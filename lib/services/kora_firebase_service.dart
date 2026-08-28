/// Kora Firebase Service — stubbed (Firebase project not yet configured).
/// Replace with real implementation when Firebase is set up.
class KoraFirebaseService {
  static final KoraFirebaseService instance = KoraFirebaseService._();
  KoraFirebaseService._();

  Future<void> initialize() async {
    // No-op until Firebase is configured
  }

  Future<String?> getToken() async => null;

  Future<void> subscribeToTopic(String topic) async {}

  Future<void> unsubscribeFromTopic(String topic) async {}
}
