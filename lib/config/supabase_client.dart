// lib/config/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String _url = 'https://mymuqnhhtqwnaqaamimz.supabase.co';
  static const String _publishableKey = 'sb_publishable_7JICkQ3yLA2DiWg9PmH78Q_8qQJWiya';

  static Future<void> init() async {
    await Supabase.initialize(
      url: _url,
      publishableKey: _publishableKey, // ✅ publishableKey (no anonKey)
    );
    print('✅ Supabase inicializado');
  }

  static SupabaseClient get client => Supabase.instance.client;
}