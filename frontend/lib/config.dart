class Config {
  static const bool isProduction = false; // Set to true when deploying
  static const String prodUrl = 'https://your-backend-app.onrender.com';
  static const String devUrl = 'http://10.127.160.179:5000';

  static const String serverUrl = isProduction ? prodUrl : devUrl;
  static const String apiUrl = '$serverUrl/api';
}
