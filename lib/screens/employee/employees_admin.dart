import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/custom_drawer.dart';


class EmployeesAdmin extends StatefulWidget {
  const EmployeesAdmin({super.key});

  @override
  State<EmployeesAdmin> createState() => _EmployeesAdminState();
}

class _EmployeesAdminState extends State<EmployeesAdmin> {
  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    await context.read<AttendanceProvider>().fetchAllEmployees();
  }

  @override
  Widget build(BuildContext context) {
    final attProv = context.watch<AttendanceProvider>();
    final employees = attProv.allEmployees;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Directorio de Personal'),
      drawer: const CustomDrawer(isAdmin: true),
      body: attProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total: ${employees.length} colaboradores',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: employees.isEmpty
                        ? const Center(child: Text('No hay empleados registrados'))
                        : ListView.builder(
                            itemCount: employees.length,
                            itemBuilder: (context, index) {
                              final emp = employees[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: emp.isAdmin
                                        ? Colors.blue.withOpacity(0.2)
                                        : Colors.green.withOpacity(0.2),
                                    child: Text(
                                      emp.fullName.isNotEmpty
                                          ? emp.fullName[0].toUpperCase()
                                          : 'E',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: emp.isAdmin ? Colors.blue : Colors.green,
                                      ),
                                    ),
                                  ),
                                  title: Text(emp.fullName),
                                  subtitle: Text(
                                    '${emp.email} • ${emp.department}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: emp.isActive
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      emp.isActive ? 'Activo' : 'Inactivo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: emp.isActive
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}