import 'dart:js_interop';

/// Web implementation - gets User-Agent from browser
String? getUserAgent() {
  try {
    // Access navigator.userAgent via JS interop
    final userAgent = _getNavigatorUserAgent();
    return userAgent;
  } catch (e) {
    return null;
  }
}

@JS('navigator.userAgent')
external String? _getNavigatorUserAgent();
