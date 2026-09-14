import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_client.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // ✅ AMBOS GETTERS (por si acaso)
  UserModel? get user => _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<void> initialize() async {
    final session = _supabase.auth.currentSession;
    print('🔵 initialize() - Session: ${session?.user.id}');
    if (session != null) {
      await fetchUserData(session.user.id);
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      print('🔵 signIn() - Response: ${response.user?.id}');

      if (response.session != null) {
        await fetchUserData(response.user!.id);
        print('🔵 signIn() - User cargado: ${_currentUser?.email}');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('No se pudo iniciar sesión');
      }
    } catch (e) {
      _errorMessage = e.toString();
      print('🔴 signIn() - Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchUserData(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      _currentUser = UserModel.fromMap(response);
      print('🔵 fetchUserData() - User: ${_currentUser?.email}');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar datos: $e';
      print('🔴 fetchUserData() - Error: $e');
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}