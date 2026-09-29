import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/attendance_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/custom_drawer.dart';
import 'create_employee_admin.dart';

class EmployeesAdmin extends StatefulWidget {
  const EmployeesAdmin({super.key});

  @override
  State<EmployeesAdmin> createState() => _EmployeesAdminState();
}

class _EmployeesAdminState extends State<EmployeesAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  String _filterStatus = 'all'; // 'all', 'active', 'inactive'
  String _searchQuery = '';
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    await context.read<AttendanceProvider>().fetchAllEmployees();
  }

  List<UserModel> _getFilteredEmployees(List<UserModel> employees) {
    return employees.where((emp) {
      // Filtro de estado
      if (_filterStatus == 'active' && !emp.isActive) return false;
      if (_filterStatus == 'inactive' && emp.isActive) return false;

      // Filtro de búsqueda
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = emp.fullName.toLowerCase().contains(query);
        final emailMatch = emp.email.toLowerCase().contains(query);
        final ciMatch = (emp.ci ?? '').toLowerCase().contains(query);
        if (!nameMatch && !emailMatch && !ciMatch) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _openContract(UserModel emp) async {
    if (emp.contractUrl == null || emp.contractUrl!.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando enlace seguro del contrato...'),
        duration: Duration(seconds: 1),
      ),
    );

    final signedUrl = await _storageService.getSignedContractUrl(emp.contractUrl!);
    if (signedUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener el acceso al contrato'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final opened = await _storageService.openContractUrl(signedUrl);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el enlace en el visor del dispositivo'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Pide la contraseña del administrador y valida con Supabase Auth
  Future<bool> _promptAdminPassword({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = const Color(0xFF0F2744),
    Widget? extraContent,
  }) async {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? localError;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: const TextStyle(fontSize: 14)),
                    if (extraContent != null) ...[
                      const SizedBox(height: 12),
                      extraContent,
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Contraseña de Administrador *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setModalState(() => obscure = !obscure),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        errorText: localError,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pwd = passwordController.text.trim();
                    if (pwd.isEmpty) {
                      setModalState(() => localError = 'Ingresa tu contraseña');
                      return;
                    }

                    final attProv = context.read<AttendanceProvider>();
                    final isValid = await attProv.verifyAdminPassword(pwd);

                    if (!isValid) {
                      setModalState(() => localError = 'Contraseña incorrecta');
                      return;
                    }

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      },
    );

    return result == true;
  }

  Future<void> _handleDeleteEmployee(UserModel emp) async {
    final confirmed = await _promptAdminPassword(
      title: 'Eliminar Empleado',
      message: '¿Estás seguro de eliminar a ${emp.fullName}? Esta acción no se puede deshacer.',
      confirmText: 'Eliminar Definitivamente',
      confirmColor: Colors.red.shade700,
    );

    if (confirmed && mounted) {
      final attProv = context.read<AttendanceProvider>();
      final success = await attProv.deleteEmployee(emp.id, contractPath: emp.contractUrl);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Empleado ${emp.fullName} eliminado'),
              backgroundColor: const Color(0xFF15803D),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(attProv.error ?? 'Error al eliminar empleado'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleTerminateEmployee(UserModel emp) async {
    final reasonController = TextEditingController();

    final confirmed = await _promptAdminPassword(
      title: 'Dar de Baja',
      message: '¿Estás seguro de dar de baja a ${emp.fullName}? El empleado perderá acceso a la app.',
      confirmText: 'Confirmar Baja',
      confirmColor: Colors.orange.shade800,
      extraContent: TextField(
        controller: reasonController,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: 'Motivo de baja (opcional)',
          hintText: 'Ej. Renuncia voluntaria, fin de contrato...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    if (confirmed && mounted) {
      final attProv = context.read<AttendanceProvider>();
      final success = await attProv.terminateEmployee(
        userId: emp.id,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Empleado ${emp.fullName} dado de baja'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(attProv.error ?? 'Error al dar de baja'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReactivateEmployee(UserModel emp) async {
    final confirmed = await _promptAdminPassword(
      title: 'Reactivar Empleado',
      message: '¿Deseas reactivar a ${emp.fullName}? Podrá volver a ingresar a la aplicación.',
      confirmText: 'Reactivar',
      confirmColor: const Color(0xFF15803D),
    );

    if (confirmed && mounted) {
      final attProv = context.read<AttendanceProvider>();
      final success = await attProv.reactivateEmployee(emp.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Empleado ${emp.fullName} reactivado con éxito'),
              backgroundColor: const Color(0xFF15803D),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(attProv.error ?? 'Error al reactivar empleado'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleEditEmployee(UserModel emp) async {
    final nameController = TextEditingController(text: emp.fullName);
    final phoneController = TextEditingController(text: emp.phone ?? '');
    final addressController = TextEditingController(text: emp.address ?? '');
    final departmentController = TextEditingController(text: emp.department);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Editar: ${emp.fullName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(labelText: 'Departamento / Área'),
              ),
            ],
          ),
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final attProv = context.read<AttendanceProvider>();
      final ok = await attProv.updateUserProfile(
        userId: emp.id,
        fullName: nameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
      );

      if (mounted) {
        if (ok) {
          await _loadEmployees();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Datos del empleado actualizados'),
              backgroundColor: Color(0xFF15803D),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(attProv.error ?? 'Error al actualizar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attProv = context.watch<AttendanceProvider>();
    final allEmployees = attProv.allEmployees;
    final filtered = _getFilteredEmployees(allEmployees);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Empleados y Roles',
          style: TextStyle(color: Color(0xFF0F2744), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF0F2744)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF0F2744)),
            tooltip: 'Nuevo Empleado',
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreateEmployeeAdmin()),
              );
              if (created == true) {
                _loadEmployees();
              }
            },
          ),
        ],
      ),
      drawer: const CustomDrawer(isAdmin: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateEmployeeAdmin()),
          );
          if (created == true) {
            _loadEmployees();
          }
        },
        backgroundColor: const Color(0xFF0F2744),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar Empleado'),
      ),
      body: attProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEmployees,
              child: Column(
                children: [
                  // Barra de búsqueda y filtros
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    color: Colors.white,
                    child: Column(
                      children: [
                        // Campo de búsqueda
                        TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, correo o C.I...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Chips de filtros
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('all', 'Todos (${allEmployees.length})'),
                              const SizedBox(width: 8),
                              _buildFilterChip('active', 'Activos (${allEmployees.where((e) => e.isActive).length})'),
                              const SizedBox(width: 8),
                              _buildFilterChip('inactive', 'De baja (${allEmployees.where((e) => !e.isActive).length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Lista de colaboradores
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No se encontraron resultados para "$_searchQuery"'
                                      : 'No hay colaboradores en esta categoría',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final emp = filtered[index];
                              return _buildEmployeeCard(emp);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filterStatus = value);
      },
      selectedColor: const Color(0xFF0F2744),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF0F2744),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
    );
  }

  Widget _buildEmployeeCard(UserModel emp) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: emp.isActive ? Colors.grey.shade200 : Colors.red.shade100,
        ),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Avatar, Nombre, Correo y Badge de Estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: emp.isAdmin
                      ? const Color(0xFF0051D5).withOpacity(0.15)
                      : (emp.isActive
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.grey.shade300),
                  child: Text(
                    emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: emp.isAdmin
                          ? const Color(0xFF0051D5)
                          : (emp.isActive ? const Color(0xFF065F46) : Colors.grey.shade700),
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF001229),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        emp.email,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Badge de Estado: Activo o De baja
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: emp.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: emp.isActive ? const Color(0xFF86EFAC) : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: emp.isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        emp.isActive ? 'Activo' : 'De baja',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: emp.isActive ? const Color(0xFF15803D) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // CI, Departamento y Rol
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (emp.ci != null && emp.ci!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'C.I.: ${emp.ci}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.work_outline, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '${emp.roleDisplay} • ${emp.isOffice ? 'Oficina' : 'Campo'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ],
                ),
                if (emp.department.isNotEmpty && emp.department != 'General')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        emp.department,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
              ],
            ),

            // Información de baja si está inactivo
            if (!emp.isActive) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_busy, size: 14, color: Color(0xFFDC2626)),
                        const SizedBox(width: 6),
                        Text(
                          emp.terminationDate != null
                              ? 'Fecha de baja: ${DateFormat('dd/MM/yyyy HH:mm').format(emp.terminationDate!.toLocal())}'
                              : 'Dado de baja',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                    if (emp.terminationReason != null && emp.terminationReason!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Motivo: ${emp.terminationReason}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Contrato de Trabajo (si existe)
            if (emp.contractUrl != null && emp.contractUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openContract(emp),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description, size: 18, color: Color(0xFF0051D5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          emp.contractFilename ?? 'Contrato laboral firmado',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0051D5),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Ver Contrato',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0051D5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.open_in_new, size: 13, color: Color(0xFF0051D5)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Editar
                TextButton.icon(
                  onPressed: () => _handleEditEmployee(emp),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F2744),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                const SizedBox(width: 4),

                // Dar de baja o Reactivar
                if (emp.isActive)
                  TextButton.icon(
                    onPressed: () => _handleTerminateEmployee(emp),
                    icon: const Icon(Icons.person_off, size: 16),
                    label: const Text('Dar de baja', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _handleReactivateEmployee(emp),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Reactivar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF15803D),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                const SizedBox(width: 4),

                // Eliminar
                TextButton.icon(
                  onPressed: () => _handleDeleteEmployee(emp),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}