import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/custom_drawer.dart';

class AssignShiftAdmin extends StatefulWidget {
  const AssignShiftAdmin({super.key});

  @override
  State<AssignShiftAdmin> createState() => _AssignShiftAdminState();
}

class _AssignShiftAdminState extends State<AssignShiftAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _selectedShiftId;
  String? _selectedUserId;
  String? _selectedClientId;
  String? _selectedSupervisorId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

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
    await provider.fetchShifts();
    await provider.fetchAllEmployees();
    await provider.fetchClients();
    await provider.fetchAssignmentHistory();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AttendanceProvider>();
    final shifts = prov.shifts;
    final employees = prov.allEmployees.where((e) => !e.isAdmin).toList();
    final supervisors = prov.allEmployees.where((e) => e.isAdmin || e.role == 'admin').toList();
    final clients = prov.clients;

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
          'Asignar Turnos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Selecciona el turno',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF001229),
              ),
            ),
            const SizedBox(height: 8),
            shifts.isEmpty
                ? _buildWarning('No hay turnos creados. Ve a Gestion de Turnos primero.')
                : Column(
                    children: shifts.map((s) {
                      final isSelected = _selectedShiftId == s['id'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedShiftId = s['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE6EEFF),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF74777E),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${_formatTime(s['start_time'])} - ${_formatTime(s['end_time'])}',
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
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),
            const Text(
              '2. Selecciona el cliente',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF001229),
              ),
            ),
            const SizedBox(height: 8),
            clients.isEmpty
                ? _buildWarning('No hay clientes creados. Ve a Gestion de Clientes primero.')
                : Column(
                    children: clients.map((c) {
                      final isSelected = _selectedClientId == c['id'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedClientId = c['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE6EEFF),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF74777E),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      c['service'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF0051D5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),
            const Text(
              '3. Selecciona el empleado',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF001229),
              ),
            ),
            const SizedBox(height: 8),
            employees.isEmpty
                ? _buildWarning('No hay empleados registrados')
                : Column(
                    children: employees.map((emp) {
                      final isSelected = _selectedUserId == emp.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedUserId = emp.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE6EEFF),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF0051D5),
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
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      emp.email,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF44474D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),
            const Text(
              '4. Supervisor responsable (opcional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF001229),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6EEFF)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _selectedSupervisorId,
                  hint: const Text(
                    'Seleccionar supervisor responsable',
                    style: TextStyle(fontSize: 13, color: Color(0xFF74777E)),
                  ),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0F2744)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin supervisor asignado', style: TextStyle(color: Color(0xFF74777E), fontSize: 13)),
                    ),
                    ...supervisors.map((s) => DropdownMenuItem<String?>(
                      value: s.id,
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF0051D5)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${s.fullName} (${s.email})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedSupervisorId = val),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '5. Selecciona el rango de fechas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF001229),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDateCard(
                    label: 'Desde',
                    date: _startDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateCard(
                    label: 'Hasta',
                    date: _endDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _canAssign() ? _assignShift : null,
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text(
                  'Asignar Turno',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2744),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD5E3FD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFFE6EEFF), thickness: 1.5),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF0F2744), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Historial de Cambios Recientes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF001229),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF0051D5)),
                  onPressed: () => context.read<AttendanceProvider>().fetchAssignmentHistory(),
                  tooltip: 'Actualizar historial',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHistorySection(prov),
          ],
        ),
      ),
    );
  }

  Widget _buildWarning(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6EEFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF44474D),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0051D5)),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd/MM/yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF001229),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canAssign() {
    return _selectedShiftId != null &&
        _selectedUserId != null &&
        _selectedClientId != null &&
        !_endDate.isBefore(_startDate);
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _assignShift() async {
    final prov = context.read<AttendanceProvider>();
    final success = await prov.assignShiftToEmployee(
      shiftId: _selectedShiftId!,
      userId: _selectedUserId!,
      startDate: _startDate,
      endDate: _endDate,
      clientId: _selectedClientId,
      supervisorId: _selectedSupervisorId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Turno asignado del ${DateFormat('dd/MM').format(_startDate)} al ${DateFormat('dd/MM').format(_endDate)}'
              : 'Error al asignar'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      if (success) {
        setState(() {
          _selectedShiftId = null;
          _selectedUserId = null;
          _selectedClientId = null;
          _selectedSupervisorId = null;
        });
      }
    }
  }

  Widget _buildHistorySection(AttendanceProvider prov) {
    if (prov.isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (prov.assignmentChangeLogs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6EEFF)),
        ),
        child: const Center(
          child: Text(
            'No hay registros de cambios recientes.',
            style: TextStyle(fontSize: 13, color: Color(0xFF74777E)),
          ),
        ),
      );
    }

    return Column(
      children: prov.assignmentChangeLogs.map((log) {
        final changeType = log['change_type']?.toString() ?? 'updated';
        Color badgeColor;
        Color badgeTextColor;
        String badgeText;

        switch (changeType) {
          case 'created':
            badgeColor = const Color(0xFFECFDF5);
            badgeTextColor = const Color(0xFF10B981);
            badgeText = 'Creado';
            break;
          case 'deleted':
            badgeColor = const Color(0xFFFEF2F2);
            badgeTextColor = const Color(0xFFEF4444);
            badgeText = 'Eliminado';
            break;
          case 'updated':
          default:
            badgeColor = const Color(0xFFEFF6FF);
            badgeTextColor = const Color(0xFF3B82F6);
            badgeText = 'Modificado';
            break;
        }

        String formattedDate = '--';
        if (log['changed_at'] != null) {
          try {
            final parsed = DateTime.parse(log['changed_at'].toString()).toLocal();
            formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(parsed);
          } catch (_) {}
        }

        final userName = log['user_name'] ?? 'Empleado';
        final adminName = log['admin_name'] ?? 'Administrador';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE6EEFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF74777E)),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF74777E),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Color(0xFF0F2744)),
                  const SizedBox(width: 6),
                  Text(
                    'Empleado: ',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  Expanded(
                    child: Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF001229),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Color(0xFF0051D5)),
                  const SizedBox(width: 6),
                  Text(
                    'Por: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Expanded(
                    child: Text(
                      adminName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0051D5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return '--:--';
    final str = time.toString();
    if (str.length >= 5) return str.substring(0, 5);
    return str;
  }
}