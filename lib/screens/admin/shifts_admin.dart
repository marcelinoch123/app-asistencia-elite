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
    // ✅ FIX: Ejecutar después del primer build
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
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
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

  void _showShiftDialog(BuildContext context, Map<String, dynamic>? shift) {
    final isEditing = shift != null;
    final nameCtrl = TextEditingController(
      text: isEditing ? shift['name']?.toString() ?? '' : '',
    );

    TimeOfDay startTime = isEditing
        ? _parseTime(shift['start_time'])
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = isEditing
        ? _parseTime(shift['end_time'])
        : const TimeOfDay(hour: 16, minute: 0);

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
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
              ],
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
                    const SnackBar(content: Text('Ingresa un nombre para el turno')),
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
                  );
                } else {
                  success = await provider.createShift(
                    name: nameCtrl.text.trim(),
                    startTime: startStr,
                    endTime: endStr,
                  );
                }

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? (isEditing ? '✅ Turno actualizado' : '✅ Turno creado')
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

  TimeOfDay _parseTime(dynamic time) {
    if (time == null) return const TimeOfDay(hour: 8, minute: 0);
    final str = time.toString();
    final parts = str.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 8, minute: 0);
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