import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/custom_drawer.dart';

class ShiftsAdmin extends StatefulWidget {
  const ShiftsAdmin({super.key});

  @override
  State<ShiftsAdmin> createState() => _ShiftsAdminState();
}

class _ShiftsAdminState extends State<ShiftsAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShifts();
    });
  }

  Future<void> _loadShifts() async {
    if (!mounted) return;
    await context.read<AttendanceProvider>().fetchShifts();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final shifts = provider.shifts;

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
          'Gestión de Turnos',
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
        label: const Text('Crear Turno'),
        onPressed: () => _showShiftDialog(context, null),
      ),
      body: provider.isShiftsLoading
          ? const Center(child: CircularProgressIndicator())
          : shifts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: shifts.length,
                  itemBuilder: (context, index) {
                    return _buildShiftCard(shifts[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 80, color: Color(0xFFD5E3FD)),
          const SizedBox(height: 16),
          const Text(
            'No hay turnos creados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF44474D),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Presiona "Crear Turno" para empezar',
            style: TextStyle(fontSize: 14, color: Color(0xFF74777E)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showShiftDialog(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Crear primer turno'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2744),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final days = (shift['days'] as List?)?.cast<String>() ?? [];

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
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2744),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schedule, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift['name'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF001229),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatTime(shift['start_time'])} - ${_formatTime(shift['end_time'])}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0051D5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: Color(0xFF0051D5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDays(days),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001229),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showShiftDialog(context, shift),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0051D5),
                    side: const BorderSide(color: Color(0xFF0051D5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(shift),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBA1A1A),
                    side: const BorderSide(color: Color(0xFFBA1A1A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return '--:--';
    final str = time.toString();
    if (str.length >= 5) return str.substring(0, 5);
    return str;
  }

  String _formatDays(List<String> days) {
    const dayNames = {
      'LUN': 'Lunes',
      'MAR': 'Martes',
      'MIE': 'Miércoles',
      'JUE': 'Jueves',
      'VIE': 'Viernes',
      'SAB': 'Sábado',
      'DOM': 'Domingo',
    };

    if (days.length == 5 &&
        days.contains('LUN') &&
        days.contains('VIE') &&
        !days.contains('SAB')) {
      return 'Lunes a Viernes';
    }
    if (days.length == 6 && !days.contains('DOM')) {
      return 'Lunes a Sábado';
    }
    if (days.length == 7) {
      return 'Lunes a Domingo';
    }
    return days.map((d) => dayNames[d] ?? d).join(', ');
  }

  void _showShiftDialog(BuildContext context, Map<String, dynamic>? shift) {
    final isEditing = shift != null;
    final nameCtrl = TextEditingController(
      text: isEditing ? shift['name']?.toString() ?? '' : '',
    );

    TimeOfDay startTime = isEditing
        ? _parseTime(shift['start_time'])
        : const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay endTime = isEditing
        ? _parseTime(shift['end_time'])
        : const TimeOfDay(hour: 15, minute: 0);

    List<String> selectedDays = isEditing
        ? (shift['days'] as List?)?.cast<String>() ??
            ['LUN', 'MAR', 'MIE', 'JUE', 'VIE']
        : ['LUN', 'MAR', 'MIE', 'JUE', 'VIE'];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit : Icons.add_circle,
                color: const Color(0xFF0F2744),
              ),
              const SizedBox(width: 8),
              Text(isEditing ? 'Editar Turno' : 'Nuevo Turno'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del turno',
                      hintText: 'Ej: Turno Mañana',
                      prefixIcon: Icon(Icons.label),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: startTime,
                      );
                      if (picked != null) {
                        setDialogState(() => startTime = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hora de inicio',
                        prefixIcon: Icon(Icons.login),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: endTime,
                      );
                      if (picked != null) {
                        setDialogState(() => endTime = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hora de finalización',
                        prefixIcon: Icon(Icons.logout),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Días de la semana',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF001229),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip(
                        label: 'LUN - VIE',
                        days: ['LUN', 'MAR', 'MIE', 'JUE', 'VIE'],
                        selectedDays: selectedDays,
                        onSelected: (days) {
                          setDialogState(() => selectedDays = days);
                        },
                      ),
                      _buildPresetChip(
                        label: 'LUN - SÁB',
                        days: ['LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB'],
                        selectedDays: selectedDays,
                        onSelected: (days) {
                          setDialogState(() => selectedDays = days);
                        },
                      ),
                      _buildPresetChip(
                        label: 'LUN - DOM',
                        days: ['LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB', 'DOM'],
                        selectedDays: selectedDays,
                        onSelected: (days) {
                          setDialogState(() => selectedDays = days);
                        },
                      ),
                      _buildPresetChip(
                        label: 'LUN - MIÉ - VIE',
                        days: ['LUN', 'MIE', 'VIE'],
                        selectedDays: selectedDays,
                        onSelected: (days) {
                          setDialogState(() => selectedDays = days);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'O selecciona días individuales:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF44474D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDayCheckbox('LUN', 'Lunes', selectedDays, (checked) {
                        setDialogState(() {
                          if (checked) {
                            selectedDays = [...selectedDays, 'LUN'];
                          } else {
                            selectedDays =
                                selectedDays.where((d) => d != 'LUN').toList();
                          }
                        });
                      }),
                      _buildDayCheckbox('MAR', 'Martes', selectedDays, (checked) {
                        setDialogState(() {
                          if (checked) {
                            selectedDays = [...selectedDays, 'MAR'];
                          } else {
                            selectedDays =
                                selectedDays.where((d) => d != 'MAR').toList();
                          }
                        });
                      }),
                      _buildDayCheckbox('MIE', 'Miércoles', selectedDays, (checked) {
                        setDialogState(() {
                          if (checked) {
                            selectedDays = [...selectedDays, 'MIE'];
                          } else {
                            selectedDays =
                                selectedDays.where((d) => d != 'MIE').toList();
                          }
                        });
                      }),
                      _buildDayCheckbox('JUE', 'Jueves', selectedDays, (checked) {
                        setDialogState(() {
                          if (checked) {
                            selectedDays = [...selectedDays, 'JUE'];
                          } else {
                            selectedDays =
                                selectedDays.where((d) => d != 'JUE').toList();
                          }
                        });
                      }),
                      _buildDayCheckbox('VIE', 'Viernes', selectedDays, (checked) {
                        setDialogState(() {
                          if (checked) {
                            selectedDays = [...selectedDays, 'VIE'];
                          } else {
                            selectedDays =
                                selectedDays.where((d) => d != 'VIE').toList();
                          }
                        });
                      }),
                      _buildDayCheckbox('SAB', 'Sábado', selectedDays, (checked) {
                        setDialogState(() {
                          if (checked) {
                            selectedDays = [...selectedDays, 'SAB'];
                          } else {
                            selectedDays =
                                selectedDays.where((d) => d != 'SAB').toList();
                          }
                        });
                      }),
                      _buildDayCheckbox('DOM', 'Domingo', selectedDays, (checked) {
                        setDialogState(() {
                          if (checked) {
                            selectedDays = [...selectedDays, 'DOM'];
                          } else {
                            selectedDays =
                                selectedDays.where((d) => d != 'DOM').toList();
                          }
                        });
                      }),
                    ],
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
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(
                        content: Text('Ingresa un nombre para el turno')),
                  );
                  return;
                }

                if (selectedDays.isEmpty) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(
                        content: Text('Selecciona al menos un día')),
                  );
                  return;
                }

                final provider = context.read<AttendanceProvider>();
                final startStr =
                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                final endStr =
                    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                bool success;
                if (isEditing) {
                  success = await provider.updateShift(
                    shiftId: shift['id'],
                    name: nameCtrl.text.trim(),
                    startTime: startStr,
                    endTime: endStr,
                    days: selectedDays,
                  );
                } else {
                  success = await provider.createShift(
                    name: nameCtrl.text.trim(),
                    startTime: startStr,
                    endTime: endStr,
                    days: selectedDays,
                  );
                }

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? (isEditing
                              ? '✅ Turno actualizado'
                              : '✅ Turno creado')
                          : '❌ Error al guardar'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2744),
              ),
              child: Text(isEditing ? 'Guardar cambios' : 'Crear turno'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required List<String> days,
    required List<String> selectedDays,
    required Function(List<String>) onSelected,
  }) {
    final isSelected = _listEquals(days, selectedDays);

    return GestureDetector(
      onTap: () => onSelected(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? const Color(0xFF0051D5) : const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0051D5) : const Color(0xFFD5E3FD),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF0051D5),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCheckbox(
    String code,
    String label,
    List<String> selectedDays,
    Function(bool) onChanged,
  ) {
    final isSelected = selectedDays.contains(code);

    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF10B981) : const Color(0xFFD5E3FD),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: isSelected
                  ? const Color(0xFF10B981)
                  : const Color(0xFF74777E),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF065F46)
                    : const Color(0xFF44474D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!b.contains(a[i])) return false;
    }
    return true;
  }

  TimeOfDay _parseTime(dynamic time) {
    if (time == null) return const TimeOfDay(hour: 7, minute: 0);
    final str = time.toString();
    final parts = str.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 7,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 7, minute: 0);
  }

  void _confirmDelete(Map<String, dynamic> shift) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Turno'),
        content: Text(
            '¿Seguro que quieres eliminar "${shift['name']}"? Esta acción no se puede deshacer.'),
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
                  .deleteShift(shift['id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? '✅ Turno eliminado'
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