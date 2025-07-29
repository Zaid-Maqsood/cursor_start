import 'dart:html' as html;
import 'package:uuid/uuid.dart';

class SessionManager {
  static String? _sessionId;
  
  static String get sessionId {
    if (_sessionId == null) {
      // Try to get from localStorage first
      _sessionId = html.window.localStorage['chat_session_id'];
      
      // If not found, generate new one
      if (_sessionId == null || _sessionId!.isEmpty) {
        _sessionId = const Uuid().v4();
        html.window.localStorage['chat_session_id'] = _sessionId!;
      }
    }
    return _sessionId!;
  }
  
  static void resetSession() {
    _sessionId = null;
    html.window.localStorage.remove('chat_session_id');
  }
} 