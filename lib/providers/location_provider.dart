import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_client.dart';

class LocationProvider extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  Timer? _locationTimer;
  bool _isTracking = false;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTracking => _isTracking;

  // ============================================================
  // VERIFICAR PERMISOS
  // ============================================================
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = 'El GPS está desactivado. Actívalo en tu dispositivo.';
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _error = 'Permiso de ubicación denegado.';
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _error = 'Permiso de ubicación denegado permanentemente. Ve a configuración del navegador.';
      notifyListeners();
      return false;
    }

    _error = null;
    notifyListeners();
    return true;
  }

  // ============================================================
  // OBTENER UBICACIÓN ACTUAL
  // ============================================================
  Future<Position?> getCurrentLocation() async {
    _isLoading = true;
    notifyListeners();

    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // ✅ ALTA PRECISIÓN
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('📍 Ubicación: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      print('📍 Precisión: ${_currentPosition!.accuracy} metros');

      _error = null;
      _isLoading = false;
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      _error = 'Error al obtener ubicación: $e';
      print('❌ Error ubicación: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ============================================================
  // INICIAR RASTREO CONTINUO (cada 30 segundos)
  // ============================================================
  void startTracking(String userId) {
    if (_isTracking) return;

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      print('⚠️ No se puede iniciar rastreo: no hay usuario autenticado en Supabase');
      return;
    }

    _isTracking = true;
    final uid = currentUser.id;
    print('📍 Iniciando rastreo continuo para: $uid');

    // Enviar ubicación inmediatamente
    _updateLocationInSupabase(uid);

    // Actualizar cada 30 segundos
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateLocationInSupabase(uid);
    });

    notifyListeners();
  }

  // ============================================================
  // DETENER RASTREO
  // ============================================================
  void stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;
    print('📍 Rastreo detenido');
    notifyListeners();
  }

  // ============================================================
  // ACTUALIZAR UBICACIÓN EN SUPABASE
  // ============================================================
  Future<void> _updateLocationInSupabase(String userId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        print('⚠️ No hay sesión activa en Supabase Auth, deteniendo rastreo');
        stopTracking();
        return;
      }

      final uid = currentUser.id;

      final position = await getCurrentLocation();
      if (position == null) return;

      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final data = {
        'user_id': uid,
        'lat': position.latitude,
        'lng': position.longitude,
        'last_update': nowUtc,
      };

      // 1. Intentar con upsert especificando onConflict: 'user_id'
      try {
        await _supabase.from('live_locations').upsert(
          data,
          onConflict: 'user_id',
        );
        print('✅ Ubicación guardada en Supabase (upsert)');
        return;
      } catch (upsertError) {
        print('⚠️ Upsert en live_locations falló ($upsertError), intentando update/insert...');
      }

      // 2. Fallback a UPDATE directo si RLS bloquea el ON CONFLICT DO UPDATE
      final updateRes = await _supabase
          .from('live_locations')
          .update({
            'lat': position.latitude,
            'lng': position.longitude,
            'last_update': nowUtc,
          })
          .eq('user_id', uid)
          .select();

      if (updateRes.isEmpty) {
        // 3. Si no existía fila previa, realizar INSERT directo
        await _supabase.from('live_locations').insert(data);
        print('✅ Ubicación guardada en Supabase (insert)');
      } else {
        print('✅ Ubicación guardada en Supabase (update)');
      }
    } catch (e) {
      print('❌ Error guardando ubicación: $e');
    }
  }

  // ============================================================
  // CALCULAR DISTANCIA A UN PUNTO (Geocerca)
  // ============================================================
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  // ============================================================
  // VERIFICAR SI ESTÁ DENTRO DE LA GEOCERCA
  // ============================================================
  bool isWithinGeofence(
    Position current,
    double targetLat,
    double targetLng,
    double radiusMeters,
  ) {
    final distance = calculateDistance(
      current.latitude,
      current.longitude,
      targetLat,
      targetLng,
    );
    print('📍 Distancia al punto: ${distance.toStringAsFixed(2)}m (radio: ${radiusMeters}m)');
    return distance <= radiusMeters;
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
}