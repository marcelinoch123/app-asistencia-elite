import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/custom_drawer.dart';

class PermissionsAdmin extends StatefulWidget {
  const PermissionsAdmin({super.key});

  @override
  State<PermissionsAdmin> createState() => _PermissionsAdminState();
}

class _PermissionsAdminState extends State<PermissionsAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final provider = context.read<AttendanceProvider>();
    await provider.fetchPermissions();
    await provider.fetchAllEmployees();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final permissions = provider.permissions;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FF),
      drawer: const CustomDrawer(isAdmin: true),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF0D1C2F)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Gestión de Permisos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F2744),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Crear Permiso'),
        onPressed: () => _showPermissionDialog(context),
      ),
      body: provider.isPermissionsLoading
          ? const Center(child: CircularProgressIndicator())
          : permissions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: permissions.length,
                  itemBuilder: (context, index) {
                    return _buildPermissionCard(permissions[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available, size: 80, color: Color(0xFFD5E3FD)),
          const SizedBox(height: 16),
          const Text(
            'No hay permisos registrados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF44474D),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Presiona "Crear Permiso" para empezar',
            style: TextStyle(fontSize: 14, color: Color(0xFF74777E)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(Map<String, dynamic> permission) {
    final userName = permission['user_name'] ?? 'Empleado';
    final userEmail = permission['user_email'] ?? '';
    final startDate = permission['start_date']?.toString() ?? '';
    final endDate = permission['end_date']?.toString() ?? '';
    final reason = permission['reason']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available,
                    color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF001229),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Del $startDate al $endDate',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0051D5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF001229),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _confirmDelete(permission),
              icon: const Icon(Icons.delete,
                  size: 16, color: Color(0xFFBA1A1A)),
              label: const Text(
                'Eliminar',
                style: TextStyle(color: Color(0xFFBA1A1A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog(BuildContext context) {
    String? selectedUserId;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final provider = context.read<AttendanceProvider>();
          final employees =
              provider.allEmployees.where((e) => !e.isAdmin).toList();

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.event_available, color: Color(0xFF0F2744)),
                SizedBox(width: 8),
                Text('Nuevo Permiso'),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Empleado',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF44474D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedUserId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Selecciona empleado',
                      ),
                      items: employees.map((emp) {
                        return DropdownMenuItem(
                          value: emp.id,
                          child: Text('${emp.fullName} (${emp.email})'),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedUserId = val),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fecha de inicio',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF44474D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startDate = picked;
                            if (endDate.isBefore(startDate)) {
                              endDate = startDate;
                            }
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(startDate),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fecha de fin',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF44474D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: endDate,
                          firstDate: startDate,
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => endDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(endDate),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Motivo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF44474D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Cita médica, permiso personal, etc.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedUserId == null) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      const SnackBar(content: Text('Selecciona un empleado')),
                    );
                    return;
                  }
                  if (reasonCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      const SnackBar(content: Text('Ingresa un motivo')),
                    );
                    return;
                  }

                  final success = await provider.createPermission(
                    userId: selectedUserId!,
                    startDate: startDate,
                    endDate: endDate,
                    reason: reasonCtrl.text.trim(),
                  );

                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? '✅ Permiso creado'
                            : '❌ Error al crear'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2744),
                ),
                child: const Text('Crear Permiso'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> permission) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Permiso'),
        content: const Text('¿Seguro que quieres eliminar este permiso?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await context
                  .read<AttendanceProvider>()
                  .deletePermission(permission['id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? '✅ Permiso eliminado'
                        : '❌ Error al eliminar'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}