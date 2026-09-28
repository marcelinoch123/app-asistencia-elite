import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CustomDrawer extends StatelessWidget {
  final bool isAdmin;

  const CustomDrawer({
    super.key,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F2744),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          color: Color(0xFF0F2744),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Usuario',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              isAdmin ? 'Administrador' : 'Empleado',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB2C8ED),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF0051D5),
                          child: Text(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.email ?? 'usuario@empresa.com',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Activo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6FFBBE),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NAVEGACION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF44474D),
                        letterSpacing: 0.03,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDrawerItem(
                      icon: Icons.dashboard,
                      label: 'Dashboard',
                      isActive: true,
                      onTap: () {
                        Navigator.pop(context);
                        if (isAdmin) {
                          Navigator.pushReplacementNamed(context, '/admin/dashboard');
                        } else {
                          Navigator.pushReplacementNamed(context, '/employee/dashboard');
                        }
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.person,
                      label: 'Perfil',
                      onTap: () {
                        Navigator.pop(context);
                        if (isAdmin) {
                          _showProfileDialog(context, authProvider);
                        } else {
                          Navigator.pushNamed(context, '/employee/profile');
                        }
                      },
                    ),
                    if (!isAdmin) ...[
                      _buildDrawerItem(
                        icon: Icons.fingerprint,
                        label: 'Asistencia',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(context, '/employee/dashboard');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.history,
                        label: 'Historial',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/employee/history');
                        },
                      ),
                    ],
                    if (isAdmin) ...[
                      const Divider(height: 24),
                      const Text(
                        'ADMINISTRACION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF44474D),
                          letterSpacing: 0.03,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDrawerItem(
                        icon: Icons.people,
                        label: 'Empleados y Roles',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(context, '/admin/employees');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.schedule,
                        label: 'Gestion de Turnos',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/shifts');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.assignment_ind,
                        label: 'Asignar Turnos',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/assign');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.event_note,
                        label: 'Asignaciones del Día',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/daily_assignments');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.business,
                        label: 'Gestion de Clientes',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/clients');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.event_available,
                        label: 'Permisos',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/permissions');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.assessment,
                        label: 'Reportes',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/reports');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.calendar_month,
                        label: 'Calendario Laboral',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/calendar');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.map,
                        label: 'Mapa en Tiempo Real',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/admin/map');
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    label: 'Cerrar Sesion',
                    isDanger: true,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text('Cerrar Sesion'),
                          content: const Text('Estas seguro que quieres cerrar sesion?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Cerrar Sesion'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await authProvider.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version 2.4.0 Mobile',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF44474D),
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

  void _showProfileDialog(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person, color: Color(0xFF0F2744)),
            SizedBox(width: 8),
            Text('Mi Perfil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('Nombre', user?.fullName ?? 'N/A'),
            const Divider(),
            _buildProfileRow('Email', user?.email ?? 'N/A'),
            const Divider(),
            _buildProfileRow(
              'Rol',
              user?.role == 'admin' ? 'Administrador' : 'Empleado',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF44474D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF001229),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isActive = false,
    bool isDanger = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDanger
            ? Colors.red
            : (isActive ? Colors.white : const Color(0xFF44474D)),
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          color: isDanger
              ? Colors.red
              : (isActive ? Colors.white : const Color(0xFF0D1C2F)),
        ),
      ),
      tileColor: isActive ? const Color(0xFF0051D5) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}