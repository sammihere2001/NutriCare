import 'package:http/http.dart' as http;
import 'package:nutricare/services/auth_service.dart';

class ApiClient {
  static final Map<String, DateTime> _lastRequestTime = {};
  static const Duration _minRequestInterval = Duration(seconds: 2);
  
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final key = url.toString();
    
    // ✅ Prevent duplicate rapid requests
    if (_lastRequestTime.containsKey(key)) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime[key]!);
      if (timeSinceLastRequest < _minRequestInterval) {
        print("⏱️ Skipping duplicate request to $key (${timeSinceLastRequest.inMilliseconds}ms ago)");
        throw Exception("Request too frequent");
      }
    }
    
    _lastRequestTime[key] = DateTime.now();
    
    final auth = await AuthService().getAuth();
    final allHeaders = {
      'Authorization': 'Bearer ${auth?.accessToken}',
      'Content-Type': 'application/json',
      ...?headers,
    };
    
    return await http.get(url, headers: allHeaders);
  }
}