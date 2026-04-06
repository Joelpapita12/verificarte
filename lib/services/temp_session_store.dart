class TempSessionStore {
  static final Map<String, Map<String, String>> _store = {};

  static String createSession({
    required String email,
    required String accountType,
  }) {
    final String sessionId =
        'sess_${DateTime.now().millisecondsSinceEpoch}_${_store.length + 1}';
    _store[sessionId] = {'email': email, 'accountType': accountType};
    return sessionId;
  }

  static String? getEmail(String sessionId) {
    return _store[sessionId]?['email'];
  }

  static String? getAccountType(String sessionId) {
    return _store[sessionId]?['accountType'];
  }
}
