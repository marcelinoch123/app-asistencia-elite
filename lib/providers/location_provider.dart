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

    _isTracking = true;
    print('📍 Iniciando rastreo continuo para: $userId');

    // Enviar ubicación inmediatamente
    _updateLocationInSupabase(userId);

    // Actualizar cada 30 segundos
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateLocationInSupabase(userId);
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
      final position = await getCurrentLocation();
      if (position == null) return;

      // ✅ GUARDAR EN TABLA live_locations
      await _supabase.from('live_locations').upsert({
        'user_id': userId,
        'lat': position.latitude,
        'lng': position.longitude,
        'last_update': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');

      print('✅ Ubicación guardada en Supabase');
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