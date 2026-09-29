import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/attendance_model.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/bottom_nav.dart';

class DashboardEmployee extends StatefulWidget {
  const DashboardEmployee({super.key});

  @override
  State<DashboardEmployee> createState() => _DashboardEmployeeState();
}

class _DashboardEmployeeState extends State<DashboardEmployee> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isProcessing = false;
  Timer? _timer;
  Timer? _locationTimer;
  Duration _workedHours = Duration.zero;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<String, List<Map<String, dynamic>>> _monthAssignments = {};
  Map<String, bool> _inRangeMap = {};
  bool _isInOffice = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final attendanceProvider = context.read<AttendanceProvider>();
      final hours = attendanceProvider.getWorkedHours();
      setState(() => _workedHours = hours);
    });
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    if (authProvider.user != null) {
      final userId = authProvider.user!.id;
      await authProvider.fetchUserData(userId);
      await attendanceProvider.autoCheckOutExpiredShifts(userId: userId);
      await attendanceProvider.fetchAttendances(userId);
      await attendanceProvider.fetchOfficeSettings();

      // Cargar inmediatamente el día de hoy para que la tarjeta aparezca al instante
      final todayStr = _getDateString(DateTime.now());
      final todayResult = await attendanceProvider.getAssignmentsForDate(userId, todayStr);
      if (todayResult != null && todayResult['assignments'] != null && mounted) {
        setState(() {
          _monthAssignments[todayStr] = List<Map<String, dynamic>>.from(todayResult['assignments']);
        });
      }

      await _updateLocationAndCheckRange(userId);

      if (mounted) {
        setState(() {
          _workedHours = attendanceProvider.getWorkedHours();
        });
      }

      // Cargar en segundo plano el resto del mes en batch sin bloquear la UI
      _loadMonthAssignments(userId);
    }
  }

  Future<void> _updateLocationAndCheckRange(String userId) async {
    final authProvider = context.read<AuthProvider>();
    final locationProvider = context.read<LocationProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    final position = await locationProvider.getCurrentLocation();
    if (position == null) return;

    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
    }

    final today = _getDateString(DateTime.now());
    final result = await attendanceProvider.getAssignmentsForDate(userId, today);

    if (result == null) return;
    final assignments = List<Map<String, dynamic>>.from(result['assignments']);

    final Map<String, bool> rangeMap = {};
    final isOffice = authProvider.user?.isOffice == true;

    if (isOffice) {
      if (attendanceProvider.officeLat == null || attendanceProvider.officeLng == null) {
        await attendanceProvider.fetchOfficeSettings();
      }

      final officeLat = attendanceProvider.officeLat;
      final officeLng = attendanceProvider.officeLng;
      final officeRadius = attendanceProvider.officeRadius;

      bool inOfficeRange = false;
      if (officeLat == null || officeLng == null || (officeLat == 0.0 && officeLng == 0.0)) {
        // Sin coordenadas configuradas: permite marcar desde cualquier lugar
        inOfficeRange = true;
      } else {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          officeLat,
          officeLng,
        );
        inOfficeRange = distance <= officeRadius;
      }

      for (final a in assignments) {
        final shiftId = a['shift_id']?.toString();
        if (shiftId != null) {
          rangeMap[shiftId] = inOfficeRange;
        }
      }

      if (mounted) {
        setState(() {
          _inRangeMap = rangeMap;
          _isInOffice = inOfficeRange;
        });
      }
    } else {
      for (final a in assignments) {
        final client = a['client_data'] as Map<String, dynamic>?;
        final shiftId = a['shift_id'] as String?;
        if (shiftId == null) continue;

        if (client == null) {
          // Si no hay datos de cliente, permitir marcar desde cualquier lugar
          rangeMap[shiftId] = true;
          continue;
        }

        final clientLat = (client['location_lat'] as num?)?.toDouble();
        final clientLng = (client['location_lng'] as num?)?.toDouble();
        final radius = (client['radius_meters'] as int?) ?? 500;

        if (clientLat == null || clientLng == null || (clientLat == 0.0 && clientLng == 0.0)) {
          // Empresa sin coordenadas configuradas: permitir marcar desde cualquier lugar
          rangeMap[shiftId] = true;
          continue;
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          clientLat,
          clientLng,
        );

        rangeMap[shiftId] = distance <= radius;
      }

      if (mounted) {
        setState(() {
          _inRangeMap = rangeMap;
        });
      }
    }
  }

  Future<void> _loadMonthAssignments(String userId) async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final monthData = await attendanceProvider.fetchMonthAssignmentsBatch(userId, _focusedDay);

    if (!mounted) return;

    setState(() {
      // Smart Merge: proteger datos de hoy si ya tienen check_in en memoria
      final todayStr = _getDateString(DateTime.now());
      final currentTodayList = _monthAssignments[todayStr];

      if (currentTodayList != null && currentTodayList.isNotEmpty) {
        final batchTodayList = monthData[todayStr];
        if (batchTodayList != null) {
          for (int i = 0; i < batchTodayList.length; i++) {
            final batchItem = batchTodayList[i];
            final shiftId = batchItem['shift_id']?.toString();
            final currentItem = currentTodayList.firstWhere(
              (c) => c['shift_id']?.toString() == shiftId,
              orElse: () => <String, dynamic>{},
            );

            final curAtt = currentItem['attendance'];
            if (curAtt != null) {
              DateTime? curCheckIn;
              if (curAtt is AttendanceModel) {
                curCheckIn = curAtt.checkIn;
              } else if (curAtt is Map && curAtt['check_in'] != null) {
                curCheckIn = DateTime.tryParse(curAtt['check_in'].toString());
              }

              final batchAtt = batchItem['attendance'];
              DateTime? batchCheckIn;
              if (batchAtt is AttendanceModel) {
                batchCheckIn = batchAtt.checkIn;
              } else if (batchAtt is Map && batchAtt['check_in'] != null) {
                batchCheckIn = DateTime.tryParse(batchAtt['check_in'].toString());
              }

              if (curCheckIn != null && (batchCheckIn == null || curCheckIn.isAfter(batchCheckIn))) {
                batchItem['attendance'] = curAtt;
              }
            }
          }
        } else {
          monthData[todayStr] = currentTodayList;
        }
      }

      _monthAssignments = monthData;
    });
  }

  List<Map<String, dynamic>> _getAssignmentsForSelectedDay() {
    final dateStr = _getDateString(_selectedDay);
    return _monthAssignments[dateStr] ?? [];
  }

  String _getDateString(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  bool _isPastDay(DateTime day) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final dayMidnight = DateTime(day.year, day.month, day.day);
    return dayMidnight.isBefore(todayMidnight);
  }

  Future<Uint8List> _addWatermark(XFile photo) async {
    try {
      final bytes = await photo.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);

      img.fillRect(
        image,
        x1: 0,
        y1: image.height - 100,
        x2: image.width,
        y2: image.height,
        color: img.ColorRgba8(0, 0, 0, 180),
      );

      img.drawString(
        image,
        'Elite Multiservicios',
        font: img.arial24,
        x: 15,
        y: image.height - 90,
        color: img.ColorRgba8(255, 255, 255, 255),
      );

      img.drawString(
        image,
        '$dateStr  $timeStr',
        font: img.arial24,
        x: 15,
        y: image.height - 60,
        color: img.ColorRgba8(255, 255, 255, 255),
      );

      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      print('Error agregando marca de agua: $e');
      return await photo.readAsBytes();
    }
  }

  Future<void> _openCameraAndPreview(Map<String, dynamic> assignment) async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final locationProvider = context.read<LocationProvider>();

    if (authProvider.user == null) return;

    setState(() => _isProcessing = true);

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
        preferredCameraDevice: CameraDevice.front,
      );

      if (photo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes tomar una foto para marcar'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      final processedBytes = await _addWatermark(photo);

      if (!mounted) return;

      setState(() => _isProcessing = false);

      final TextEditingController notesController = TextEditingController();

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Vista previa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF001229),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      processedBytes,
                      height: 260,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Observaciones / Incidencias (opcional)',
                      hintText: 'Ej. Retraso justificado, imprevisto...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.edit_note, size: 20),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Registrar Asistencia'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2744),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (confirmed != true) return;

      setState(() => _isProcessing = true);

      final position = await locationProvider.getCurrentLocation();

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener tu ubicacion'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      final notesText = notesController.text.trim();
      final success = await attendanceProvider.checkIn(
        authProvider.user!.id,
        {
          'photoBytes': processedBytes,
          'lat': position.latitude,
          'lng': position.longitude,
        },
        assignment['shift_id'],
        notes: notesText.isEmpty ? null : notesText,
      );

      if (success && mounted) {
        final now = DateTime.now();
        final todayStr = _getDateString(now);
        final shiftId = assignment['shift_id']?.toString();

        final todayAssignments = _monthAssignments[todayStr];
        if (todayAssignments != null) {
          for (final a in todayAssignments) {
            if (a['shift_id']?.toString() == shiftId) {
              a['attendance'] = {
                'check_in': now.toUtc().toIso8601String(),
                'status': 'on_time',
                'shift_id': shiftId,
              };
            }
          }
        }
        assignment['attendance'] = {
          'check_in': now.toUtc().toIso8601String(),
          'status': 'on_time',
          'shift_id': shiftId,
        };

        if (mounted) {
          setState(() {
            _workedHours = attendanceProvider.getWorkedHours();
          });
        }

        final lateMin = attendanceProvider.lastLateMinutes;
        final lateFee = attendanceProvider.lastLateFee;
        final checkInTime = attendanceProvider.lastCheckInTime ?? '';

        String mensaje;
        Color color;

        if (lateMin > 0) {
          final horas = lateMin ~/ 60;
          final mins = lateMin % 60;
          String tiempoRetraso = '';
          if (horas > 0) tiempoRetraso += '${horas}h ';
          if (mins > 0 || horas == 0) tiempoRetraso += '${mins}min';

          mensaje = 'Turno iniciado a las $checkInTime. Retraso: $tiempoRetraso. Descuento: Bs ${lateFee.toStringAsFixed(2)}';
          color = Colors.orange;
        } else {
          mensaje = 'Turno iniciado a las $checkInTime';
          color = Colors.green;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: color,
            duration: const Duration(seconds: 5),
          ),
        );

        attendanceProvider.fetchAttendances(authProvider.user!.id).then((_) {
          if (mounted) {
            setState(() {
              _workedHours = attendanceProvider.getWorkedHours();
            });
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attendanceProvider.error ?? 'Error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _markOfficeEntry(Map<String, dynamic> assignment) async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final locationProvider = context.read<LocationProvider>();

    if (authProvider.user == null) return;

    final TextEditingController notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar Entrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Deseas marcar tu entrada de oficina ahora?'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Observaciones / Incidencias (opcional)',
                hintText: 'Ej. Ingreso autorizado, nota...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                prefixIcon: const Icon(Icons.edit_note, size: 20),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2744),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final position = await locationProvider.getCurrentLocation();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener tu ubicacion'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      final notesText = notesController.text.trim();
      final success = await attendanceProvider.checkIn(
        authProvider.user!.id,
        {
          'lat': position.latitude,
          'lng': position.longitude,
        },
        assignment['shift_id'],
        skipPhoto: true,
        isOffice: true,
        notes: notesText.isEmpty ? null : notesText,
      );

      if (success && mounted) {
        final now = DateTime.now();
        final todayStr = _getDateString(now);
        final shiftId = assignment['shift_id']?.toString();

        // 1. Actualización optimista inmediata en memoria
        final todayAssignments = _monthAssignments[todayStr];
        if (todayAssignments != null) {
          for (final a in todayAssignments) {
            if (a['shift_id']?.toString() == shiftId) {
              a['attendance'] = {
                'check_in': now.toUtc().toIso8601String(),
                'status': 'on_time',
                'shift_id': shiftId,
              };
            }
          }
        }
        assignment['attendance'] = {
          'check_in': now.toUtc().toIso8601String(),
          'status': 'on_time',
          'shift_id': shiftId,
        };

        // Redibujar UI de inmediato
        if (mounted) {
          setState(() {
            _workedHours = attendanceProvider.getWorkedHours();
          });
        }

        final lateMin = attendanceProvider.lastLateMinutes;
        final lateFee = attendanceProvider.lastLateFee;
        final checkInTime = attendanceProvider.lastCheckInTime ?? '';

        String mensaje;
        Color color;

        if (lateMin > 0) {
          final horas = lateMin ~/ 60;
          final mins = lateMin % 60;
          String tiempoRetraso = '';
          if (horas > 0) tiempoRetraso += '${horas}h ';
          if (mins > 0 || horas == 0) tiempoRetraso += '${mins}min';

          mensaje = 'Turno iniciado a las $checkInTime. Retraso: $tiempoRetraso. Descuento: Bs ${lateFee.toStringAsFixed(2)}';
          color = Colors.orange;
        } else {
          mensaje = 'Turno iniciado a las $checkInTime';
          color = Colors.green;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: color,
            duration: const Duration(seconds: 5),
          ),
        );

        // Actualizar datos en segundo plano sin sobrescribir el estado optimista inmediatamente
        attendanceProvider.fetchAttendances(authProvider.user!.id).then((_) {
          if (mounted) {
            setState(() {
              _workedHours = attendanceProvider.getWorkedHours();
            });
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attendanceProvider.error ?? 'Error al marcar entrada'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _markExit(Map<String, dynamic> assignment) async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    if (authProvider.user == null) return;
    final isOffice = authProvider.user!.isOffice;

    final shift = assignment['shift_data'] as Map<String, dynamic>?;
    final startTimeStr = shift?['start_time'];
    final endTimeStr = shift?['end_time'];

    // Para empleados de CAMPO: validación de horario mínimo de salida
    if (!isOffice && endTimeStr != null) {
      final shiftEnd = _getShiftEndTime(endTimeStr, startTimeStr, DateTime.now());
      if (shiftEnd != null) {
        final minBefore = attendanceProvider.minMinutesBeforeCheckout;
        final earliestExit = shiftEnd.subtract(Duration(minutes: minBefore));
        if (DateTime.now().isBefore(earliestExit)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Debes esperar hasta las ${_formatTime(earliestExit)} para finalizar'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }
    }

    Uint8List? processedBytes;

    if (!isOffice) {
      setState(() => _isProcessing = true);
      try {
        final picker = ImagePicker();
        final photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1200,
          maxHeight: 1200,
          preferredCameraDevice: CameraDevice.front,
        );

        if (photo == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Debes tomar una foto para finalizar'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isProcessing = false);
          return;
        }

        processedBytes = await _addWatermark(photo);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error capturando foto: $e'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }

    final TextEditingController notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Confirmar Salida',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (processedBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      processedBytes,
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  const Text('¿Estás seguro de registrar tu salida?'),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Observaciones / Incidencias (opcional)',
                    hintText: 'Ej. Salida normal, motivo...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    prefixIcon: const Icon(Icons.edit_note, size: 20),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Confirmar Salida'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final notesText = notesController.text.trim();
      final success = await attendanceProvider.checkOut(
        authProvider.user!.id,
        assignment['shift_id'],
        photo: processedBytes,
        isOffice: isOffice,
        notes: notesText.isEmpty ? null : notesText,
      );

      if (success && mounted) {
        final now = DateTime.now();
        final todayStr = _getDateString(now);
        final shiftId = assignment['shift_id']?.toString();

        final todayAssignments = _monthAssignments[todayStr];
        if (todayAssignments != null) {
          for (final a in todayAssignments) {
            if (a['shift_id']?.toString() == shiftId) {
              final att = a['attendance'];
              if (att is Map<String, dynamic>) {
                att['check_out'] = now.toUtc().toIso8601String();
              } else if (att is AttendanceModel) {
                final map = att.toMap();
                map['check_out'] = now.toUtc().toIso8601String();
                a['attendance'] = map;
              } else {
                a['attendance'] = {'check_out': now.toUtc().toIso8601String()};
              }
            }
          }
        }
        if (assignment['attendance'] is Map) {
          assignment['attendance']['check_out'] = now.toUtc().toIso8601String();
        } else {
          assignment['attendance'] = {'check_out': now.toUtc().toIso8601String()};
        }

        final earlyMin = attendanceProvider.lastEarlyLeaveMinutes;
        if (earlyMin > 0) {
          final horas = earlyMin ~/ 60;
          final mins = earlyMin % 60;
          String tiempoFaltante = '';
          if (horas > 0) tiempoFaltante += '${horas}h ';
          if (mins > 0 || horas == 0) tiempoFaltante += '${mins}min';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Salida registrada. Salida anticipada: faltaron $tiempoFaltante para completar la jornada.',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Salida registrada con éxito'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        await attendanceProvider.fetchAttendances(authProvider.user!.id);
        await _loadMonthAssignments(authProvider.user!.id);
        if (mounted) {
          setState(() {
            _workedHours = attendanceProvider.getWorkedHours();
          });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attendanceProvider.error ?? 'Error al registrar salida'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        break;
      case 2:
        Navigator.pushNamed(context, '/employee/history');
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos - Proximamente')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final user = authProvider.user;

    final assignments = _getAssignmentsForSelectedDay();
    final isToday = _isToday(_selectedDay);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FF),
      drawer: const CustomDrawer(isAdmin: false),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF0D1C2F)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Dashboard Empleado',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
        actions: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF0051D5),
            child: Text(
              user?.fullName.isNotEmpty == true
                  ? user!.fullName[0].toUpperCase()
                  : 'E',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        onTap: _onNavTap,
      ),
      body: attendanceProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mi Calendario',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF001229),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getCurrentDate(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF44474D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                      },
                      onPageChanged: (focused) {
                        setState(() {
                          _focusedDay = focused;
                        });
                        if (user != null) {
                          _loadMonthAssignments(user.id);
                        }
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final dateStr = _getDateString(day);
                          final assignments = _monthAssignments[dateStr];
                          if (assignments != null && assignments.isNotEmpty) {
                            return Container(
                              margin: const EdgeInsets.all(4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return Container(
                            margin: const EdgeInsets.all(4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF0051D5),
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                color: Color(0xFF0051D5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildLegend(const Color(0xFF10B981), 'Con trabajo'),
                      const SizedBox(width: 16),
                      _buildLegend(const Color(0xFF0051D5), 'Hoy'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isToday
                        ? 'Turnos de Hoy'
                        : 'Turnos del ${_selectedDay.day}/${_selectedDay.month}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF001229),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (assignments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'No hay turnos asignados para este dia',
                        style: TextStyle(fontSize: 14, color: Color(0xFF44474D)),
                      ),
                    )
                  else
                    ...assignments.map((a) => (user?.isOffice == true)
                        ? _buildOfficeAssignmentCard(a, isToday)
                        : _buildAssignmentBar(a, isToday)),
                ],
              ),
            ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF44474D)),
        ),
      ],
    );
  }

  Widget _buildAssignmentBar(Map<String, dynamic> assignment, bool isToday) {
    final shift = assignment['shift_data'] as Map<String, dynamic>?;
    final client = assignment['client_data'] as Map<String, dynamic>?;
    final attendance = assignment['attendance'] as dynamic;
    final shiftId = assignment['shift_id'] as String? ?? '';

    final shiftName = shift?['name'] ?? 'Sin turno';
    final startTime = _formatTimeStr(shift?['start_time']);
    final endTime = _formatTimeStr(shift?['end_time']);
    final clientName = client?['name'] ?? 'Sin cliente';
    final clientAddress = client?['address'] ?? '';

    DateTime? checkInDate;
    DateTime? checkOutDate;

    if (attendance is AttendanceModel) {
      checkInDate = attendance.checkIn;
      checkOutDate = attendance.checkOut;
    } else if (attendance is Map) {
      if (attendance['check_in'] != null) {
        checkInDate = attendance['check_in'] is DateTime
            ? attendance['check_in'] as DateTime
            : DateTime.tryParse(attendance['check_in'].toString())?.toLocal();
      }
      if (attendance['check_out'] != null) {
        checkOutDate = attendance['check_out'] is DateTime
            ? attendance['check_out'] as DateTime
            : DateTime.tryParse(attendance['check_out'].toString())?.toLocal();
      }
    }

    if (checkInDate == null) {
      final selectedDateStr = _getDateString(_selectedDay);
      final match = context.read<AttendanceProvider>().attendances.where((a) {
        return a.date == selectedDateStr && a.shiftId == shiftId;
      }).firstOrNull;
      if (match != null) {
        checkInDate = match.checkIn;
        checkOutDate = match.checkOut;
      }
    }

    final hasCheckIn = checkInDate != null;
    final hasCheckOut = checkOutDate != null;

    final inRange = _inRangeMap[shiftId] ?? false;

    // Validación de horario permitido para marcar entrada (5 min antes del turno)
    final now = DateTime.now();
    final shiftStart = _getShiftStartTime(shift?['start_time'], now);
    final earliestAllowed = shiftStart?.subtract(const Duration(minutes: 5));
    final isTooEarly = isToday && earliestAllowed != null && now.isBefore(earliestAllowed);
    final earliestAllowedStr = earliestAllowed != null ? _formatTime(earliestAllowed) : '';

    // Cronometro en vivo si esta en turno
    String cronoText = '--:--:--';
    if (hasCheckIn && !hasCheckOut) {
      final diff = DateTime.now().difference(checkInDate);
      if (!diff.isNegative) {
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        cronoText = '$h:$m:$s';
      }
    }

    final isPast = _isPastDay(_selectedDay);

    Color borderColor;
    if (hasCheckOut) {
      borderColor = const Color(0xFF0051D5);
    } else if (hasCheckIn) {
      borderColor = const Color(0xFF10B981);
    } else if (isTooEarly) {
      borderColor = const Color(0xFFCBD5E1);
    } else if (!inRange && isToday) {
      borderColor = const Color(0xFFEF4444);
    } else if (isPast && !hasCheckIn) {
      borderColor = const Color(0xFFEF4444);
    } else {
      borderColor = const Color(0xFFE6EEFF);
    }

    return GestureDetector(
      onTap: () {
        if (!isToday) return;
        if (hasCheckIn) return;
        if (_isProcessing) return;

        if (isTooEarly) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aún no puedes marcar. Tu turno empieza a las $startTime'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        if (!inRange) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Estas fuera del rango permitido. Acercate al lugar de trabajo.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        _openCameraAndPreview(assignment);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasCheckIn ? const Color(0xFF10B981) : const Color(0xFF0F2744),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasCheckIn ? Icons.check : Icons.business,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF001229),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clientAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF44474D),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasCheckIn && !hasCheckOut)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'En turno',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        cronoText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  )
                else if (hasCheckOut)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0051D5).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Completado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0051D5),
                      ),
                    ),
                  )
                else if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isTooEarly
                          ? const Color(0xFFF1F5F9)
                          : inRange
                              ? const Color(0xFFF59E0B).withOpacity(0.15)
                              : const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isTooEarly
                          ? 'Disponible a partir de las $earliestAllowedStr'
                          : inRange
                              ? 'Toca para marcar'
                              : 'Fuera de rango',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isTooEarly
                            ? const Color(0xFF64748B)
                            : inRange
                                ? const Color(0xFF92400E)
                                : const Color(0xFF991B1B),
                      ),
                    ),
                  )
                else if (isPast)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Falta',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pendiente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Color(0xFF0051D5)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$shiftName  |  $startTime - $endTime',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF001229),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasCheckIn && !hasCheckOut && isToday) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _markExit(assignment),
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('Finalizar Turno'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfficeAssignmentCard(Map<String, dynamic> assignment, bool isToday) {
    final shift = assignment['shift_data'] as Map<String, dynamic>?;
    final attendance = assignment['attendance'] as dynamic;
    final shiftId = assignment['shift_id']?.toString() ?? '';

    final shiftName = shift?['name'] ?? 'Turno de Oficina';
    final startTime = _formatTimeStr(shift?['start_time']);
    final endTime = _formatTimeStr(shift?['end_time']);

    DateTime? checkInDate;
    DateTime? checkOutDate;

    if (attendance is AttendanceModel) {
      checkInDate = attendance.checkIn;
      checkOutDate = attendance.checkOut;
    } else if (attendance is Map) {
      if (attendance['check_in'] != null) {
        checkInDate = attendance['check_in'] is DateTime
            ? attendance['check_in'] as DateTime
            : DateTime.tryParse(attendance['check_in'].toString())?.toLocal();
      }
      if (attendance['check_out'] != null) {
        checkOutDate = attendance['check_out'] is DateTime
            ? attendance['check_out'] as DateTime
            : DateTime.tryParse(attendance['check_out'].toString())?.toLocal();
      }
    }

    if (checkInDate == null) {
      final selectedDateStr = _getDateString(_selectedDay);
      final match = context.read<AttendanceProvider>().attendances.where((a) {
        return a.date == selectedDateStr && a.shiftId == shiftId;
      }).firstOrNull;
      if (match != null) {
        checkInDate = match.checkIn;
        checkOutDate = match.checkOut;
      }
    }

    final hasCheckIn = checkInDate != null;
    final hasCheckOut = checkOutDate != null;

    final inRange = _isInOffice || (_inRangeMap[shiftId] ?? false);

    // Validación de horario permitido para marcar entrada (5 min antes del turno)
    final now = DateTime.now();
    final shiftStart = _getShiftStartTime(shift?['start_time'], now);
    final earliestAllowed = shiftStart?.subtract(const Duration(minutes: 5));
    final isTooEarly = isToday && earliestAllowed != null && now.isBefore(earliestAllowed);
    final earliestAllowedStr = earliestAllowed != null ? _formatTime(earliestAllowed) : '';

    // Cronometro en vivo si esta en turno
    String cronoText = '--:--:--';
    if (hasCheckIn && !hasCheckOut) {
      final diff = DateTime.now().difference(checkInDate);
      if (!diff.isNegative) {
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        cronoText = '$h:$m:$s';
      }
    }

    final isPast = _isPastDay(_selectedDay);

    Color borderColor;
    if (hasCheckOut) {
      borderColor = const Color(0xFF0051D5);
    } else if (hasCheckIn) {
      borderColor = const Color(0xFF10B981);
    } else if (isTooEarly) {
      borderColor = const Color(0xFFCBD5E1);
    } else if (!inRange && isToday) {
      borderColor = const Color(0xFFEF4444);
    } else if (isPast && !hasCheckIn) {
      borderColor = const Color(0xFFEF4444);
    } else {
      borderColor = const Color(0xFFE6EEFF);
    }

    return GestureDetector(
      onTap: () {
        if (!isToday) return;
        if (hasCheckIn) return;
        if (_isProcessing) return;

        if (isTooEarly) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aún no puedes marcar. Tu turno empieza a las $startTime'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        if (!inRange) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Estas fuera del rango permitido. Acercate a la oficina.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        _markOfficeEntry(assignment);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasCheckIn ? const Color(0xFF10B981) : const Color(0xFF0F2744),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasCheckIn ? Icons.check : Icons.schedule,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shiftName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF001229),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Color(0xFF44474D)),
                          const SizedBox(width: 4),
                          Text(
                            '$startTime - $endTime',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF44474D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasCheckIn && !hasCheckOut)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'En turno',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        cronoText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  )
                else if (hasCheckOut)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0051D5).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Completado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0051D5),
                      ),
                    ),
                  )
                else if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isTooEarly
                          ? const Color(0xFFF1F5F9)
                          : inRange
                              ? const Color(0xFFF59E0B).withOpacity(0.15)
                              : const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isTooEarly
                          ? 'Disponible a partir de las $earliestAllowedStr'
                          : inRange
                              ? 'Toca para marcar'
                              : 'Fuera de rango',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isTooEarly
                            ? const Color(0xFF64748B)
                            : inRange
                                ? const Color(0xFF92400E)
                                : const Color(0xFF991B1B),
                      ),
                    ),
                  )
                else if (isPast)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Falta',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pendiente',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
            if (hasCheckIn && !hasCheckOut && isToday) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _markExit(assignment),
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('Finalizar Turno'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DateTime? _getShiftStartTime(dynamic startTimeStr, DateTime day) {
    if (startTimeStr == null) return null;
    final parts = startTimeStr.toString().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  DateTime? _getShiftEndTime(dynamic endTimeStr, dynamic startTimeStr, DateTime day) {
    if (endTimeStr == null) return null;
    final parts = endTimeStr.toString().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    var shiftEnd = DateTime(day.year, day.month, day.day, h, m);
    if (startTimeStr != null) {
      final sParts = startTimeStr.toString().split(':');
      if (sParts.length >= 2) {
        final sH = int.tryParse(sParts[0]);
        if (sH != null && h < sH) {
          shiftEnd = shiftEnd.add(const Duration(days: 1));
        }
      }
    }
    return shiftEnd;
  }

  String _formatTimeStr(dynamic time) {
    if (time == null) return '--:--';
    final str = time.toString();
    if (str.length >= 5) return str.substring(0, 5);
    return str;
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    const weekdays = [
      'Lunes',
      'Martes',
      'Miercoles',
      'Jueves',
      'Viernes',
      'Sabado',
      'Domingo'
    ];
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]} de ${now.year}';
  }
}