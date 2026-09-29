import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/supabase_client.dart';
import '../../models/user_model.dart';
import '../../providers/attendance_provider.dart';
import '../../models/report_detail_model.dart';
import '../../services/export_service.dart';
import '../../widgets/custom_drawer.dart';

class ReportsAdmin extends StatefulWidget {
  const ReportsAdmin({super.key});

  @override
  State<ReportsAdmin> createState() => _ReportsAdminState();
}

class _ReportsAdminState extends State<ReportsAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _selectedEmployeeId;
  late int _selectedMonth;
  late int _selectedYear;

  bool _isLoadingEmployees = true;
  bool _isLoadingReport = false;
  bool _isExporting = false;
  String? _errorMessage;

  Map<String, dynamic>? _summaryData;
  List<DailyReportDetail> _dailyDetails = [];

  final List<String> _months = [
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
    'Diciembre',
  ];

  late List<int> _years;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _years = [now.year - 1, now.year, now.year + 1];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmployees();
    });
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoadingEmployees = true);
    try {
      final attProvider = context.read<AttendanceProvider>();
      await attProvider.fetchAllEmployees();

      final employees = attProvider.allEmployees
          .where((u) => u.role == 'employee' || u.isEmployee)
          .toList();

      if (mounted) {
        setState(() {
          if (employees.isNotEmpty && _selectedEmployeeId == null) {
            _selectedEmployeeId = employees.first.id;
          }
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
          _errorMessage = 'Error al cargar empleados: $e';
        });
      }
    }
  }

  Future<void> _generateReport() async {
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un empleado')),
      );
      return;
    }

    setState(() {
      _isLoadingReport = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final targetMonthStart = DateTime(_selectedYear, _selectedMonth, 1);

      if (targetMonthStart.isAfter(currentMonthStart)) {
        setState(() {
          _isLoadingReport = false;
          _summaryData = null;
          _dailyDetails = [];
          _errorMessage = 'No es posible generar reportes para meses futuros.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No es posible generar reportes para meses futuros'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final attProvider = context.read<AttendanceProvider>();
      await attProvider.autoCheckOutExpiredShifts();
      final summary = await attProvider.calculateMonthlySummary(
        _selectedEmployeeId!,
        _selectedMonth,
        _selectedYear,
      );

      if (summary.isEmpty) {
        setState(() {
          _isLoadingReport = false;
          _errorMessage = 'No se pudo obtener el resumen para este periodo.';
        });
        return;
      }

      final lastDayOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      final endDayToCheck = (_selectedYear == now.year && _selectedMonth == now.month)
          ? now.day
          : lastDayOfMonth;

      final startStr =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-01';
      final endStr =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${lastDayOfMonth.toString().padLeft(2, '0')}';

      // 1. Asistencias registradas
      final attResponse = await SupabaseConfig.client
          .from('attendances')
          .select()
          .eq('user_id', _selectedEmployeeId!)
          .gte('date', startStr)
          .lte('date', endStr)
          .order('date', ascending: true);

      final attendancesList = List<Map<String, dynamic>>.from(attResponse);

      // 2. Feriados y días no laborables
      final workDaysResponse = await SupabaseConfig.client
          .from('work_days')
          .select()
          .gte('date', startStr)
          .lte('date', endStr);

      final workDaysMap = <String, String>{};
      for (final wd in workDaysResponse) {
        final d = wd['date']?.toString();
        final t = wd['type']?.toString();
        if (d != null && t != null) {
          workDaysMap[d] = t;
        }
      }

      // 3. Permisos
      final permResponse = await SupabaseConfig.client
          .from('permissions')
          .select()
          .eq('user_id', _selectedEmployeeId!)
          .lte('start_date', endStr)
          .gte('end_date', startStr);

      final permissionsList = List<Map<String, dynamic>>.from(permResponse);

      // 4. Turnos asignados y catálogo de turnos
      final assignResponse = await SupabaseConfig.client
          .from('shift_assignments')
          .select('assigned_date, shift_id')
          .eq('user_id', _selectedEmployeeId!)
          .gte('assigned_date', startStr)
          .lte('assigned_date', endStr);

      final shiftsResponse = await SupabaseConfig.client
          .from('shifts')
          .select('id, name, start_time, end_time');

      final shiftsMap = <String, String>{};
      for (final s in shiftsResponse) {
        final sId = s['id']?.toString();
        final start = s['start_time']?.toString() ?? '';
        final end = s['end_time']?.toString() ?? '';
        if (sId != null) {
          shiftsMap[sId] = '$start - $end';
        }
      }

      final assignedDates = <String>{};
      final dateShiftScheduleMap = <String, String>{};
      for (final a in assignResponse) {
        String? aDate = a['assigned_date']?.toString();
        final sId = a['shift_id']?.toString();
        if (aDate != null && sId != null) {
          if (aDate.length >= 10) aDate = aDate.substring(0, 10);
          assignedDates.add(aDate);
          dateShiftScheduleMap[aDate] = shiftsMap[sId] ?? 'Asignado';
        }
      }

      // 5. Armar detalle diario
      final List<DailyReportDetail> details = [];

      for (int d = 1; d <= endDayToCheck; d++) {
        final currentDay = DateTime(_selectedYear, _selectedMonth, d);
        final dateStr =
            '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

        final matchingAtt = attendancesList.firstWhere(
          (a) {
            String? aDate = a['date']?.toString();
            if (aDate != null && aDate.length >= 10) {
              aDate = aDate.substring(0, 10);
            }
            return aDate == dateStr && a['check_in'] != null;
          },
          orElse: () => {},
        );

        final shiftSchedule = dateShiftScheduleMap[dateStr] ?? '—';

        if (matchingAtt.isNotEmpty) {
          final lateMin = (matchingAtt['late_minutes'] as num?)?.toInt() ?? 0;
          final tolMin =
              (matchingAtt['tolerance_minutes_used'] as num?)?.toInt() ?? 0;
          final earlyMin =
              (matchingAtt['early_leave_minutes'] as num?)?.toInt() ?? 0;
          final lateFee = (matchingAtt['late_fee'] as num?)?.toDouble() ?? 0.0;
          final checkInStr = _formatTimeToBolivia(matchingAtt['check_in']);
          final checkOutStr = matchingAtt['check_out'] != null
              ? _formatTimeToBolivia(matchingAtt['check_out'])
              : 'En curso';

          final lat = matchingAtt['location_lat'];
          final lng = matchingAtt['location_lng'];
          final coordinates = (lat != null && lng != null) ? '$lat, $lng' : '—';

          final status = lateMin > 0 ? 'Tarde' : 'Presente';

          final autoCheckOut = matchingAtt['auto_check_out'] == true;
          final checkOutPhotoMissing = matchingAtt['check_out_photo_missing'] == true;
          final checkOutPhotoUrl = matchingAtt['check_out_photo_url'] as String?;

          details.add(DailyReportDetail(
            dateStr: dateStr,
            date: currentDay,
            checkIn: checkInStr,
            checkOut: checkOutStr,
            lateMinutes: lateMin,
            toleranceMinutes: tolMin,
            earlyLeaveMinutes: earlyMin,
            status: status,
            shiftSchedule: shiftSchedule,
            coordinates: coordinates,
            discount: lateFee,
            autoCheckOut: autoCheckOut,
            checkOutPhotoMissing: checkOutPhotoMissing,
            checkOutPhotoUrl: checkOutPhotoUrl,
          ));
        } else {
          String status;
          if (currentDay.weekday == DateTime.sunday) {
            status = 'Domingo';
          } else if (workDaysMap[dateStr] == 'holiday') {
            status = 'Feriado';
          } else if (workDaysMap[dateStr] == 'non_working') {
            status = 'No laborable';
          } else {
            bool hasPerm = false;
            for (final p in permissionsList) {
              final pStart = p['start_date']?.toString();
              final pEnd = p['end_date']?.toString();
              if (pStart != null && pEnd != null) {
                if (dateStr.compareTo(pStart) >= 0 &&
                    dateStr.compareTo(pEnd) <= 0) {
                  hasPerm = true;
                  break;
                }
              }
            }

            if (hasPerm) {
              status = 'Permiso';
            } else if (!assignedDates.contains(dateStr)) {
              status = 'Sin turno';
            } else {
              status = 'Falta';
            }
          }

          final double discount = (status == 'Falta') ? 200.0 : 0.0;

          details.add(DailyReportDetail(
            dateStr: dateStr,
            date: currentDay,
            checkIn: '--:--',
            checkOut: '--:--',
            lateMinutes: 0,
            toleranceMinutes: 0,
            earlyLeaveMinutes: 0,
            status: status,
            shiftSchedule: shiftSchedule,
            coordinates: '—',
            discount: discount,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _summaryData = summary;
          _dailyDetails = details;
          _isLoadingReport = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReport = false;
          _errorMessage = 'Error al generar reporte: $e';
        });
      }
    }
  }

  Future<void> _exportReport() async {
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un colaborador antes de exportar.'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      if (_summaryData == null || _dailyDetails.isEmpty) {
        await _generateReport();
      }

      if (_summaryData == null || _dailyDetails.isEmpty) {
        throw Exception('No se encontraron datos para generar el reporte.');
      }

      if (!mounted) return;
      final attProvider = context.read<AttendanceProvider>();
      final employee = attProvider.allEmployees.firstWhere(
        (u) => u.id == _selectedEmployeeId,
        orElse: () => throw Exception('Colaborador no encontrado'),
      );

      await ExportService.exportMonthlyReportToExcel(
        employee: employee,
        month: _selectedMonth,
        year: _selectedYear,
        summary: _summaryData!,
        dailyDetails: _dailyDetails,
      );

      if (mounted) {
        const successMessage = kIsWeb
            ? 'Reporte en Excel descargado exitosamente.'
            : 'Reporte en Excel generado. Abriendo opciones para compartir...';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(successMessage),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar reporte: $e'),
            backgroundColor: const Color(0xFFE53E3E),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _formatTimeToBolivia(dynamic timeValue) {
    if (timeValue == null) return '--:--';
    DateTime? dt;
    if (timeValue is DateTime) {
      dt = timeValue.toUtc();
    } else if (timeValue is String) {
      String s = timeValue.trim();
      if (s.isEmpty) return '--:--';
      if (!s.endsWith('Z') && !RegExp(r'[+-]\d{2}(:\d{2})?$').hasMatch(s)) {
        s = s.contains('T') ? '${s}Z' : '${s.replaceAll(' ', 'T')}Z';
      }
      dt = DateTime.tryParse(s)?.toUtc();
    }
    if (dt == null) return '--:--';
    final boliviaTime = dt.subtract(const Duration(hours: 4));
    final h = boliviaTime.hour.toString().padLeft(2, '0');
    final m = boliviaTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    final attProvider = context.watch<AttendanceProvider>();
    final employees = attProvider.allEmployees
        .where((u) => u.role == 'employee' || u.isEmployee)
        .toList();

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
          'Reportes de Asistencia',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0F2744),
                    ),
                  )
                : const Icon(Icons.file_download_outlined, color: Color(0xFF0F2744)),
            tooltip: 'Exportar Reporte a Excel',
            onPressed: (_isLoadingReport || _isExporting) ? null : _exportReport,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingEmployees
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(employees),
                  const SizedBox(height: 16),
                  if (_isLoadingReport)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    _buildErrorCard(_errorMessage!)
                  else if (_summaryData != null) ...[
                    _buildTotalsSection(_summaryData!),
                    const SizedBox(height: 24),
                    _buildDetailTable(),
                    const SizedBox(height: 24),
                  ] else
                    _buildInitialPlaceholder(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterSection(List<UserModel> employees) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GENERAR REPORTE MENSUAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0051D5),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          // Selector de Empleado
          const Text(
            'Colaborador',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1C2F),
            ),
          ),
          const SizedBox(height: 6),
          if (employees.isEmpty)
            const Text(
              'No hay empleados con rol "employee" registrados.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedEmployeeId,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              items: employees.map((emp) {
                return DropdownMenuItem<String>(
                  value: emp.id,
                  child: Text(
                    '${emp.fullName} (${emp.email})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF001229),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedEmployeeId = val);
                }
              },
            ),
          const SizedBox(height: 14),
          // Fila Mes y Año
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D1C2F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedMonth,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      items: List.generate(12, (index) {
                        final monthNum = index + 1;
                        return DropdownMenuItem<int>(
                          value: monthNum,
                          child: Text(
                            _months[index],
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedMonth = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Año',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D1C2F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedYear,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      items: _years.map((year) {
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text(
                            '$year',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedYear = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Botones Generar y Exportar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingReport ? null : _generateReport,
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text(
                    'Generar Reporte',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2744),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: (_isLoadingReport || _isExporting) ? null : _exportReport,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0F2744),
                        ),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(_isExporting ? 'Exportando...' : 'Exportar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F2744),
                  side: const BorderSide(color: Color(0xFF0F2744)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(Map<String, dynamic> summary) {
    final totalLateMinutes = summary['total_late_minutes'] ?? 0;
    final totalLateFee = (summary['total_late_fee'] as num?)?.toDouble() ?? 0.0;
    final totalTolMinutes = summary['total_tolerance_minutes'] ?? 0;
    final totalAccumFee =
        (summary['total_accumulated_fee'] as num?)?.toDouble() ?? 0.0;
    final totalAbsences = summary['total_absences'] ?? 0;
    final totalAbsenceFee =
        (summary['total_absence_fee'] as num?)?.toDouble() ?? 0.0;
    final totalEarlyMinutes = summary['total_early_leave_minutes'] ?? 0;
    final grandTotalFee =
        (summary['grand_total_fee'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RESUMEN MENSUAL: ${_months[_selectedMonth - 1].toUpperCase()} $_selectedYear',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF001229),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            // 1. Tardanzas
            _buildMetricCard(
              title: 'Tardanzas',
              value: '$totalLateMinutes min',
              subtitle: 'Descuento: Bs ${totalLateFee.toStringAsFixed(2)}',
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFF59E0B),
              iconBg: const Color(0xFFFEF3C7),
            ),
            // 2. Tolerancia acumulada
            _buildMetricCard(
              title: 'Tolerancia Usada',
              value: '$totalTolMinutes min',
              subtitle: 'De 60 min mensuales',
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFF0051D5),
              iconBg: const Color(0xFFDDE9FF),
            ),
            // 3. Penalidad tolerancia >= 60 min
            _buildMetricCard(
              title: 'Penalidad Tolerancia',
              value: totalAccumFee > 0
                  ? 'Bs ${totalAccumFee.toStringAsFixed(2)}'
                  : 'Bs 0.00',
              subtitle: totalAccumFee > 0
                  ? 'Aplica (>= 60 min)'
                  : 'Dentro del límite (< 60 min)',
              icon: Icons.gavel_outlined,
              iconColor: totalAccumFee > 0
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981),
              iconBg: totalAccumFee > 0
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFECFDF5),
            ),
            // 4. Faltas injustificadas
            _buildMetricCard(
              title: 'Faltas',
              value: '$totalAbsences faltas',
              subtitle: 'Descuento: Bs ${totalAbsenceFee.toStringAsFixed(2)}',
              icon: Icons.cancel_outlined,
              iconColor: const Color(0xFFEF4444),
              iconBg: const Color(0xFFFEE2E2),
            ),
            // 5. Salida anticipada
            _buildMetricCard(
              title: 'Salida Anticipada',
              value: '$totalEarlyMinutes min',
              subtitle: 'Antes de fin de turno',
              icon: Icons.logout,
              iconColor: const Color(0xFF8B5CF6),
              iconBg: const Color(0xFFEDE9FE),
            ),
            // 6. Estado de cumplimiento
            _buildMetricCard(
              title: 'Días Registrados',
              value: '${_dailyDetails.where((d) => d.status == 'Presente' || d.status == 'Tarde').length}',
              subtitle: 'Asistencias marcadas',
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFFECFDF5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Tarjeta destacada de Gran Total
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2744),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F2744).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFF6FFBBE),
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL A DESCONTAR',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Tardanzas + Tolerancia + Faltas',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                'Bs ${grandTotalFee.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF44474D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF001229),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DETALLE DÍA POR DÍA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF001229),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${_dailyDetails.length} días evaluados',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_dailyDetails.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No hay registros para este periodo.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                headingTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F2744),
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E293B),
                ),
                columnSpacing: 18,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Entrada')),
                  DataColumn(label: Text('Salida')),
                  DataColumn(label: Text('Tardanza')),
                  DataColumn(label: Text('Tolerancia')),
                  DataColumn(label: Text('Salida Ant.')),
                  DataColumn(label: Text('Estado')),
                ],
                rows: _dailyDetails.map((detail) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          _formatDate(detail.date),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(detail.checkIn)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(detail.checkOut),
                            if (detail.autoCheckOut) ...[
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
                            if (detail.checkOutPhotoMissing) ...[
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
                            ] else if (detail.checkOutPhotoUrl != null && detail.checkOutPhotoUrl!.isNotEmpty) ...[
                              const SizedBox(width: 2),
                              IconButton(
                                icon: const Icon(Icons.camera_alt, size: 16, color: Color(0xFF0051D5)),
                                tooltip: 'Ver foto de salida',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showPhotoDialog(
                                  detail.checkOutPhotoUrl!,
                                  'Foto de Salida - ${detail.dateStr}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          detail.lateMinutes > 0 ? '${detail.lateMinutes} min' : '-',
                          style: TextStyle(
                            color: detail.lateMinutes > 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF64748B),
                            fontWeight: detail.lateMinutes > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          detail.toleranceMinutes > 0
                              ? '${detail.toleranceMinutes} min'
                              : '-',
                          style: TextStyle(
                            color: detail.toleranceMinutes > 0
                                ? const Color(0xFF0051D5)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          detail.earlyLeaveMinutes > 0
                              ? '${detail.earlyLeaveMinutes} min'
                              : '-',
                          style: TextStyle(
                            color: detail.earlyLeaveMinutes > 0
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataCell(_buildStatusBadge(detail.status)),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Presente':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        break;
      case 'Tarde':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      case 'Falta':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      case 'Feriado':
      case 'No laborable':
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF334155);
        break;
      case 'Permiso':
        bg = const Color(0xFFDDE9FF);
        fg = const Color(0xFF0051D5);
        break;
      case 'Domingo':
      case 'Sin turno':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF87171)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFF991B1B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 48,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 12),
          Text(
            'Selecciona un colaborador y presiona "Generar Reporte"',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'Se calculará el resumen mensual con tardanzas, tolerancias, faltas y detalle diario.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
