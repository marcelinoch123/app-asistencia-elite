import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Datos del último check-in para mostrar en UI
  int _lastLateMinutes = 0;
  String? _lastShiftStart;
  String? _lastCheckInTime;

  // ============================================================
  // GETTERS
  // ============================================================
  List<AttendanceModel> get attendances => _attendances;
  List<UserModel> get allEmployees => _allEmployees;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AttendanceModel? get todayAttendance => _todayAttendance;

  int get lastLateMinutes => _lastLateMinutes;
  String? get lastShiftStart => _lastShiftStart;
  String? get lastCheckInTime => _lastCheckInTime;

  // ============================================================
  // HELPER: FECHA DE HOY EN FORMATO YYYY-MM-DD
  // ============================================================
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CARGAR ASISTENCIAS DE UN USUARIO
  // ============================================================
  Future<void> fetchAttendances(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('attendances')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _attendances =
          response.map((data) => AttendanceModel.fromMap(data)).toList();

      // ✅ FECHA DE HOY EN HORA LOCAL
      final today = _getTodayString();
      print('🔵 fetchAttendances - Buscando registros de hoy: $today');

      // ✅ BUSCAR SOLO EL TURNO DE HOY
      AttendanceModel? todayAttendance;
      for (final att in _attendances) {
        if (att.date == today) {
          todayAttendance = att;
          break;
        }
      }

      if (todayAttendance != null) {
        _todayAttendance = todayAttendance;
        print('✅ Turno de hoy encontrado: ${todayAttendance.id}');
        print('   checkIn: ${todayAttendance.checkIn}');
        print('   checkOut: ${todayAttendance.checkOut}');
        print('   lateMinutes: ${todayAttendance.lateMinutes}');
      } else {
        _todayAttendance = _emptyAttendance(userId, today);
        print('ℹ️ No hay turno registrado hoy. Mostrando botón INICIAR.');
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      print('❌ Error en fetchAttendances: $e');
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

  // ============================================================
  // REGISTRAR ENTRADA
  // ============================================================
  Future<bool> checkIn(String userId, dynamic photo) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final today = _getTodayString();

      print('🔵 checkIn() - Fecha de hoy: $today');

      // ✅ VERIFICAR SOLO SI YA MARCÓ HOY
      final existing = await _supabase
          .from('attendances')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      if (existing != null && existing['check_in'] != null) {
        _error = 'Ya registraste tu entrada hoy';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // ============================================================
      // BUSCAR TURNO ASIGNADO
      // ============================================================
      Map<String, dynamic>? shift;
      try {
        final assignmentResponse = await _supabase
            .from('shift_assignments')
            .select('shift_id, shifts(*)')
            .eq('user_id', userId)
            .order('assigned_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (assignmentResponse != null &&
            assignmentResponse['shifts'] != null) {
          final shiftData =
              assignmentResponse['shifts'] as Map<String, dynamic>;
          shift = shiftData;
          print(
              '✅ Turno encontrado: ${shiftData['name']} (inicio: ${shiftData['start_time']})');
        } else {
          print('⚠️ No hay turno asignado');
        }
      } catch (e) {
        print('⚠️ Error buscando turno: $e');
      }

      // ============================================================
      // CALCULAR RETRASO
      // ============================================================
      int lateMinutes = 0;
      String? shiftStartStr;

      if (shift != null) {
        shiftStartStr = shift['start_time'] as String;
        final tolerance = (shift['tolerance_minutes'] as int?) ?? 5;

        final parts = shiftStartStr.split(':');
        final shiftStart = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        final diffMinutes = now.difference(shiftStart).inMinutes;
        print(
            '⏰ Hora actual: ${now.hour}:${now.minute} | Turno inicia: $shiftStartStr | Diferencia: $diffMinutes min | Tolerancia: $tolerance min');

        if (diffMinutes > tolerance) {
          lateMinutes = diffMinutes - tolerance;
          print('⚠️ Retraso calculado: $lateMinutes minutos');
        }
      }

      // Determinar estado
      String status;
      if (lateMinutes == 0) {
        status = 'on_time';
      } else if (lateMinutes <= 15) {
        status = 'late';
      } else {
        status = 'very_late';
      }

      // ============================================================
      // GUARDAR CON UTC Y SHIFT_ID
      // ============================================================
      final response = await _supabase.from('attendances').insert({
        'user_id': userId,
        'date': today,
        'check_in': DateTime.now().toUtc().toIso8601String(),
        'status': status,
        'shift_id': shift?['id'],
        'late_minutes': lateMinutes,
        'late_fee': 0.0,
        'worked_minutes': 0,
        'location_lat': null,
        'location_lng': null,
      }).select();

      if (response.isNotEmpty) {
        _lastLateMinutes = lateMinutes;
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
      print('❌ Error en checkIn: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // REGISTRAR SALIDA
  // ============================================================
  Future<bool> checkOut(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final today = _getTodayString();

      print('🔵 checkOut() - Buscando turno de hoy: $today');

      // ✅ BUSCAR SOLO EL TURNO DE HOY
      final existing = await _supabase
          .from('attendances')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .not('check_in', 'is', null)
          .filter('check_out', 'is', null)
          .maybeSingle();

      print('🔵 checkOut() - existing: $existing');

      if (existing == null) {
        _error = 'No tienes un turno activo para finalizar';
        print('❌ checkOut() - No hay turno activo de hoy');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final attendanceId = existing['id'] as String;
      print('🔵 checkOut() - ID a actualizar: $attendanceId');

      // Calcular minutos trabajados
      final checkInUtc = DateTime.parse(existing['check_in']).toUtc();
      final checkOutUtc = DateTime.now().toUtc();
      final workedMinutes = checkOutUtc.difference(checkInUtc).inMinutes;
      final checkOutStr = DateTime.now().toUtc().toIso8601String();

      print('🔵 checkOut() - check_out: $checkOutStr');
      print('🔵 checkOut() - worked_minutes: $workedMinutes');

      // ✅ ACTUALIZAR
      final updateResponse = await _supabase
          .from('attendances')
          .update({
            'check_out': checkOutStr,
            'worked_minutes': workedMinutes,
          })
          .eq('id', attendanceId)
          .select();

      print('🔵 checkOut() - Filas actualizadas: ${updateResponse.length}');

      if (updateResponse.isEmpty) {
        _error = 'No se pudo actualizar. Verifica los permisos.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      print('✅ checkOut() - Check-out guardado correctamente');

      await fetchAttendances(userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('❌ checkOut() - Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // CALCULAR HORAS TRABAJADAS HOY (CRONÓMETRO)
  // ============================================================
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

  // ============================================================
  // OBTENER ESTADO DEL EMPLEADO
  // ============================================================
  String getEmployeeStatus() {
    if (_todayAttendance == null) return 'Sin registro';

    if (_todayAttendance!.checkOut != null) {
      return 'Turno completado';
    }

    if (_todayAttendance!.checkIn == null) {
      return 'Sin registro';
    }

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

  // ============================================================
  // HELPERS
  // ============================================================
  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // MÉTODOS DE ADMIN
  // ============================================================
  Future<void> fetchAllEmployees() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);

      _allEmployees =
          response.map((data) => UserModel.fromMap(data)).toList();
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

  // ============================================================
  // CONTADORES PARA DASHBOARD ADMIN
  // ============================================================
  int get totalEmployeesCount => _allEmployees.length;
  int get activeEmployeesCount => _allEmployees.where((e) => e.isActive).length;
  int get inactiveEmployeesCount =>
      _allEmployees.where((e) => !e.isActive).length;
  int get adminCount => _allEmployees.where((e) => e.isAdmin).length;

    // ============================================================
  // GESTIÓN DE TURNOS (ADMIN)
  // ============================================================

  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> get shifts => _shifts;

  bool _isShiftsLoading = false;
  bool get isShiftsLoading => _isShiftsLoading;

  // ✅ OBTENER TODOS LOS TURNOS
  Future<void> fetchShifts() async {
    _isShiftsLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('shifts')
          .select()
          .order('start_time', ascending: true);

      _shifts = List<Map<String, dynamic>>.from(response);
      print('✅ ${_shifts.length} turnos cargados');
    } catch (e) {
      _error = 'Error al cargar turnos: $e';
      print('❌ Error en fetchShifts: $e');
    }

    _isShiftsLoading = false;
    notifyListeners();
  }

  // ✅ CREAR TURNO
  Future<bool> createShift({
    required String name,
    required String startTime,
    required String endTime,
    int toleranceMinutes = 5,
  }) async {
    try {
      await _supabase.from('shifts').insert({
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'late_fee_per_minute': 1.00,
        'tolerance_minutes': toleranceMinutes,
      });

      await fetchShifts();
      print('✅ Turno creado: $name');
      return true;
    } catch (e) {
      _error = 'Error al crear turno: $e';
      print('❌ Error en createShift: $e');
      return false;
    }
  }

  // ✅ ACTUALIZAR TURNO
  Future<bool> updateShift({
    required String shiftId,
    required String name,
    required String startTime,
    required String endTime,
    int toleranceMinutes = 5,
  }) async {
    try {
      await _supabase.from('shifts').update({
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'tolerance_minutes': toleranceMinutes,
      }).eq('id', shiftId);

      await fetchShifts();
      print('✅ Turno actualizado: $name');
      return true;
    } catch (e) {
      _error = 'Error al actualizar turno: $e';
      print('❌ Error en updateShift: $e');
      return false;
    }
  }

  // ✅ ELIMINAR TURNO
  Future<bool> deleteShift(String shiftId) async {
    try {
      await _supabase.from('shifts').delete().eq('id', shiftId);
      await fetchShifts();
      print('✅ Turno eliminado');
      return true;
    } catch (e) {
      _error = 'Error al eliminar turno: $e';
      print('❌ Error en deleteShift: $e');
      return false;
    }
  }

  // ✅ ASIGNAR TURNO A EMPLEADO EN RANGO DE FECHAS
  Future<bool> assignShiftToEmployee({
    required String shiftId,
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Crear lista de fechas entre startDate y endDate
      final dates = <String>[];
      DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (!current.isAfter(end)) {
        final dateStr =
            '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        dates.add(dateStr);
        current = current.add(const Duration(days: 1));
      }

      // Insertar cada fecha
      for (final date in dates) {
        await _supabase.from('shift_assignments').upsert({
          'shift_id': shiftId,
          'user_id': userId,
          'assigned_date': date,
        }, onConflict: 'user_id,assigned_date');
      }

      print('✅ Turno asignado a $userId en ${dates.length} días');
      return true;
    } catch (e) {
      _error = 'Error al asignar turno: $e';
      print('❌ Error en assignShiftToEmployee: $e');
      return false;
    }
  }

  // ✅ OBTENER ASIGNACIONES DE UN EMPLEADO
  Future<List<Map<String, dynamic>>> getEmployeeAssignments(
      String userId) async {
    try {
      final response = await _supabase
          .from('shift_assignments')
          .select('*, shifts(*)')
          .eq('user_id', userId)
          .order('assigned_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error en getEmployeeAssignments: $e');
      return [];
    }
  }

  // ✅ ELIMINAR ASIGNACIÓN
  Future<bool> deleteAssignment(String assignmentId) async {
    try {
      await _supabase.from('shift_assignments').delete().eq('id', assignmentId);
      return true;
    } catch (e) {
      print('❌ Error en deleteAssignment: $e');
      return false;
    }
  }
}