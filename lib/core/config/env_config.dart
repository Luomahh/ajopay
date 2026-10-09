import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed wrapper around environment variables.
/// No other file in the app should read dotenv or hardcode these values directly.
class EnvConfig {
  EnvConfig._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception(
        'Missing required environment variable: $key. '
        'Check that .env exists and is listed under pubspec.yaml assets.',
      );
    }
    return value;
  }
}
