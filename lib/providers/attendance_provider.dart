import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../config/supabase_client.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

class AttendanceProvider extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;

  List<AttendanceModel> _attendances = [];
  List<UserModel> _allEmployees = [];
  bool _isLoading = false;
  String? _error;
  AttendanceModel? _todayAttendance;
  List<Map<String, dynamic>> _todayAssignments = [];

  int _lastLateMinutes = 0;
  double _lastLateFee = 0.0;
  int _lastToleranceMinutesUsed = 0;
  int _lastEarlyLeaveMinutes = 0;
  String? _lastShiftStart;
  String? _lastCheckInTime;

  List<AttendanceModel> get attendances => _attendances;
  List<UserModel> get allEmployees => _allEmployees;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AttendanceModel? get todayAttendance => _todayAttendance;
  List<Map<String, dynamic>> get todayAssignments => _todayAssignments;

  int get lastLateMinutes => _lastLateMinutes;
  double get lastLateFee => _lastLateFee;
  int get lastToleranceMinutesUsed => _lastToleranceMinutesUsed;
  int get lastEarlyLeaveMinutes => _lastEarlyLeaveMinutes;
  String? get lastShiftStart => _lastShiftStart;
  String? get lastCheckInTime => _lastCheckInTime;

  int _currentMonthAbsences = 0;
  int get currentMonthAbsences => _currentMonthAbsences;

  double? _officeLat;
  double? _officeLng;
  int _officeRadius = 500;

  double? get officeLat => _officeLat;
  double? get officeLng => _officeLng;
  int get officeRadius => _officeRadius;

  SupabaseClient get supabaseClient => _supabase;

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getDayCode(DateTime date) {
    const days = ['DOM', 'LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB'];
    return days[date.weekday % 7];
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Future<void> fetchAttendances(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('attendances')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _attendances = response.map((data) => AttendanceModel.fromMap(data)).toList();

      final today = _getTodayString();
      final todays = _attendances.where((a) => a.date == today).toList();

      if (todays.isNotEmpty) {
        _todayAttendance = todays.first;
      } else {
        _todayAttendance = _emptyAttendance(userId, today);
      }

      await fetchTodayAssignments(userId);

      // Sincronizar faltas dinámicas del mes actual
      final now = DateTime.now();
      await countAbsences(userId, now.month, now.year);

      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error en fetchAttendances: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  AttendanceModel _emptyAttendance(String userId, String today) {
    return AttendanceModel(
      id: '',
      userId: userId,
      date: today,
      checkIn: null,
      checkOut: null,
      status: 'absent',
      photoUrl: null,
      locationLat: null,
      locationLng: null,
      lateMinutes: 0,
      lateFee: 0.0,
      workedMinutes: 0,
      createdAt: DateTime.now(),
    );
  }

  Future<void> fetchTodayAssignments(String userId) async {
    try {
      final today = _getTodayString();

      final response = await _supabase
          .from('shift_assignments')
          .select()
          .eq('user_id', userId)
          .eq('assigned_date', today);

      final assignments = List<Map<String, dynamic>>.from(response);

      for (var i = 0; i < assignments.length; i++) {
        final shiftId = assignments[i]['shift_id'];
        final clientId = assignments[i]['client_id'];

        if (shiftId != null) {
          try {
            final shift = await _supabase
                .from('shifts')
                .select()
                .eq('id', shiftId)
                .maybeSingle();
            assignments[i]['shift_data'] = shift;
          } catch (e) {
            assignments[i]['shift_data'] = null;
          }
        }

        if (clientId != null) {
          try {
            final client = await _supabase
                .from('clients')
                .select()
                .eq('id', clientId)
                .maybeSingle();
            assignments[i]['client_data'] = client;
          } catch (e) {
            assignments[i]['client_data'] = null;
          }
        }

        final existing = _attendances.where((a) =>
            a.date == today && a.shiftId == shiftId).toList();
        assignments[i]['attendance'] = existing.isNotEmpty ? existing.first : null;
      }

      _todayAssignments = assignments;
    } catch (e) {
      print('Error en fetchTodayAssignments: $e');
      _todayAssignments = [];
    }
  }

  Future<Map<String, dynamic>?> getAssignmentsForDate(String userId, String date) async {
    try {
      final response = await _supabase
          .from('shift_assignments')
          .select()
          .eq('user_id', userId)
          .eq('assigned_date', date);

      final assignments = List<Map<String, dynamic>>.from(response);

      for (var i = 0; i < assignments.length; i++) {
        final shiftId = assignments[i]['shift_id'];
        final clientId = assignments[i]['client_id'];

        if (shiftId != null) {
          final shift = await _supabase
              .from('shifts')
              .select()
              .eq('id', shiftId)
              .maybeSingle();
          assignments[i]['shift_data'] = shift;

          try {
            final attendance = await _supabase
                .from('attendances')
                .select()
                .eq('user_id', userId)
                .eq('date', date)
                .eq('shift_id', shiftId)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            assignments[i]['attendance'] = attendance;
          } catch (e) {
            assignments[i]['attendance'] = null;
          }

          if (assignments[i]['attendance'] == null) {
            final memAtt = _attendances
                .where((a) => a.date == date && (shiftId == null || a.shiftId == shiftId))
                .firstOrNull;
            if (memAtt != null && memAtt.checkIn != null) {
              assignments[i]['attendance'] = memAtt.toMap();
            }
          }
        }

        if (clientId != null) {
          final client = await _supabase
              .from('clients')
              .select()
              .eq('id', clientId)
              .maybeSingle();
          assignments[i]['client_data'] = client;
        }
      }

      return {'date': date, 'assignments': assignments};
    } catch (e) {
      print('Error en getAssignmentsForDate: $e');
      return null;
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> fetchMonthAssignmentsBatch(
    String userId,
    DateTime month,
  ) async {
    try {
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);
      final firstDayStr =
          '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
      final lastDayStr =
          '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      // 1. Consultar asignaciones del mes completo
      final assignmentsResponse = await _supabase
          .from('shift_assignments')
          .select()
          .eq('user_id', userId)
          .gte('assigned_date', firstDayStr)
          .lte('assigned_date', lastDayStr);

      final rawAssignments = List<Map<String, dynamic>>.from(assignmentsResponse);
      if (rawAssignments.isEmpty) {
        return {};
      }

      // Recolectar IDs únicos
      final shiftIds = rawAssignments
          .map((a) => a['shift_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      final clientIds = rawAssignments
          .map((a) => a['client_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      // 2. Consultar turnos en lote
      final Map<dynamic, Map<String, dynamic>> shiftsMap = {};
      if (shiftIds.isNotEmpty) {
        try {
          final shiftsResponse = await _supabase
              .from('shifts')
              .select()
              .inFilter('id', shiftIds);
          for (final s in shiftsResponse) {
            shiftsMap[s['id']] = Map<String, dynamic>.from(s);
          }
        } catch (e) {
          print('Error en batch shifts: $e');
        }
      }

      // 3. Consultar clientes en lote
      final Map<dynamic, Map<String, dynamic>> clientsMap = {};
      if (clientIds.isNotEmpty) {
        try {
          final clientsResponse = await _supabase
              .from('clients')
              .select()
              .inFilter('id', clientIds);
          for (final c in clientsResponse) {
            clientsMap[c['id']] = Map<String, dynamic>.from(c);
          }
        } catch (e) {
          print('Error en batch clients: $e');
        }
      }

      // 4. Consultar asistencias del mes ordenadas por created_at desc
      final Map<String, Map<String, dynamic>> attendancesMap = {};
      try {
        final attendancesResponse = await _supabase
            .from('attendances')
            .select()
            .eq('user_id', userId)
            .gte('date', firstDayStr)
            .lte('date', lastDayStr)
            .order('created_at', ascending: false);

        for (final att in attendancesResponse) {
          final attMap = Map<String, dynamic>.from(att);
          final key = '${attMap['date']}_${attMap['shift_id']}';
          if (!attendancesMap.containsKey(key)) {
            attendancesMap[key] = attMap;
          }
        }
      } catch (e) {
        print('Error en batch attendances: $e');
      }

      // Agrupar asignaciones por fecha
      final Map<String, List<Map<String, dynamic>>> resultMap = {};

      for (final raw in rawAssignments) {
        final assignment = Map<String, dynamic>.from(raw);
        final dateStr = assignment['assigned_date']?.toString() ?? '';
        final shiftId = assignment['shift_id'];
        final clientId = assignment['client_id'];

        assignment['shift_data'] = (shiftId != null && shiftsMap.containsKey(shiftId))
            ? shiftsMap[shiftId]
            : null;

        assignment['client_data'] = (clientId != null && clientsMap.containsKey(clientId))
            ? clientsMap[clientId]
            : null;

        // Búsqueda de attendance y protección contra race conditions
        final attKey = '${dateStr}_$shiftId';
        Map<String, dynamic>? attendance = attendancesMap[attKey];

        // Protección con attendances en memoria
        final memAtt = _attendances
            .where((a) => a.date == dateStr && (shiftId == null || a.shiftId == shiftId))
            .firstOrNull;

        if (memAtt != null && memAtt.checkIn != null) {
          DateTime? dbCheckIn;
          if (attendance != null && attendance['check_in'] != null) {
            dbCheckIn = DateTime.tryParse(attendance['check_in'].toString());
          }

          if (dbCheckIn == null || memAtt.checkIn!.isAfter(dbCheckIn)) {
            // Conservar el de memoria por ser más reciente
            attendance = memAtt.toMap();
          }
        }

        assignment['attendance'] = attendance;

        if (!resultMap.containsKey(dateStr)) {
          resultMap[dateStr] = [];
        }
        resultMap[dateStr]!.add(assignment);
      }

      return resultMap;
    } catch (e) {
      print('Error en fetchMonthAssignmentsBatch: $e');
      return {};
    }
  }

  Future<bool> checkIn(
    String userId,
    dynamic photoData,
    String shiftId, {
    bool skipPhoto = false,
    bool isOffice = false,
    String? notes,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final today = _getTodayString();
      final dayCode = _getDayCode(now);

      final existing = await _supabase
          .from('attendances')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .eq('shift_id', shiftId)
          .maybeSingle();

      if (existing != null && existing['check_in'] != null) {
        _error = 'Ya registraste tu entrada para este turno';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      Map<String, dynamic>? shift;
      try {
        final shiftResponse = await _supabase
            .from('shifts')
            .select()
            .eq('id', shiftId)
            .maybeSingle();
        shift = shiftResponse;
      } catch (e) {
        print('Error buscando turno: $e');
      }

      if (shift != null && shift['days'] != null) {
        final shiftDays = List<String>.from(shift['days'] as List);
        if (!shiftDays.contains(dayCode)) {
          _error = 'Hoy ($dayCode) no es dia laborable para este turno';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Restricción de horario: solo se permite marcar desde 30 min antes del inicio del turno
      if (shift != null && shift['start_time'] != null) {
        final startParts = (shift['start_time'] as String).split(':');
        if (startParts.length >= 2) {
          final startH = int.parse(startParts[0]);
          final startM = int.parse(startParts[1]);
          final shiftStart = DateTime(
            now.year,
            now.month,
            now.day,
            startH,
            startM,
          );
          final earliestAllowed = shiftStart.subtract(const Duration(minutes: 5));
          if (now.isBefore(earliestAllowed)) {
            final formattedStart = '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}';
            _error = 'Aún no puedes marcar. Tu turno empieza a las $formattedStart';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }
      }

      double? empLat;
      double? empLng;
      Uint8List? photoBytes;

      if (photoData is Map) {
        empLat = (photoData['lat'] as num?)?.toDouble();
        empLng = (photoData['lng'] as num?)?.toDouble();
        photoBytes = photoData['photoBytes'] as Uint8List?;
      }

      if (empLat != null && empLng != null) {
        if (isOffice) {
          if (_officeLat == null || _officeLng == null) {
            await fetchOfficeSettings();
          }

          // Solo validar distancia si la oficina tiene coordenadas válidas configuradas
          if (_officeLat != null && _officeLng != null && (_officeLat != 0.0 || _officeLng != 0.0)) {
            final distance = Geolocator.distanceBetween(
              empLat,
              empLng,
              _officeLat!,
              _officeLng!,
            );

            if (distance > _officeRadius) {
              _error = 'Estas fuera del rango permitido. Distancia: ${distance.toStringAsFixed(0)}m. Maximo: ${_officeRadius}m';
              _isLoading = false;
              notifyListeners();
              return false;
            }
          }
          // Si no tiene coordenadas configuradas (null o 0.0), se permite marcar desde cualquier lugar
        } else {
          try {
            final assignment = await _supabase
                .from('shift_assignments')
                .select('client_id')
                .eq('user_id', userId)
                .eq('assigned_date', today)
                .eq('shift_id', shiftId)
                .maybeSingle();

            if (assignment != null && assignment['client_id'] != null) {
              final client = await _supabase
                  .from('clients')
                  .select()
                  .eq('id', assignment['client_id'])
                  .maybeSingle();

              if (client != null) {
                final clientLat = (client['location_lat'] as num?)?.toDouble();
                final clientLng = (client['location_lng'] as num?)?.toDouble();
                final radius = (client['radius_meters'] as int?) ?? 500;

                // Solo validar distancia si el cliente tiene coordenadas válidas configuradas
                if (clientLat != null && clientLng != null && (clientLat != 0.0 || clientLng != 0.0)) {
                  final distance = Geolocator.distanceBetween(
                    empLat,
                    empLng,
                    clientLat,
                    clientLng,
                  );

                  if (distance > radius) {
                    _error = 'Estas fuera del rango permitido. Distancia: ${distance.toStringAsFixed(0)}m. Maximo: ${radius}m';
                    _isLoading = false;
                    notifyListeners();
                    return false;
                  }
                }
                // Si no tiene coordenadas configuradas (null o 0.0), se permite marcar desde cualquier lugar
              }
            }
          } catch (e) {
            print('Error verificando geocerca: $e');
          }
        }
      }

      String? photoUrl;
      if (!skipPhoto && photoBytes != null) {
        try {
          photoUrl = await _uploadPhotoBytes(photoBytes, userId);
        } catch (e) {
          print('Error subiendo foto: $e');
        }
      }

      int toleranceMinutesUsed = 0;
      int lateMinutes = 0;
      double lateFee = 0.0;
      String? shiftStartStr;

      if (shift != null) {
        shiftStartStr = shift['start_time'] as String;
        final tolerance = (shift['tolerance_minutes'] as int?) ?? 10;
        final feePerMinute = (shift['late_fee_per_minute'] as num?)?.toDouble() ?? 1.0;

        final parts = shiftStartStr.split(':');
        final shiftStart = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        final diffMinutes = now.difference(shiftStart).inMinutes;

        // Regla 1: Llegada dentro de la tolerancia de 10 min
        if (diffMinutes > 0 && diffMinutes <= tolerance) {
          toleranceMinutesUsed = diffMinutes;
          lateMinutes = 0;
          lateFee = 0.0;
        }
        // Regla 3: A partir del minuto 11 (diffMinutes > tolerance)
        else if (diffMinutes > tolerance) {
          toleranceMinutesUsed = 0; // No cuenta para los 60 min de tolerancia
          lateMinutes = diffMinutes - tolerance;

          final hasPermission = await hasPermissionOnDate(userId, today);
          if (!hasPermission) {
            lateFee = lateMinutes * feePerMinute;
          }
        } else {
          // diffMinutes <= 0 (puntual o antes)
          toleranceMinutesUsed = 0;
          lateMinutes = 0;
          lateFee = 0.0;
        }
      }

      String status;
      if (lateMinutes == 0) {
        status = 'on_time';
      } else if (lateMinutes <= 15) {
        status = 'late';
      } else {
        status = 'very_late';
      }

      final insertData = <String, dynamic>{
        'user_id': userId,
        'date': today,
        'check_in': DateTime.now().toUtc().toIso8601String(),
        'status': status,
        'shift_id': shiftId,
        'late_minutes': lateMinutes,
        'late_fee': lateFee,
        'tolerance_minutes_used': toleranceMinutesUsed,
        'early_leave_minutes': 0,
        'worked_minutes': 0,
        'photo_url': photoUrl,
        'location_lat': empLat,
        'location_lng': empLng,
      };

      if (notes != null && notes.trim().isNotEmpty) {
        insertData['notes'] = notes.trim();
      }

      final response = await _supabase.from('attendances').insert(insertData).select();

      if (response.isNotEmpty) {
        _lastLateMinutes = lateMinutes;
        _lastLateFee = lateFee;
        _lastToleranceMinutesUsed = toleranceMinutesUsed;
        _lastShiftStart = shiftStartStr;
        _lastCheckInTime = _formatTime(now);

        await fetchAttendances(userId);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _error = e.toString();
      print('Error en checkIn: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> _uploadPhotoBytes(Uint8List bytes, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from('attendance_photos')
          .uploadBinary(fileName, bytes);

      final url = _supabase.storage
          .from('attendance_photos')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      print('Error subiendo foto: $e');
      return null;
    }
  }

  Future<String?> uploadProfilePhoto(Uint8List bytes, String userId) async {
    try {
      final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from('attendance_photos')
          .uploadBinary(fileName, bytes);

      final url = _supabase.storage
          .from('attendance_photos')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      print('Error subiendo foto de perfil: $e');
      return null;
    }
  }
  

  Future<bool> updateUserProfile({
  required String userId,
  required String fullName,
  required String phone,
  required String address,
  String? photoUrl,
}) async {
  try {
    final data = <String, dynamic>{
      'name': fullName,
      'full_name': fullName,
      'phone': phone,
      'address': address,
    };
    if (photoUrl != null && photoUrl.isNotEmpty) {
      data['photo_url'] = photoUrl;
    }

    print('🔵 Actualizando usuario $userId con: $data');

    final response = await _supabase
        .from('users')
        .update(data)
        .eq('id', userId)
        .select();

    print('✅ Update response: $response');
    return response.isNotEmpty;
  } catch (e) {
    print('❌ Error actualizando perfil: $e');
    return false;
  }
}

  Future<bool> checkOut(String userId, String shiftId, {String? notes}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final today = _getTodayString();

      final existing = await _supabase
          .from('attendances')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .eq('shift_id', shiftId)
          .not('check_in', 'is', null)
          .filter('check_out', 'is', null)
          .maybeSingle();

      if (existing == null) {
        _error = 'No tienes un turno activo para finalizar';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final attendanceId = existing['id'] as String;
      final checkInUtc = DateTime.parse(existing['check_in']).toUtc();
      final checkOutUtc = DateTime.now().toUtc();
      final workedMinutes = checkOutUtc.difference(checkInUtc).inMinutes;
      final checkOutStr = DateTime.now().toUtc().toIso8601String();

      // Consultar turno asignado para verificar hora de fin
      Map<String, dynamic>? shift;
      try {
        shift = await _supabase
            .from('shifts')
            .select()
            .eq('id', shiftId)
            .maybeSingle();
      } catch (e) {
        print('Error buscando turno en checkOut: $e');
      }

      int earlyLeaveMinutes = 0;
      if (shift != null && shift['end_time'] != null) {
        final dateStr = existing['date'] as String? ?? today;
        final dateParts = dateStr.split('-');
        final shiftYear = int.parse(dateParts[0]);
        final shiftMonth = int.parse(dateParts[1]);
        final shiftDay = int.parse(dateParts[2]);

        final endParts = (shift['end_time'] as String).split(':');
        final endHour = int.parse(endParts[0]);
        final endMinute = int.parse(endParts[1]);

        // Los turnos en Supabase están en hora local de Bolivia (UTC-4).
        // Convertimos a UTC sumando 4 horas para una comparación exacta independiente de la zona horaria del dispositivo.
        DateTime shiftEndUtc = DateTime.utc(
          shiftYear,
          shiftMonth,
          shiftDay,
          endHour,
          endMinute,
        ).add(const Duration(hours: 4));

        // Si el turno cruza la medianoche (ej. 22:00 a 06:00), shiftEnd es al día siguiente
        if (shift['start_time'] != null) {
          final startParts = (shift['start_time'] as String).split(':');
          final startHour = int.parse(startParts[0]);
          final startMinute = int.parse(startParts[1]);
          final shiftStartUtc = DateTime.utc(
            shiftYear,
            shiftMonth,
            shiftDay,
            startHour,
            startMinute,
          ).add(const Duration(hours: 4));

          if (shiftEndUtc.isBefore(shiftStartUtc)) {
            shiftEndUtc = shiftEndUtc.add(const Duration(days: 1));
          }
        }

        // Reglas 7 y 8: Salida anticipada comparando en UTC truncado a minutos
        final checkOutMinuteUtc = DateTime.utc(
          checkOutUtc.year,
          checkOutUtc.month,
          checkOutUtc.day,
          checkOutUtc.hour,
          checkOutUtc.minute,
        );

        if (checkOutMinuteUtc.isBefore(shiftEndUtc)) {
          earlyLeaveMinutes = shiftEndUtc.difference(checkOutMinuteUtc).inMinutes;
        } else {
          earlyLeaveMinutes = 0;
        }
      }

      final Map<String, dynamic> updateData = {
        'check_out': checkOutStr,
        'worked_minutes': workedMinutes,
        'early_leave_minutes': earlyLeaveMinutes,
      };

      if (notes != null && notes.trim().isNotEmpty) {
        final existingNotes = existing['notes'] as String?;
        if (existingNotes != null && existingNotes.trim().isNotEmpty) {
          updateData['notes'] = '$existingNotes | Salida: ${notes.trim()}';
        } else {
          updateData['notes'] = 'Salida: ${notes.trim()}';
        }
      }

      final updateResponse = await _supabase
          .from('attendances')
          .update(updateData)
          .eq('id', attendanceId)
          .select();

      if (updateResponse.isEmpty) {
        _error = 'No se pudo actualizar';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _lastEarlyLeaveMinutes = earlyLeaveMinutes;

      await fetchAttendances(userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error en checkOut: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Duration getWorkedHours() {
    if (_todayAttendance == null || _todayAttendance!.checkIn == null) {
      return Duration.zero;
    }

    final checkIn = _todayAttendance!.checkIn!;
    DateTime checkOut;
    if (_todayAttendance!.checkOut != null) {
      checkOut = _todayAttendance!.checkOut!;
    } else {
      checkOut = DateTime.now();
    }

    final diff = checkOut.difference(checkIn);
    if (diff.isNegative) return Duration.zero;

    return diff;
  }

  String getEmployeeStatus() {
    if (_todayAttendance == null) return 'Sin registro';
    if (_todayAttendance!.checkOut != null) return 'Turno completado';
    if (_todayAttendance!.checkIn == null) return 'Sin registro';

    switch (_todayAttendance!.status) {
      case 'early':
        return 'Temprano';
      case 'on_time':
        return 'En horario';
      case 'late':
        return 'Tarde';
      case 'very_late':
        return 'Muy tarde';
      case 'absent':
        return 'Ausente';
      default:
        return 'En turno';
    }
  }

  Future<void> fetchAllEmployees() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);

      _allEmployees = response.map((data) => UserModel.fromMap(data)).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Error al cargar empleados: $e';
      notifyListeners();
    }
  }

  Future<bool> addEmployee(UserModel employee) async {
    try {
      final tempPassword = 'Temp123!';
      final authResponse = await _supabase.auth.signUp(
        email: employee.email,
        password: tempPassword,
      );

      if (authResponse.user == null) {
        throw Exception('No se pudo crear el usuario');
      }

      await _supabase.from('users').insert({
        'id': authResponse.user!.id,
        'email': employee.email,
        'name': employee.fullName,
        'full_name': employee.fullName,
        'role': employee.role,
        'department': employee.department,
        'phone': employee.phone,
        'is_active': employee.isActive,
      });

      await fetchAllEmployees();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al agregar empleado: $e';
      notifyListeners();
      return false;
    }
  }

  int get totalEmployeesCount => _allEmployees.length;
  int get activeEmployeesCount => _allEmployees.where((e) => e.isActive).length;
  int get inactiveEmployeesCount => _allEmployees.where((e) => !e.isActive).length;
  int get adminCount => _allEmployees.where((e) => e.isAdmin).length;

  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> get shifts => _shifts;
  bool _isShiftsLoading = false;
  bool get isShiftsLoading => _isShiftsLoading;

  Future<void> fetchShifts() async {
    _isShiftsLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('shifts')
          .select()
          .order('start_time', ascending: true);

      _shifts = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = 'Error al cargar turnos: $e';
    }

    _isShiftsLoading = false;
    notifyListeners();
  }

  Future<bool> createShift({
    required String name,
    required String startTime,
    required String endTime,
    required List<String> days,
    int toleranceMinutes = 10,
  }) async {
    try {
      await _supabase.from('shifts').insert({
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'days': days,
        'late_fee_per_minute': 1.00,
        'tolerance_minutes': toleranceMinutes,
      });

      await fetchShifts();
      return true;
    } catch (e) {
      _error = 'Error al crear turno: $e';
      return false;
    }
  }

  Future<bool> updateShift({
    required String shiftId,
    required String name,
    required String startTime,
    required String endTime,
    required List<String> days,
    int toleranceMinutes = 10,
  }) async {
    try {
      await _supabase.from('shifts').update({
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'days': days,
        'tolerance_minutes': toleranceMinutes,
      }).eq('id', shiftId);

      await fetchShifts();
      return true;
    } catch (e) {
      _error = 'Error al actualizar turno: $e';
      return false;
    }
  }

  Future<bool> deleteShift(String shiftId) async {
    try {
      await _supabase.from('shifts').delete().eq('id', shiftId);
      await fetchShifts();
      return true;
    } catch (e) {
      _error = 'Error al eliminar turno: $e';
      return false;
    }
  }

  List<Map<String, dynamic>> _assignmentChangeLogs = [];
  List<Map<String, dynamic>> get assignmentChangeLogs => _assignmentChangeLogs;
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  Future<void> fetchAssignmentHistory() async {
    _isLoadingHistory = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('assignment_change_log')
          .select()
          .order('changed_at', ascending: false)
          .limit(20);

      final logs = List<Map<String, dynamic>>.from(response);

      for (var i = 0; i < logs.length; i++) {
        final targetUserId = logs[i]['user_id'];
        final changedById = logs[i]['changed_by'];

        if (targetUserId != null) {
          try {
            final userResp = await _supabase
                .from('users')
                .select('name, full_name, email')
                .eq('id', targetUserId)
                .maybeSingle();
            logs[i]['user_name'] = userResp?['full_name'] ?? userResp?['name'] ?? 'Empleado';
            logs[i]['user_email'] = userResp?['email'] ?? '';
          } catch (_) {
            logs[i]['user_name'] = 'Empleado';
          }
        }

        if (changedById != null) {
          try {
            final adminResp = await _supabase
                .from('users')
                .select('name, full_name, email')
                .eq('id', changedById)
                .maybeSingle();
            logs[i]['admin_name'] = adminResp?['full_name'] ?? adminResp?['name'] ?? 'Administrador';
            logs[i]['admin_email'] = adminResp?['email'] ?? '';
          } catch (_) {
            logs[i]['admin_name'] = 'Administrador';
          }
        }
      }

      _assignmentChangeLogs = logs;
    } catch (e) {
      print('Error al cargar historial de asignaciones: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<bool> assignShiftToEmployee({
    required String shiftId,
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    String? clientId,
    String? supervisorId,
  }) async {
    try {
      final dates = <String>[];
      DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (!current.isAfter(end)) {
        final dateStr = '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        dates.add(dateStr);
        current = current.add(const Duration(days: 1));
      }

      final adminId = _supabase.auth.currentUser?.id;

      for (final date in dates) {
        Map<String, dynamic>? existing;
        try {
          existing = await _supabase
              .from('shift_assignments')
              .select()
              .eq('user_id', userId)
              .eq('assigned_date', date)
              .maybeSingle();
        } catch (e) {
          print('Error consultando asignación previa: $e');
        }

        final isUpdate = existing != null;
        final changeType = isUpdate ? 'updated' : 'created';
        final oldValue = isUpdate
            ? 'shift_id: ${existing['shift_id']}, client_id: ${existing['client_id']}, supervisor_id: ${existing['supervisor_id']}'
            : null;
        final newValue = 'shift_id: $shiftId, client_id: $clientId, supervisor_id: $supervisorId';

        final upsertResult = await _supabase.from('shift_assignments').upsert({
          'shift_id': shiftId,
          'user_id': userId,
          'assigned_date': date,
          'client_id': clientId,
          'supervisor_id': supervisorId,
        }, onConflict: 'user_id,assigned_date').select();

        final assignmentId = upsertResult.isNotEmpty ? upsertResult.first['id'] : existing?['id'];

        try {
          await _supabase.from('assignment_change_log').insert({
            if (assignmentId != null) 'assignment_id': assignmentId,
            'user_id': userId,
            if (adminId != null) 'changed_by': adminId,
            'change_type': changeType,
            'old_value': oldValue,
            'new_value': newValue,
          });
        } catch (logErr) {
          print('Error registrando log de cambio: $logErr');
        }
      }

      await fetchAssignmentHistory();
      return true;
    } catch (e) {
      _error = 'Error al asignar turno: $e';
      return false;
    }
  }

  List<Map<String, dynamic>> _permissions = [];
  List<Map<String, dynamic>> get permissions => _permissions;
  bool _isPermissionsLoading = false;
  bool get isPermissionsLoading => _isPermissionsLoading;

  Future<void> fetchPermissions() async {
    _isPermissionsLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('permissions')
          .select()
          .order('created_at', ascending: false);

      _permissions = List<Map<String, dynamic>>.from(response);

      for (var i = 0; i < _permissions.length; i++) {
        final userId = _permissions[i]['user_id'];
        if (userId != null) {
          try {
            final userResponse = await _supabase
                .from('users')
                .select('name, email')
                .eq('id', userId)
                .maybeSingle();
            _permissions[i]['user_name'] = userResponse?['name'] ?? 'Empleado';
            _permissions[i]['user_email'] = userResponse?['email'] ?? '';
          } catch (e) {
            _permissions[i]['user_name'] = 'Empleado';
            _permissions[i]['user_email'] = '';
          }
        }
      }
    } catch (e) {
      _error = 'Error al cargar permisos: $e';
    }

    _isPermissionsLoading = false;
    notifyListeners();
  }

  Future<bool> createPermission({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      await _supabase.from('permissions').insert({
        'user_id': userId,
        'start_date': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
        'end_date': '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
        'reason': reason,
        'type': 'justified',
      });

      await fetchPermissions();
      return true;
    } catch (e) {
      _error = 'Error al crear permiso: $e';
      return false;
    }
  }

  Future<bool> deletePermission(String permissionId) async {
    try {
      await _supabase.from('permissions').delete().eq('id', permissionId);
      await fetchPermissions();
      return true;
    } catch (e) {
      _error = 'Error al eliminar permiso: $e';
      return false;
    }
  }

  Future<bool> hasPermissionOnDate(String userId, String date) async {
    try {
      final response = await _supabase
          .from('permissions')
          .select()
          .eq('user_id', userId)
          .lte('start_date', date)
          .gte('end_date', date);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // GESTION DE CLIENTES  // ============================================================
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> get clients => _clients;
  bool _isClientsLoading = false;
  bool get isClientsLoading => _isClientsLoading;

  Future<void> fetchClients() async {
    _isClientsLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('clients')
          .select()
          .order('name', ascending: true);

      _clients = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = 'Error al cargar clientes: $e';
    }

    _isClientsLoading = false;
    notifyListeners();
  }

  Future<bool> createClient({
    required String name,
    required String service,
    required String address,
    required double lat,
    required double lng,
    required int radius,
  }) async {
    try {
      await _supabase.from('clients').insert({
        'name': name,
        'service': service,
        'address': address,
        'location_lat': lat,
        'location_lng': lng,
        'radius_meters': radius,
        'is_active': true,
      });

      await fetchClients();
      return true;
    } catch (e) {
      _error = 'Error al crear cliente: $e';
      return false;
    }
  }

  Future<bool> updateClient({
    required String clientId,
    required String name,
    required String service,
    required String address,
    required double lat,
    required double lng,
    required int radius,
  }) async {
    try {
      await _supabase.from('clients').update({
        'name': name,
        'service': service,
        'address': address,
        'location_lat': lat,
        'location_lng': lng,
        'radius_meters': radius,
      }).eq('id', clientId);

      await fetchClients();
      return true;
    } catch (e) {
      _error = 'Error al actualizar cliente: $e';
      return false;
    }
  }

  Future<bool> deleteClient(String clientId) async {
    try {
      await _supabase.from('clients').delete().eq('id', clientId);
      await fetchClients();
      return true;
    } catch (e) {
      _error = 'Error al eliminar cliente: $e';
      return false;
    }
  }

  // ============================================================
  // GESTIÓN DE DÍAS LABORALES (CALENDARIO)
  // ============================================================
  List<Map<String, dynamic>> _workDays = [];
  List<Map<String, dynamic>> get workDays => _workDays;
  bool _isWorkDaysLoading = false;
  bool get isWorkDaysLoading => _isWorkDaysLoading;

  Future<void> fetchWorkDays([DateTime? month]) async {
    _isWorkDaysLoading = true;
    notifyListeners();

    try {
      final targetMonth = month ?? DateTime.now();
      final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
      final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
      final startStr = '${startOfMonth.year}-${startOfMonth.month.toString().padLeft(2, '0')}-01';
      final endStr = '${endOfMonth.year}-${endOfMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('work_days')
          .select()
          .gte('date', startStr)
          .lte('date', endStr)
          .order('date', ascending: true);

      _workDays = List<Map<String, dynamic>>.from(response);
      _error = null;
    } catch (e) {
      _error = 'Error al cargar días laborales: $e';
      print('Error en fetchWorkDays: $e');
    }

    _isWorkDaysLoading = false;
    notifyListeners();
  }

  Future<bool> setWorkDay(DateTime date, String type, String? description) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final existing = await _supabase
          .from('work_days')
          .select('id')
          .eq('date', dateStr)
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('work_days').update({
          'type': type,
          'description': description,
        }).eq('id', existing['id']);
      } else {
        await _supabase.from('work_days').insert({
          'date': dateStr,
          'type': type,
          'description': description,
        });
      }

      await fetchWorkDays(date);
      return true;
    } catch (e) {
      _error = 'Error al guardar día laboral: $e';
      print('Error en setWorkDay: $e');
      return false;
    }
  }

  Future<bool> deleteWorkDay(String workDayId, [DateTime? refreshMonth]) async {
    try {
      await _supabase.from('work_days').delete().eq('id', workDayId);
      await fetchWorkDays(refreshMonth);
      return true;
    } catch (e) {
      _error = 'Error al eliminar día laboral: $e';
      print('Error en deleteWorkDay: $e');
      return false;
    }
  }

  Map<String, dynamic>? getWorkDayForDate(DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    for (final wd in _workDays) {
      if (wd['date'] == dateStr) {
        return wd;
      }
    }
    return null;
  }

  // ============================================================
  // CONFIGURACIÓN DE OFICINA (APP SETTINGS)
  // ============================================================
  Future<void> fetchOfficeSettings() async {
    try {
      final response = await _supabase
          .from('app_settings')
          .select()
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _officeLat = (response['office_lat'] as num?)?.toDouble();
        _officeLng = (response['office_lng'] as num?)?.toDouble();
        _officeRadius = (response['office_radius'] as num?)?.toInt() ?? 500;
      }
    } catch (e) {
      print('Error en fetchOfficeSettings: $e');
    }
    notifyListeners();
  }

  Future<bool> updateOfficeSettings({
    required double lat,
    required double lng,
    required int radius,
  }) async {
    try {
      final existing = await _supabase
          .from('app_settings')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('app_settings').update({
          'office_lat': lat,
          'office_lng': lng,
          'office_radius': radius,
        }).eq('id', existing['id']);
      } else {
        await _supabase.from('app_settings').insert({
          'office_lat': lat,
          'office_lng': lng,
          'office_radius': radius,
        });
      }

      _officeLat = lat;
      _officeLng = lng;
      _officeRadius = radius;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar configuración de oficina: $e';
      return false;
    }
  }

  // ============================================================
  // RESUMEN MENSUAL Y REGLAS DE NEGOCIO (DESCUENTOS Y FALTAS)
  // ============================================================
  Future<Map<String, dynamic>> calculateMonthlySummary(
    String userId,
    int month,
    int year,
  ) async {
    try {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final targetMonthStart = DateTime(year, month, 1);

      // Si el mes es futuro, no se procesa resumen
      if (targetMonthStart.isAfter(currentMonthStart)) {
        return {};
      }

      final int lastDayOfMonth = DateTime(year, month + 1, 0).day;
      final int endDayToCheck = (year == now.year && month == now.month)
          ? now.day
          : lastDayOfMonth;

      final startStr = '$year-${month.toString().padLeft(2, '0')}-01';
      final endStr = '$year-${month.toString().padLeft(2, '0')}-${lastDayOfMonth.toString().padLeft(2, '0')}';

      // 1. Obtener todas las asistencias del mes para este usuario
      final attendancesResponse = await _supabase
          .from('attendances')
          .select()
          .eq('user_id', userId)
          .gte('date', startStr)
          .lte('date', endStr);

      final monthAttendances = (attendancesResponse as List)
          .map((data) => AttendanceModel.fromMap(data))
          .toList();

      // 2. Obtener configuración de días especiales en work_days
      final workDaysResponse = await _supabase
          .from('work_days')
          .select()
          .gte('date', startStr)
          .lte('date', endStr);

      final workDaysMap = <String, String>{};
      for (final wd in workDaysResponse) {
        final dStr = wd['date']?.toString();
        final type = wd['type']?.toString();
        if (dStr != null && type != null) {
          workDaysMap[dStr] = type;
        }
      }

      // 3. Obtener permisos vigentes del usuario en el mes
      final permissionsResponse = await _supabase
          .from('permissions')
          .select()
          .eq('user_id', userId)
          .lte('start_date', endStr)
          .gte('end_date', startStr);

      final permissionsList = List<Map<String, dynamic>>.from(permissionsResponse);

      // 4. Obtener fecha de creación del empleado en users
      final userResponse = await _supabase
          .from('users')
          .select('created_at')
          .eq('id', userId)
          .maybeSingle();

      DateTime? userCreatedAt;
      if (userResponse != null && userResponse['created_at'] != null) {
        userCreatedAt = DateTime.tryParse(userResponse['created_at'].toString())?.toLocal();
      }

      if (kDebugMode) {
        print('🔍 [calculateMonthlySummary] Iniciando cálculo para userId: $userId, mes: $month, año: $year');
        print('🔍 [calculateMonthlySummary] Rango de consulta: $startStr a $endStr (endDayToCheck: $endDayToCheck)');
      }

      // 5. Obtener turnos asignados al empleado en el mes desde shift_assignments
      final assignmentsResponse = await _supabase
          .from('shift_assignments')
          .select('assigned_date, shift_id')
          .eq('user_id', userId)
          .gte('assigned_date', startStr)
          .lte('assigned_date', endStr);

      final Set<String> assignedDates = {};
      for (final a in assignmentsResponse) {
        String? aDate = a['assigned_date']?.toString();
        if (aDate != null && a['shift_id'] != null) {
          if (aDate.length >= 10) {
            aDate = aDate.substring(0, 10);
          }
          assignedDates.add(aDate);
        }
      }

      if (kDebugMode) {
        print('🔍 [calculateMonthlySummary] Fechas con turno asignado (${assignedDates.length}): $assignedDates');
        print('🔍 [calculateMonthlySummary] Asistencias encontradas (${monthAttendances.length}): ${monthAttendances.map((a) => "${a.date} (checkIn: ${a.checkIn})").toList()}');
      }

      // 6. Recorrer días desde 1 hasta endDayToCheck para detectar faltas
      int totalAbsences = 0;
      final List<String> absenceDates = [];

      for (int d = 1; d <= endDayToCheck; d++) {
        final currentDay = DateTime(year, month, d);
        final dateStr = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

        // Regla 5: No contar días futuros si el mes es el actual
        if (year == now.year && month == now.month && d > now.day) {
          continue;
        }

        // Regla 6: No contar días anteriores a la fecha de creación del empleado
        if (userCreatedAt != null) {
          final userCreatedDate = DateTime(userCreatedAt.year, userCreatedAt.month, userCreatedAt.day);
          if (currentDay.isBefore(userCreatedDate)) {
            continue;
          }
        }

        // Reglas 1 y 2: Verificar si existe un turno asignado en shift_assignments
        final hasShiftAssigned = assignedDates.contains(dateStr);
        if (!hasShiftAssigned) {
          // Si NO hay turno asignado, NO se cuenta como falta
          continue;
        }

        // Regla 4: Si hay asistencia registrada con check_in, NO es falta
        final hasAttendance = monthAttendances.any(
          (a) {
            final aDate = a.date.length >= 10 ? a.date.substring(0, 10) : a.date;
            return aDate == dateStr && a.checkIn != null;
          },
        );
        if (hasAttendance) {
          continue;
        }

        // Regla 3: Si SÍ hay turno asignado y NO hay asistencia registrada:
        // 3.a. Verificar si es feriado o no laborable en work_days
        final workDayType = workDaysMap[dateStr];
        if (workDayType == 'holiday' || workDayType == 'non_working') {
          continue;
        }

        // 3.b. Verificar si hay un permiso vigente
        bool hasPermission = false;
        for (final perm in permissionsList) {
          final pStart = perm['start_date']?.toString();
          final pEnd = perm['end_date']?.toString();
          if (pStart != null && pEnd != null) {
            if (dateStr.compareTo(pStart) >= 0 && dateStr.compareTo(pEnd) <= 0) {
              hasPermission = true;
              break;
            }
          }
        }

        if (hasPermission) {
          continue;
        }

        // 3.c. Si nada de lo anterior aplica, cuenta como falta (suma Bs 200)
        absenceDates.add(dateStr);
        totalAbsences++;
      }

      if (kDebugMode) {
        print('🔴 [calculateMonthlySummary] Fechas contadas como FALTA (${absenceDates.length}): $absenceDates');
      }

      // 5. Sumar minutos de tolerancia usados, tardanzas, salidas anticipadas y multas
      int totalToleranceMinutes = 0;
      int totalLateMinutes = 0;
      double totalLateFee = 0.0;
      int totalEarlyLeaveMinutes = 0;

      for (final att in monthAttendances) {
        totalToleranceMinutes += att.toleranceMinutesUsed;
        totalLateMinutes += att.lateMinutes;
        totalLateFee += att.lateFee;
        totalEarlyLeaveMinutes += att.earlyLeaveMinutes;
      }

      // Regla: si total_tolerance_minutes >= 60, descuento adicional de Bs 100
      final double totalAccumulatedFee = totalToleranceMinutes >= 60 ? 100.0 : 0.0;

      // Descuento por faltas: Bs 200 por cada falta
      final double totalAbsenceFee = totalAbsences * 200.0;

      // Total acumulado general de todos los descuentos
      final double grandTotalFee = totalLateFee + totalAccumulatedFee + totalAbsenceFee;

      if (kDebugMode) {
        print('💰 [calculateMonthlySummary] Resultado: faltas=$totalAbsences (Bs $totalAbsenceFee), tardanzas=Bs $totalLateFee, penalidad=Bs $totalAccumulatedFee, granTotal=Bs $grandTotalFee');
      }

      final summaryData = <String, dynamic>{
        'user_id': userId,
        'month': month,
        'year': year,
        'total_tolerance_minutes': totalToleranceMinutes,
        'total_late_minutes': totalLateMinutes,
        'total_late_fee': totalLateFee,
        'total_accumulated_fee': totalAccumulatedFee,
        'total_absences': totalAbsences,
        'total_absence_fee': totalAbsenceFee,
        'total_early_leave_minutes': totalEarlyLeaveMinutes,
        'grand_total_fee': grandTotalFee,
      };

      // Guardar o actualizar en monthly_summary con upsert (onConflict: user_id,month,year)
      try {
        final upsertRes = await _supabase
            .from('monthly_summary')
            .upsert(summaryData, onConflict: 'user_id,month,year')
            .select();
        if (kDebugMode) {
          print('✅ [calculateMonthlySummary] Upsert en monthly_summary exitoso: $upsertRes');
        }
      } catch (upsertError) {
        if (kDebugMode) {
          print('❌ [calculateMonthlySummary] Error en upsert a monthly_summary: $upsertError');
        }
      }

      return summaryData;
    } catch (e) {
      if (kDebugMode) {
        print('Error en calculateMonthlySummary: $e');
      }
      _error = 'Error al calcular resumen mensual: $e';
      return {};
    }
  }

  Future<int> countAbsences(String userId, int month, int year) async {
    try {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final targetMonthStart = DateTime(year, month, 1);

      // Si el mes consultado es futuro, no hay faltas pasadas
      if (targetMonthStart.isAfter(currentMonthStart)) {
        return 0;
      }

      final int lastDayOfMonth = DateTime(year, month + 1, 0).day;
      final startStr = '$year-${month.toString().padLeft(2, '0')}-01';
      final endStr = '$year-${month.toString().padLeft(2, '0')}-${lastDayOfMonth.toString().padLeft(2, '0')}';

      // 1. Obtener turnos asignados al empleado en el mes desde shift_assignments
      final assignmentsResponse = await _supabase
          .from('shift_assignments')
          .select('assigned_date, shift_id')
          .eq('user_id', userId)
          .gte('assigned_date', startStr)
          .lte('assigned_date', endStr);

      final assignmentsList = List<Map<String, dynamic>>.from(assignmentsResponse);
      if (assignmentsList.isEmpty) {
        if (year == now.year && month == now.month) {
          _currentMonthAbsences = 0;
          notifyListeners();
        }
        return 0;
      }

      // Mapear fechas con turnos asignados e IDs de turnos
      final Map<String, List<dynamic>> assignedDatesMap = {};
      final Set<dynamic> shiftIds = {};
      for (final a in assignmentsList) {
        String? aDate = a['assigned_date']?.toString();
        final sId = a['shift_id'];
        if (aDate != null && sId != null) {
          if (aDate.length >= 10) {
            aDate = aDate.substring(0, 10);
          }
          assignedDatesMap.putIfAbsent(aDate, () => []).add(sId);
          shiftIds.add(sId);
        }
      }

      if (assignedDatesMap.isEmpty) {
        if (year == now.year && month == now.month) {
          _currentMonthAbsences = 0;
          notifyListeners();
        }
        return 0;
      }

      // 2. Obtener asistencias registradas del empleado en el mes
      final attendancesResponse = await _supabase
          .from('attendances')
          .select('date, check_in, shift_id')
          .eq('user_id', userId)
          .gte('date', startStr)
          .lte('date', endStr);

      final attendancesList = List<Map<String, dynamic>>.from(attendancesResponse);

      // 3. Obtener días feriados o no laborables del mes desde work_days
      final workDaysResponse = await _supabase
          .from('work_days')
          .select('date, type')
          .gte('date', startStr)
          .lte('date', endStr);

      final Set<String> nonWorkingDays = {};
      for (final wd in workDaysResponse) {
        final dStr = wd['date']?.toString();
        final type = wd['type']?.toString();
        if (dStr != null && (type == 'holiday' || type == 'non_working')) {
          final key = dStr.length >= 10 ? dStr.substring(0, 10) : dStr;
          nonWorkingDays.add(key);
        }
      }

      // 4. Obtener permisos vigentes del empleado en el mes
      final permissionsResponse = await _supabase
          .from('permissions')
          .select('start_date, end_date')
          .eq('user_id', userId)
          .lte('start_date', endStr)
          .gte('end_date', startStr);

      final permissionsList = List<Map<String, dynamic>>.from(permissionsResponse);

      // 5. Obtener fecha de creación del empleado para evitar faltas previas a su contratación
      final userResponse = await _supabase
          .from('users')
          .select('created_at')
          .eq('id', userId)
          .maybeSingle();

      DateTime? userCreatedAt;
      if (userResponse != null && userResponse['created_at'] != null) {
        userCreatedAt = DateTime.tryParse(userResponse['created_at'].toString())?.toLocal();
      }

      // 6. Consultar horarios de turnos para evaluar si el turno de hoy ya terminó
      final Map<dynamic, String?> shiftEndTimes = {};
      if (shiftIds.isNotEmpty) {
        try {
          final shiftsRes = await _supabase
              .from('shifts')
              .select('id, end_time')
              .inFilter('id', shiftIds.toList());
          for (final s in shiftsRes) {
            shiftEndTimes[s['id']] = s['end_time']?.toString();
          }
        } catch (_) {}
      }

      // 7. Iterar días del mes hasta hoy (o fin de mes si es mes anterior)
      int totalAbsences = 0;
      final int endDayToCheck = (year == now.year && month == now.month)
          ? now.day
          : lastDayOfMonth;

      for (int d = 1; d <= endDayToCheck; d++) {
        final currentDay = DateTime(year, month, d);
        final dateStr = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

        // Omitir días previos a la creación del usuario
        if (userCreatedAt != null) {
          final userCreatedDate = DateTime(userCreatedAt.year, userCreatedAt.month, userCreatedAt.day);
          if (currentDay.isBefore(userCreatedDate)) {
            continue;
          }
        }

        // Si no tiene turno asignado en esta fecha, omitir
        if (!assignedDatesMap.containsKey(dateStr)) {
          continue;
        }

        // Si es el día de hoy, verificar si el turno ya terminó
        if (year == now.year && month == now.month && d == now.day) {
          final shiftsForToday = assignedDatesMap[dateStr] ?? [];
          bool anyShiftEnded = false;
          for (final sId in shiftsForToday) {
            final endTimeStr = shiftEndTimes[sId];
            if (endTimeStr != null) {
              final parts = endTimeStr.split(':');
              if (parts.length >= 2) {
                final endHour = int.tryParse(parts[0]) ?? 0;
                final endMinute = int.tryParse(parts[1]) ?? 0;
                if (now.hour > endHour || (now.hour == endHour && now.minute >= endMinute)) {
                  anyShiftEnded = true;
                  break;
                }
              }
            }
          }
          // Si el turno de hoy aún no ha concluido, no se cuenta como falta todavía
          if (!anyShiftEnded) {
            continue;
          }
        }

        // Si tiene asistencia registrada con check_in, NO es falta
        final hasCheckIn = attendancesList.any((att) {
          final attDate = att['date']?.toString();
          final normDate = (attDate != null && attDate.length >= 10) ? attDate.substring(0, 10) : attDate;
          return normDate == dateStr && att['check_in'] != null;
        });
        if (hasCheckIn) {
          continue;
        }

        // Si es feriado o día no laborable en work_days, NO es falta
        if (nonWorkingDays.contains(dateStr)) {
          continue;
        }

        // Si tiene permiso vigente en esa fecha, NO es falta
        bool hasPermission = false;
        for (final perm in permissionsList) {
          final pStart = perm['start_date']?.toString();
          final pEnd = perm['end_date']?.toString();
          if (pStart != null && pEnd != null) {
            final startNorm = pStart.length >= 10 ? pStart.substring(0, 10) : pStart;
            final endNorm = pEnd.length >= 10 ? pEnd.substring(0, 10) : pEnd;
            if (dateStr.compareTo(startNorm) >= 0 && dateStr.compareTo(endNorm) <= 0) {
              hasPermission = true;
              break;
            }
          }
        }
        if (hasPermission) {
          continue;
        }

        // Cumple todas las condiciones: tiene turno asignado, sin asistencia, sin feriado ni permiso -> FALTA
        totalAbsences++;
      }

      if (year == now.year && month == now.month) {
        _currentMonthAbsences = totalAbsences;
        notifyListeners();
      }

      return totalAbsences;
    } catch (e) {
      if (kDebugMode) {
        print('Error en countAbsences: $e');
      }
      return 0;
    }
  }
}