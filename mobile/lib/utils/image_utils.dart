import 'app_urls.dart';

class ImageUtils {
  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    
    // Agar already full URL hai (http ya https se start)
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    
    // Local path hai to base URL jodo
    return '${AppUrls.baseUrl}/$path';
  }
}