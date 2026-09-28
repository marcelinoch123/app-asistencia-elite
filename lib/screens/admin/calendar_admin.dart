import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/custom_drawer.dart';

class CalendarAdmin extends StatefulWidget {
  const CalendarAdmin({super.key});

  @override
  State<CalendarAdmin> createState() => _CalendarAdminState();
}

class _CalendarAdminState extends State<CalendarAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  String _selectedType = 'full';
  final TextEditingController _descriptionController = TextEditingController();
  String? _existingWorkDayId;
  bool _isSaving = false;

  final Map<String, _TypeConfig> _typeConfigs = const {
    'full': _TypeConfig(
      label: 'Día laboral completo',
      shortLabel: 'Completo',
      color: Color(0xFF10B981),
      icon: Icons.check_circle_outline,
    ),
    'half': _TypeConfig(
      label: 'Medio día',
      shortLabel: 'Medio día',
      color: Color(0xFFF59E0B),
      icon: Icons.timelapse,
    ),
    'holiday': _TypeConfig(
      label: 'Feriado',
      shortLabel: 'Feriado',
      color: Color(0xFFEF4444),
      icon: Icons.celebration,
    ),
    'non_working': _TypeConfig(
      label: 'No laborable',
      shortLabel: 'No laborable',
      color: Color(0xFF6B7280),
      icon: Icons.block,
    ),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthData(_focusedDay);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMonthData(DateTime month) async {
    if (!mounted) return;
    final provider = context.read<AttendanceProvider>();
    await provider.fetchWorkDays(month);
    _syncSelectedDayData();
  }

  void _syncSelectedDayData() {
    final provider = context.read<AttendanceProvider>();
    final workDay = provider.getWorkDayForDate(_selectedDay);

    setState(() {
      if (workDay != null) {
        _existingWorkDayId = workDay['id']?.toString();
        _selectedType = workDay['type']?.toString() ?? 'full';
        _descriptionController.text = workDay['description']?.toString() ?? '';
      } else {
        _existingWorkDayId = null;
        _selectedType = 'full';
        _descriptionController.clear();
      }
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _syncSelectedDayData();
  }

  Future<void> _saveDayConfiguration() async {
    setState(() => _isSaving = true);
    final provider = context.read<AttendanceProvider>();

    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    final success = await provider.setWorkDay(
      _selectedDay,
      _selectedType,
      description,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      _syncSelectedDayData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Día ${DateFormat('dd/MM/yyyy').format(_selectedDay)} configurado como ${_typeConfigs[_selectedType]?.label ?? _selectedType}',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Error al guardar configuración'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteDayConfiguration() async {
    if (_existingWorkDayId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar configuración'),
          ],
        ),
        content: Text(
          '¿Deseas eliminar la configuración especial para el día ${DateFormat('dd/MM/yyyy').format(_selectedDay)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    final provider = context.read<AttendanceProvider>();
    final success = await provider.deleteWorkDay(_existingWorkDayId!, _focusedDay);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      _syncSelectedDayData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Configuración eliminada para el ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
          ),
          backgroundColor: const Color(0xFF0F2744),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Error al eliminar configuración'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color? _getColorForDay(DateTime day, AttendanceProvider provider) {
    final workDay = provider.getWorkDayForDate(day);
    if (workDay == null) return null;
    final type = workDay['type'] as String?;
    return _typeConfigs[type]?.color;
  }

  String _formatSpanishDate(DateTime date) {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    const months = [
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
      'Diciembre'
    ];

    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} de $monthName de ${date.year}';
  }

  String _formatSpanishMonthYear(DateTime date) {
    const months = [
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
      'Diciembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

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
          'Calendario Laboral',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F2744)),
            tooltip: 'Recargar días',
            onPressed: () => _loadMonthData(_focusedDay),
          ),
        ],
      ),
      body: provider.isWorkDaysLoading && provider.workDays.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ========================================================
                  // TARJETA PRINCIPAL DEL CALENDARIO
                  // ========================================================
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                    child: TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      currentDay: DateTime.now(),
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: _onDaySelected,
                      onPageChanged: (focused) {
                        setState(() => _focusedDay = focused);
                        _loadMonthData(focused);
                      },
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextFormatter: (date, locale) =>
                            _formatSpanishMonthYear(date),
                        titleTextStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F2744),
                        ),
                        leftChevronIcon: const Icon(
                          Icons.chevron_left,
                          color: Color(0xFF0F2744),
                        ),
                        rightChevronIcon: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF0F2744),
                        ),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF44474D),
                        ),
                        weekendStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          return _buildCalendarCell(day, provider);
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _buildCalendarCell(day, provider, isToday: true);
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return _buildCalendarCell(day, provider, isSelected: true);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ========================================================
                  // LEYENDA DE COLORES
                  // ========================================================
                  Container(
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
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildLegendItem(const Color(0xFF10B981), 'Laboral completo'),
                        _buildLegendItem(const Color(0xFFF59E0B), 'Medio día'),
                        _buildLegendItem(const Color(0xFFEF4444), 'Feriado'),
                        _buildLegendItem(const Color(0xFF6B7280), 'No laborable'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ========================================================
                  // PANEL INFERIOR DE CONFIGURACIÓN DEL DÍA SELECCIONADO
                  // ========================================================
                  _buildDayEditPanel(provider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendarCell(
    DateTime day,
    AttendanceProvider provider, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    final color = _getColorForDay(day, provider);
    final isSelectedDay = isSelected || isSameDay(_selectedDay, day);
    final isCurrentDay = isToday || isSameDay(DateTime.now(), day);

    BoxDecoration decoration;

    if (color != null) {
      // Tiene tipo configurado
      decoration = BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isSelectedDay
            ? Border.all(color: const Color(0xFF0051D5), width: 3)
            : (isCurrentDay
                ? Border.all(color: const Color(0xFF0F2744), width: 2)
                : null),
        boxShadow: isSelectedDay
            ? [
                BoxShadow(
                  color: const Color(0xFF0051D5).withOpacity(0.35),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      );
    } else if (isSelectedDay) {
      // Seleccionado pero sin configuración especial
      decoration = BoxDecoration(
        color: const Color(0xFF0051D5),
        shape: BoxShape.circle,
        border: isCurrentDay
            ? Border.all(color: const Color(0xFF0F2744), width: 2)
            : null,
      );
    } else if (isCurrentDay) {
      // Hoy sin configuración especial
      decoration = BoxDecoration(
        color: const Color(0xFF0051D5).withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0051D5), width: 1.5),
      );
    } else {
      // Día regular
      decoration = const BoxDecoration(
        shape: BoxShape.circle,
      );
    }

    Color textColor;
    if (color != null || isSelectedDay) {
      textColor = Colors.white;
    } else if (isCurrentDay) {
      textColor = const Color(0xFF0051D5);
    } else if (day.weekday == DateTime.sunday) {
      textColor = const Color(0xFFEF4444);
    } else {
      textColor = const Color(0xFF0D1C2F);
    }

    return Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: decoration,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontWeight: isSelectedDay || isCurrentDay || color != null
              ? FontWeight.w700
              : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF44474D),
          ),
        ),
      ],
    );
  }

  Widget _buildDayEditPanel(AttendanceProvider provider) {
    final existingWorkDay = provider.getWorkDayForDate(_selectedDay);
    final hasConfig = existingWorkDay != null;

    return Container(
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
          // Título con la fecha seleccionada
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2744),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatSpanishDate(_selectedDay),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF001229),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          hasConfig
                              ? 'Configurado: ${_typeConfigs[existingWorkDay['type']]?.shortLabel ?? existingWorkDay['type']}'
                              : 'Sin configuración especial',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: hasConfig
                                ? (_typeConfigs[existingWorkDay['type']]?.color ??
                                    const Color(0xFF0051D5))
                                : const Color(0xFF74777E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasConfig)
                IconButton(
                  tooltip: 'Eliminar configuración',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _isSaving ? null : _deleteDayConfiguration,
                ),
            ],
          ),
          const Divider(height: 24),

          const Text(
            'TIPO DE DÍA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF44474D),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Selector de los 4 tipos de día
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: _typeConfigs.entries.map((entry) {
              final typeKey = entry.key;
              final config = entry.value;
              final isSelected = _selectedType == typeKey;

              return InkWell(
                onTap: () {
                  setState(() => _selectedType = typeKey);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? config.color.withOpacity(0.12)
                        : const Color(0xFFF8F9FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? config.color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        config.icon,
                        color: config.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          config.shortLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF001229)
                                : const Color(0xFF44474D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Campo de descripción opcional
          const Text(
            'DESCRIPCIÓN / MOTIVO (OPCIONAL)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF44474D),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Ej. Feriado Nacional, Inventario general, etc.',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
              filled: true,
              fillColor: const Color(0xFFF8F9FF),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF0051D5), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Botón de guardar
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveDayConfiguration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2744),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      hasConfig ? 'Actualizar Configuración' : 'Guardar Configuración',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeConfig {
  final String label;
  final String shortLabel;
  final Color color;
  final IconData icon;

  const _TypeConfig({
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.icon,
  });
}
