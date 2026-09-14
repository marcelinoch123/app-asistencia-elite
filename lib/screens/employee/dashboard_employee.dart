import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/location_provider.dart';
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
  Duration _workedHours = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // TIMER QUE ACTUALIZA EL CRONÓMETRO CADA SEGUNDO
  // ============================================================
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final attendanceProvider = context.read<AttendanceProvider>();
      final hours = attendanceProvider.getWorkedHours();
      setState(() => _workedHours = hours);
    });
  }

  // ============================================================
  // CARGAR DATOS AL ENTRAR
  // ============================================================
  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    if (authProvider.user != null) {
      await attendanceProvider.fetchAttendances(authProvider.user!.id);
      if (mounted) {
        setState(() {
          _workedHours = attendanceProvider.getWorkedHours();
        });
      }
    }
  }

  // ============================================================
  // NAVEGACIÓN INFERIOR
  // ============================================================
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
          const SnackBar(content: Text('Permisos - Próximamente')),
        );
        break;
    }
  }

  // ============================================================
  // INICIAR TURNO
  // ============================================================
  Future<void> _registerAttendance() async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final locationProvider = context.read<LocationProvider>();

    if (authProvider.user == null) return;

    setState(() => _isProcessing = true);

    try {
      // ✅ OBTENER UBICACIÓN REAL ANTES DE GUARDAR
      print('📍 Obteniendo ubicación para iniciar turno...');
      final position = await locationProvider.getCurrentLocation();

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '❌ No se pudo obtener tu ubicación. Activa el GPS y permite el acceso.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      print(
          '📍 Ubicación obtenida: ${position.latitude}, ${position.longitude} (±${position.accuracy}m)');

      // ✅ PASAR LA POSICIÓN AL checkIn
      final success = await attendanceProvider.checkIn(
        authProvider.user!.id,
        position,
      );

      if (success && mounted) {
        final lateMin = attendanceProvider.lastLateMinutes;
        final checkInTime = attendanceProvider.lastCheckInTime ?? '';
        final shiftStart = attendanceProvider.lastShiftStart ?? '';

        String mensaje;
        Color color;

        if (lateMin > 0) {
          final horas = lateMin ~/ 60;
          final mins = lateMin % 60;
          String tiempoRetraso = '';
          if (horas > 0) tiempoRetraso += '${horas}h ';
          if (mins > 0 || horas == 0) tiempoRetraso += '${mins}min';

          mensaje =
              '⚠️ Turno iniciado a las $checkInTime\nTurno: $shiftStart\nRetraso: $tiempoRetraso\n📍 GPS: ±${position.accuracy.toStringAsFixed(0)}m';
          color = Colors.orange;
        } else {
          mensaje =
              '✅ Turno iniciado a las $checkInTime - A tiempo\n📍 GPS: ±${position.accuracy.toStringAsFixed(0)}m';
          color = Colors.green;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: color,
            duration: const Duration(seconds: 5),
          ),
        );

        await attendanceProvider.fetchAttendances(authProvider.user!.id);
        setState(() {
          _workedHours = attendanceProvider.getWorkedHours();
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attendanceProvider.error ?? 'Error'),
            backgroundColor: Colors.red,
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

    setState(() => _isProcessing = false);
  }

  // ============================================================
  // FINALIZAR TURNO
  // ============================================================
  Future<void> _finishShift() async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    if (authProvider.user == null) return;

    setState(() => _isProcessing = true);

    try {
      final success = await attendanceProvider.checkOut(authProvider.user!.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Turno finalizado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        await attendanceProvider.fetchAttendances(authProvider.user!.id);
        _timer?.cancel();
        setState(() {
          _workedHours = attendanceProvider.getWorkedHours();
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attendanceProvider.error ?? 'Error'),
            backgroundColor: Colors.red,
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

    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final user = authProvider.user;
    final todayAtt = attendanceProvider.todayAttendance;

    final hasCheckedIn = todayAtt?.checkIn != null;
    final hasCheckedOut = todayAtt?.checkOut != null;
    final lateMinutes = todayAtt?.lateMinutes ?? 0;

    // Formatear hora de inicio
    String startTimeStr = '--:--';
    if (todayAtt?.checkIn != null) {
      final local = todayAtt!.checkIn!;
      startTimeStr = _formatTime(local);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FF),
      drawer: const CustomDrawer(isAdmin: false),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.8),
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
                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¡Bienvenido! Ponte a chambear 💪',
                            style: TextStyle(
                              fontSize: 24,
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
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE9FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.wb_sunny,
                            color: Color(0xFF0051D5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ============================================================
                  // CARD DE UBICACIÓN GPS
                  // ============================================================
                  Container(
                    padding: const EdgeInsets.all(14),
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
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: locationProvider.currentPosition != null
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            locationProvider.currentPosition != null
                                ? Icons.location_on
                                : Icons.location_off,
                            color: locationProvider.currentPosition != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'UBICACIÓN GPS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF44474D),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                locationProvider.currentPosition != null
                                    ? '${locationProvider.currentPosition!.latitude.toStringAsFixed(5)}, ${locationProvider.currentPosition!.longitude.toStringAsFixed(5)}'
                                    : 'Obteniendo ubicación...',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF001229),
                                ),
                              ),
                              if (locationProvider.currentPosition != null)
                                Text(
                                  'Precisión: ±${locationProvider.currentPosition!.accuracy.toStringAsFixed(0)}m',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF74777E),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh,
                              color: Color(0xFF0051D5)),
                          onPressed: () async {
                            await locationProvider.getCurrentLocation();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // TARJETA DE ESTADO
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F2744),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.schedule,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Estado del Turno',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF44474D),
                                      ),
                                    ),
                                    Text(
                                      hasCheckedOut
                                          ? 'Turno finalizado'
                                          : (hasCheckedIn
                                              ? 'Turno iniciado'
                                              : 'Sin iniciar'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0D1C2F),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: hasCheckedOut
                                    ? const Color(0xFFEFF4FF)
                                    : (hasCheckedIn
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFEE2E2)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: hasCheckedOut
                                          ? const Color(0xFF0051D5)
                                          : (hasCheckedIn
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444)),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasCheckedOut
                                        ? 'Completado'
                                        : (hasCheckedIn
                                            ? 'Activo'
                                            : 'Inactivo'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: hasCheckedOut
                                          ? const Color(0xFF0051D5)
                                          : (hasCheckedIn
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF991B1B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (hasCheckedIn) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.play_circle,
                                    color: Color(0xFF10B981), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Turno iniciado: $startTimeStr',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (hasCheckedIn && lateMinutes > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFF59E0B), width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber,
                                    color: Color(0xFFF59E0B), size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Retraso registrado',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                      Text(
                                        '${lateMinutes ~/ 60}h ${lateMinutes % 60}min',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.timelapse,
                                      size: 14, color: Color(0xFF0051D5)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Horas trabajadas hoy',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF44474D),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _workedHours.inHours
                                        .toString()
                                        .padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F2744),
                                      letterSpacing: -0.03,
                                    ),
                                  ),
                                  const Text(
                                    ':',
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0051D5),
                                    ),
                                  ),
                                  Text(
                                    (_workedHours.inMinutes % 60)
                                        .toString()
                                        .padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F2744),
                                      letterSpacing: -0.03,
                                    ),
                                  ),
                                  const Text(
                                    ':',
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0051D5),
                                    ),
                                  ),
                                  Text(
                                    (_workedHours.inSeconds % 60)
                                        .toString()
                                        .padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F2744),
                                      letterSpacing: -0.03,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'hrs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF44474D),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // BOTÓN INICIAR TURNO
                  if (!hasCheckedIn)
                    GestureDetector(
                      onTap: _isProcessing ? null : _registerAttendance,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isProcessing
                              ? Colors.grey
                              : const Color(0xFF0F2744),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isProcessing
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF316BF3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow,
                                            color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'INICIAR TURNO',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.02,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Se registrará tu ubicación GPS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFB2C8ED),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                  // BOTÓN FINALIZAR TURNO
                  if (hasCheckedIn && !hasCheckedOut)
                    GestureDetector(
                      onTap: _isProcessing ? null : _finishShift,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isProcessing
                              ? Colors.grey
                              : const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isProcessing
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.stop_circle,
                                          color: Colors.white, size: 24),
                                      SizedBox(width: 8),
                                      Text(
                                        'FINALIZAR TURNO',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.02,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Registra tu hora de salida',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                  // MENSAJE COMPLETADO
                  if (hasCheckedIn && hasCheckedOut)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Color(0xFF10B981), size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '✅ Turno completado. ¡Buen trabajo!',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    const weekdays = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]} de ${now.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}