import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isAdmin;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Items para ADMIN
    if (isAdmin) {
      return _buildNavBar([
        _NavItem(icon: Icons.dashboard, label: 'Dashboard', index: 0),
        _NavItem(icon: Icons.people, label: 'Empleados', index: 1),
        _NavItem(icon: Icons.assessment, label: 'Reportes', index: 2),
        _NavItem(icon: Icons.map, label: 'Mapa', index: 3),
      ]);
    }

    // ✅ Items para EMPLEADO
    return _buildNavBar([
      _NavItem(icon: Icons.dashboard, label: 'Dashboard', index: 0),
      _NavItem(icon: Icons.fingerprint, label: 'Asistencia', index: 1),
      _NavItem(icon: Icons.history, label: 'Historial', index: 2),
      _NavItem(icon: Icons.event_busy, label: 'Permisos', index: 3),
    ]);
  }

  Widget _buildNavBar(List<_NavItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2744).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              return _buildNavItem(
                icon: item.icon,
                label: item.label,
                index: item.index,
                isActive: currentIndex == item.index,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    final color =
        isActive ? const Color(0xFF0051D5) : const Color(0xFF44474D);

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  _NavItem({required this.icon, required this.label, required this.index});
}