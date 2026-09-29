import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/supabase_client.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/custom_drawer.dart';

enum DailyAssignmentStatus {
  pendiente,
  enCurso,
  completado,
  ausente,
}

class DailyAssignmentItem {
  final String id;
  final String assignedDate;
  final String employeeName;
  final String employeeEmail;
  final String shiftName;
  final String startTime;
  final String endTime;
  final String clientName;
  final String clientAddress;
  final String supervisorName;
  final dynamic checkIn;
  final dynamic checkOut;
  final String? rawStatus;
  final bool autoCheckOut;
  final bool checkOutPhotoMissing;
  final String? checkOutPhotoUrl;

  DailyAssignmentItem({
    required this.id,
    required this.assignedDate,
    required this.employeeName,
    required this.employeeEmail,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.clientName,
    required this.clientAddress,
    required this.supervisorName,
    this.checkIn,
    this.checkOut,
    this.rawStatus,
    this.autoCheckOut = false,
    this.checkOutPhotoMissing = false,
    this.checkOutPhotoUrl,
  });

  DailyAssignmentStatus get status {
    if (checkIn != null && checkOut != null) {
      return DailyAssignmentStatus.completado;
    }
    if (checkIn != null && checkOut == null) {
      return DailyAssignmentStatus.enCurso;
    }

    // Sin check_in registrado
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? itemDate;
    try {
      itemDate = DateTime.parse(assignedDate);
    } catch (_) {
      itemDate = today;
    }
    final itemDateOnly = DateTime(itemDate.year, itemDate.month, itemDate.day);

    if (itemDateOnly.isBefore(today)) {
      return DailyAssignmentStatus.ausente;
    } else if (itemDateOnly.isAfter(today)) {
      return DailyAssignmentStatus.pendiente;
    } else {
      // Es hoy: verificar si ya venció el horario del turno o si está marcado ausente
      if (rawStatus == 'absent') {
        return DailyAssignmentStatus.ausente;
      }
      if (endTime.isNotEmpty) {
        try {
          final parts = endTime.split(':');
          final endH = int.parse(parts[0]);
          final endM = int.parse(parts[1]);
          final shiftEndTime = DateTime(now.year, now.month, now.day, endH, endM);
          if (now.isAfter(shiftEndTime)) {
            return DailyAssignmentStatus.ausente;
          }
        } catch (_) {}
      }
      return DailyAssignmentStatus.pendiente;
    }
  }
}

class DailyAssignmentsAdmin extends StatefulWidget {
  const DailyAssignmentsAdmin({super.key});

  @override
  State<DailyAssignmentsAdmin> createState() => _DailyAssignmentsAdminState();
}

class _DailyAssignmentsAdminState extends State<DailyAssignmentsAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _errorMessage;
  List<DailyAssignmentItem> _assignments = [];

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  Future<void> _fetchAssignments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      try {
        await context.read<AttendanceProvider>().autoCheckOutExpiredShifts();
      } catch (_) {}

      // Ejecutar consultas concurrentes hacia Supabase
      final results = await Future.wait([
        SupabaseConfig.client
            .from('shift_assignments')
            .select('id, assigned_date, user_id, shift_id, client_id, supervisor_id')
            .eq('assigned_date', dateStr),
        SupabaseConfig.client
            .from('attendances')
            .select('user_id, shift_id, check_in, check_out, status, check_out_photo_url, check_out_photo_missing, auto_check_out')
            .eq('date', dateStr),
        SupabaseConfig.client
            .from('users')
            .select('id, full_name, name, email'),
        SupabaseConfig.client
            .from('shifts')
            .select('id, name, start_time, end_time'),
        SupabaseConfig.client
            .from('clients')
            .select('id, name, address'),
      ]);

      final assignmentsData = List<Map<String, dynamic>>.from(results[0]);
      final attendancesData = List<Map<String, dynamic>>.from(results[1]);
      final usersData = List<Map<String, dynamic>>.from(results[2]);
      final shiftsData = List<Map<String, dynamic>>.from(results[3]);
      final clientsData = List<Map<String, dynamic>>.from(results[4]);

      final Map<String, Map<String, dynamic>> usersMap = {
        for (final u in usersData) u['id']?.toString() ?? '': u
      };
      final Map<String, Map<String, dynamic>> shiftsMap = {
        for (final s in shiftsData) s['id']?.toString() ?? '': s
      };
      final Map<String, Map<String, dynamic>> clientsMap = {
        for (final c in clientsData) c['id']?.toString() ?? '': c
      };

      final Map<String, Map<String, dynamic>> attendancesMap = {};
      for (final a in attendancesData) {
        final uId = a['user_id']?.toString() ?? '';
        final sId = a['shift_id']?.toString() ?? '';
        attendancesMap['${uId}_$sId'] = a;
        attendancesMap.putIfAbsent(uId, () => a);
      }

      final List<DailyAssignmentItem> items = [];
      for (final sa in assignmentsData) {
        final uId = sa['user_id']?.toString() ?? '';
        final sId = sa['shift_id']?.toString() ?? '';
        final cId = sa['client_id']?.toString() ?? '';
        final supId = sa['supervisor_id']?.toString() ?? '';

        final user = usersMap[uId];
        final shift = shiftsMap[sId];
        final client = clientsMap[cId];
        final supervisor = usersMap[supId];
        final att = attendancesMap['${uId}_$sId'] ?? attendancesMap[uId];

        final empName = user?['full_name']?.toString() ??
            user?['name']?.toString() ??
            'Empleado';
        final empEmail = user?['email']?.toString() ?? '';
        final shiftName = shift?['name']?.toString() ?? 'Turno';
        final startTime = shift?['start_time']?.toString() ?? '';
        final endTime = shift?['end_time']?.toString() ?? '';
        final clientName = client?['name']?.toString() ?? 'Sin cliente';
        final clientAddress = client?['address']?.toString() ?? 'Sin dirección';
        final supName = supervisor?['full_name']?.toString() ??
            supervisor?['name']?.toString() ??
            'No asignado';

        final autoCheckOut = att?['auto_check_out'] == true;
        final checkOutPhotoMissing = att?['check_out_photo_missing'] == true;
        final checkOutPhotoUrl = att?['check_out_photo_url']?.toString();

        items.add(DailyAssignmentItem(
          id: sa['id']?.toString() ?? '',
          assignedDate: sa['assigned_date']?.toString() ?? dateStr,
          employeeName: empName,
          employeeEmail: empEmail,
          shiftName: shiftName,
          startTime: startTime,
          endTime: endTime,
          clientName: clientName,
          clientAddress: clientAddress,
          supervisorName: supName,
          checkIn: att?['check_in'],
          checkOut: att?['check_out'],
          rawStatus: att?['status']?.toString(),
          autoCheckOut: autoCheckOut,
          checkOutPhotoMissing: checkOutPhotoMissing,
          checkOutPhotoUrl: checkOutPhotoUrl,
        ));
      }

      // ORDER BY s.start_time, u.full_name
      items.sort((a, b) {
        final startCmp = a.startTime.compareTo(b.startTime);
        if (startCmp != 0) return startCmp;
        return a.employeeName.toLowerCase().compareTo(b.employeeName.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _assignments = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al consultar asignaciones: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onDateChanged(DateTime newDate) {
    setState(() => _selectedDate = newDate);
    _fetchAssignments();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F2744),
              onPrimary: Colors.white,
              onSurface: Color(0xFF001229),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      _onDateChanged(picked);
    }
  }

  String _formatTimeDisplay(dynamic val) {
    if (val == null) return '--:--';
    final s = val.toString().trim();
    if (s.isEmpty) return '--:--';
    final dt = DateTime.tryParse(s);
    if (dt != null) {
      return DateFormat('HH:mm').format(dt.toLocal());
    }
    if (s.length >= 5) return s.substring(0, 5);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    final totalCount = _assignments.length;
    final completadosCount = _assignments
        .where((a) => a.status == DailyAssignmentStatus.completado)
        .length;
    final enCursoCount = _assignments
        .where((a) => a.status == DailyAssignmentStatus.enCurso)
        .length;
    final ausentesCount = _assignments
        .where((a) => a.status == DailyAssignmentStatus.ausente)
        .length;
    final pendientesCount = _assignments
        .where((a) => a.status == DailyAssignmentStatus.pendiente)
        .length;

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
          'Asignaciones del Día',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
        actions: [
          if (!isToday)
            TextButton.icon(
              onPressed: () => _onDateChanged(DateTime.now()),
              icon: const Icon(Icons.today, size: 16, color: Color(0xFF0051D5)),
              label: const Text(
                'Hoy',
                style: TextStyle(
                  color: Color(0xFF0051D5),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F2744)),
            tooltip: 'Actualizar',
            onPressed: _fetchAssignments,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Selector de Fecha
          _buildDateSelector(),

          // Contador e Indicadores
          _buildCounterHeader(
            total: totalCount,
            completados: completadosCount,
            enCurso: enCursoCount,
            ausentes: ausentesCount,
            pendientes: pendientesCount,
          ),

          // Lista de tarjetas
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAssignments,
              color: const Color(0xFF0F2744),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _assignments.isEmpty
                          ? _buildEmptyView()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: _assignments.length,
                              itemBuilder: (context, index) {
                                return _buildAssignmentCard(_assignments[index]);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final dateDisplay = DateFormat('EEEE d, MMMM yyyy', 'es').format(_selectedDate);
    final capitalized = dateDisplay.isNotEmpty
        ? '${dateDisplay[0].toUpperCase()}${dateDisplay.substring(1)}'
        : dateDisplay;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF0F2744)),
            tooltip: 'Día anterior',
            onPressed: () => _onDateChanged(
              _selectedDate.subtract(const Duration(days: 1)),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF0051D5),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        capitalized,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF001229),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF0F2744)),
            tooltip: 'Día siguiente',
            onPressed: () => _onDateChanged(
              _selectedDate.add(const Duration(days: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterHeader({
    required int total,
    required int completados,
    required int enCurso,
    required int ausentes,
    required int pendientes,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$total ${total == 1 ? 'empleado asignado' : 'empleados asignados'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F2744),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSummaryBadge(
                  label: 'Completados',
                  count: completados,
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                ),
                const SizedBox(width: 8),
                _buildSummaryBadge(
                  label: 'En curso',
                  count: enCurso,
                  color: const Color(0xFF0051D5),
                  bgColor: const Color(0xFFEFF6FF),
                ),
                const SizedBox(width: 8),
                _buildSummaryBadge(
                  label: 'Ausentes',
                  count: ausentes,
                  color: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2),
                ),
                const SizedBox(width: 8),
                _buildSummaryBadge(
                  label: 'Pendientes',
                  count: pendientes,
                  color: const Color(0xFF64748B),
                  bgColor: const Color(0xFFF1F5F9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(DailyAssignmentItem item) {
    final statusBadge = _buildStatusBadge(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Nombre y Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF001229),
                        ),
                      ),
                      if (item.employeeEmail.isNotEmpty)
                        Text(
                          item.employeeEmail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                statusBadge,
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),

            // Turno con horarios
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF0051D5),
              label: 'Turno',
              value: '${item.shiftName} (${_formatTimeDisplay(item.startTime)} - ${_formatTimeDisplay(item.endTime)})',
            ),
            const SizedBox(height: 8),

            // Cliente y dirección
            _buildDetailRow(
              icon: Icons.business_outlined,
              iconColor: const Color(0xFF0F2744),
              label: 'Cliente',
              value: item.clientName,
              subValue: item.clientAddress != 'Sin dirección' ? item.clientAddress : null,
            ),
            const SizedBox(height: 8),

            // Supervisor
            _buildDetailRow(
              icon: Icons.supervisor_account_outlined,
              iconColor: const Color(0xFF64748B),
              label: 'Supervisor',
              value: item.supervisorName,
            ),

            // Marcas de asistencia si existen
            if (item.checkIn != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.login, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      'Entrada: ${_formatTimeDisplay(item.checkIn)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F2744),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.logout, size: 14, color: Color(0xFF0051D5)),
                    const SizedBox(width: 4),
                    Text(
                      'Salida: ${_formatTimeDisplay(item.checkOut)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F2744),
                      ),
                    ),
                    if (item.autoCheckOut) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Auto',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                    if (item.checkOutPhotoMissing) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Sin foto',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ] else if (item.checkOutPhotoUrl != null && item.checkOutPhotoUrl!.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      IconButton(
                        icon: const Icon(Icons.camera_alt, size: 15, color: Color(0xFF0051D5)),
                        tooltip: 'Ver foto de salida',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showPhotoDialog(
                          item.checkOutPhotoUrl!,
                          'Foto de Salida - ${item.employeeName}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF001229),
                ),
              ),
              if (subValue != null && subValue.isNotEmpty)
                Text(
                  subValue,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(DailyAssignmentStatus status) {
    Color textColor;
    Color bgColor;
    String label;
    IconData icon;

    switch (status) {
      case DailyAssignmentStatus.completado:
        label = 'Completado';
        textColor = const Color(0xFF10B981);
        bgColor = const Color(0xFFECFDF5);
        icon = Icons.check_circle_outline;
        break;
      case DailyAssignmentStatus.enCurso:
        label = 'En curso';
        textColor = const Color(0xFF0051D5);
        bgColor = const Color(0xFFEFF6FF);
        icon = Icons.play_circle_outline;
        break;
      case DailyAssignmentStatus.ausente:
        label = 'Ausente';
        textColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFFEF2F2);
        icon = Icons.cancel_outlined;
        break;
      case DailyAssignmentStatus.pendiente:
        label = 'Pendiente';
        textColor = const Color(0xFF64748B);
        bgColor = const Color(0xFFF1F5F9);
        icon = Icons.schedule;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_late_outlined,
                size: 64,
                color: const Color(0xFF64748B).withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No hay asignaciones para esta fecha',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF001229),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona otro día o asigna turnos a tus empleados desde "Asignar Turnos".',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Ocurrió un error inesperado',
              style: const TextStyle(fontSize: 14, color: Color(0xFF001229)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchAssignments,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2744),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoDialog(String photoUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('No se pudo cargar la foto'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
