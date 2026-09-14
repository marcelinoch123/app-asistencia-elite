import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/bottom_nav.dart';

class HistoryEmployee extends StatefulWidget {
  const HistoryEmployee({super.key});

  @override
  State<HistoryEmployee> createState() => _HistoryEmployeeState();
}

class _HistoryEmployeeState extends State<HistoryEmployee> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    if (authProvider.user != null) {
      await attendanceProvider.fetchAttendances(authProvider.user!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final attendances = attendanceProvider.attendances;

    // Calcular métricas
    final puntuales = attendances
        .where((a) => a.status == 'on_time' || a.status == 'early')
        .length;
    final tardanzas = attendances
        .where((a) => a.status == 'late' || a.status == 'very_late')
        .length;
    final faltas = attendances.where((a) => a.status == 'absent').length;

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
          'Historial de Marcaciones',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
      ),
      // ✅ BARRA INFERIOR
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/employee/dashboard');
          } else if (index == 2) {
            // Ya estamos aquí
          } else if (index == 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permisos - Próximamente')),
            );
          }
        },
      ),
      body: attendanceProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============================================================
                  // TARJETA DE IDENTIDAD
                  // ============================================================
                  Container(
                    padding: const EdgeInsets.all(16),
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
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F2744),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.fingerprint,
                              color: Color(0xFF6FFBBE)),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bitácora Personal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF44474D),
                                letterSpacing: 0.03,
                              ),
                            ),
                            Text(
                              'Historial de Marcaciones',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D1C2F),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ============================================================
                  // MÉTRICAS RÁPIDAS
                  // ============================================================
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          value: '$puntuales',
                          label: 'Puntuales',
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          value: '$tardanzas',
                          label: 'Tardanzas',
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          value: '$faltas',
                          label: 'Faltas',
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          value: '0',
                          label: 'Permisos',
                          color: const Color(0xFF74777E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ============================================================
                  // LISTA DE ASISTENCIAS
                  // ============================================================
                  const Text(
                    'ÚLTIMOS REGISTROS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF44474D),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (attendances.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: const Text(
                        'No hay asistencias registradas',
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFF44474D)),
                      ),
                    )
                  else
                    ...attendances.map((att) => _buildAttendanceCard(att)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
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
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1C2F),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF44474D),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(dynamic att) {
    // Colores según estado
    Color statusColor;
    Color statusBg;
    String statusText;

    switch (att.status) {
      case 'early':
        statusColor = const Color(0xFF065F46);
        statusBg = const Color(0xFFECFDF5);
        statusText = 'Temprano';
        break;
      case 'on_time':
        statusColor = const Color(0xFF065F46);
        statusBg = const Color(0xFFECFDF5);
        statusText = 'A tiempo';
        break;
      case 'late':
        statusColor = const Color(0xFF92400E);
        statusBg = const Color(0xFFFEF3C7);
        statusText = 'Tardanza';
        break;
      case 'very_late':
        statusColor = const Color(0xFF991B1B);
        statusBg = const Color(0xFFFEE2E2);
        statusText = 'Muy tarde';
        break;
      default:
        statusColor = const Color(0xFF44474D);
        statusBg = const Color(0xFFE6EEFF);
        statusText = 'Ausente';
    }

    final checkInStr =
        att.checkIn != null ? _formatTime(att.checkIn!) : '--:--';
    final checkOutStr =
        att.checkOut != null ? _formatTime(att.checkOut!) : 'En curso';

    final workedHours = att.workedMinutes > 0
        ? '${att.workedMinutes ~/ 60}h ${att.workedMinutes % 60}m'
        : '--';

    // Parsear fecha para mostrar día
    final parts = att.date.split('-');
    final day = parts.length == 3 ? parts[2] : '--';
    final month = parts.length == 3 ? _getMonthName(int.parse(parts[1])) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Column(
        children: [
          // Fecha y estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6EEFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          month.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF44474D),
                          ),
                        ),
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF001229),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    att.date,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D1C2F),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Entrada / Salida / Efectivas
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoBlock(
                    icon: Icons.login,
                    label: 'Entrada',
                    value: checkInStr,
                    color: const Color(0xFF10B981),
                  ),
                ),
                Expanded(
                  child: _buildInfoBlock(
                    icon: Icons.logout,
                    label: 'Salida',
                    value: checkOutStr,
                    color: const Color(0xFF0051D5),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Efectivas',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF44474D),
                        ),
                      ),
                      Text(
                        workedHours,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF001229),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Retraso
          if (att.lateMinutes > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber,
                      size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text(
                    'Retraso: ${att.lateMinutes ~/ 60}h ${att.lateMinutes % 60}min',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBlock({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF44474D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _getMonthName(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[month - 1];
  }
}