import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/bottom_nav.dart';

class DashboardAdmin extends StatefulWidget {
  const DashboardAdmin({super.key});

  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Ejecutar después del primer build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final attendanceProvider = context.read<AttendanceProvider>();
    await attendanceProvider.fetchAllEmployees();
    await attendanceProvider.fetchShifts();
  }

  void _onNavTap(int index) {
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushNamed(context, '/admin/employees');
        setState(() => _currentNavIndex = 0);
        break;
      case 2:
        Navigator.pushNamed(context, '/admin/reports');
        setState(() => _currentNavIndex = 0);
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mapa - Próximamente')),
        );
        setState(() => _currentNavIndex = 0);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final user = authProvider.user;

    final totalEmployees = attendanceProvider.totalEmployeesCount;
    final activeEmployees = attendanceProvider.activeEmployeesCount;
    final totalShifts = attendanceProvider.shifts.length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FF),
      drawer: const CustomDrawer(isAdmin: true),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF0D1C2F)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Dashboard Administrador',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2744),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDDE9FF),
                letterSpacing: 1,
              ),
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF0051D5),
            child: Text(
              user?.fullName.isNotEmpty == true
                  ? user!.fullName[0].toUpperCase()
                  : 'A',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        isAdmin: true,
      ),
      body: attendanceProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GESTIÓN DE TALENTO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0051D5),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Panel de Control',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF001229),
                      letterSpacing: -0.02,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      _buildKpiCard(
                        title: 'Total Plantilla',
                        value: '$totalEmployees',
                        subtitle: '$activeEmployees activos',
                        icon: Icons.groups,
                        iconColor: const Color(0xFF0051D5),
                        iconBg: const Color(0xFFDDE9FF),
                      ),
                      _buildKpiCard(
                        title: 'Turnos Creados',
                        value: '$totalShifts',
                        subtitle: 'Disponibles',
                        icon: Icons.schedule,
                        iconColor: const Color(0xFF00A16F),
                        iconBg: const Color(0xFFECFDF5),
                      ),
                      _buildKpiCard(
                        title: 'Presentes Hoy',
                        value: '1',
                        subtitle: 'En turno',
                        icon: Icons.check_circle,
                        iconColor: const Color(0xFF00A16F),
                        iconBg: const Color(0xFFECFDF5),
                      ),
                      _buildKpiCard(
                        title: 'Tardanzas',
                        value: '1',
                        subtitle: 'Hoy',
                        icon: Icons.warning_amber,
                        iconColor: const Color(0xFFF59E0B),
                        iconBg: const Color(0xFFFEF3C7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ACCIONES RÁPIDAS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF44474D),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildActionCard(
                    icon: Icons.schedule,
                    title: 'Gestión de Turnos',
                    subtitle: 'Crear, editar y eliminar turnos',
                    color: const Color(0xFF0F2744),
                    onTap: () => Navigator.pushNamed(context, '/admin/shifts'),
                  ),
                  const SizedBox(height: 8),
                  _buildActionCard(
                    icon: Icons.assignment_ind,
                    title: 'Asignar Turnos',
                    subtitle: 'Asignar turnos a empleados por fechas',
                    color: const Color(0xFF0051D5),
                    onTap: () => Navigator.pushNamed(context, '/admin/assign'),
                  ),
                  const SizedBox(height: 8),
                  _buildActionCard(
                    icon: Icons.people,
                    title: 'Empleados y Roles',
                    subtitle: 'Gestionar empleados y sus roles',
                    color: const Color(0xFF00A16F),
                    onTap: () => Navigator.pushNamed(context, '/admin/employees'),
                  ),
                  const SizedBox(height: 8),
                  _buildActionCard(
                    icon: Icons.assessment,
                    title: 'Reportes',
                    subtitle: 'Ver asistencias y métricas',
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.pushNamed(context, '/admin/reports'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'EMPLEADOS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF44474D),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (attendanceProvider.allEmployees.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: const Text(
                        'No hay empleados registrados',
                        style: TextStyle(fontSize: 14, color: Color(0xFF44474D)),
                      ),
                    )
                  else
                    ...attendanceProvider.allEmployees.take(5).map((emp) {
                      return _buildEmployeeCard(emp);
                    }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF44474D),
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF001229),
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF44474D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF001229),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF44474D),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Color(0xFF74777E)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(dynamic emp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
          CircleAvatar(
            radius: 20,
            backgroundColor:
                emp.isAdmin ? const Color(0xFF0051D5) : const Color(0xFF10B981),
            child: Text(
              emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF001229),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  emp.isAdmin ? 'Administrador' : 'Empleado · ${emp.department}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF44474D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: emp.isActive
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              emp.isActive ? 'Activo' : 'Inactivo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: emp.isActive
                    ? const Color(0xFF065F46)
                    : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}