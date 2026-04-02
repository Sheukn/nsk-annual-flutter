class ApiConfig {
  static const String baseUrl = 'http://192.168.0.29:8081/api';
  
  // Sync endpoints
  static const String syncHealth = '$baseUrl/sync/health';
  static const String syncLast = '$baseUrl/sync/last';
  
  // Photo endpoints
  static const String photosList = '$baseUrl/photos';
  static const String photosBatch = '$baseUrl/photos/batch';
  
  // Board endpoints
  static const String boards = '$baseUrl/boards';
}
