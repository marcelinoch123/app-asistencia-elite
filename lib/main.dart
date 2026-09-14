import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/supabase_client.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/location_provider.dart'; // ✅ IMPORTANTE
import 'screens/auth/login_screen.dart';
import 'screens/employee/dashboard_employee.dart';
import 'screens/employee/history_employee.dart';
import 'screens/admin/dashboard_admin.dart';
import 'screens/admin/employees_admin.dart';
import 'screens/admin/shifts_admin.dart';
import 'screens/admin/assign_shift_admin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ✅ TODOS los providers deben estar AQUÍ
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()), // ✅ AGREGAR
      ],
      child: MaterialApp(
        title: 'Control de Asistencia',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/employee/dashboard': (context) => const DashboardEmployee(),
          '/employee/history': (context) => const HistoryEmployee(),
          '/admin/dashboard': (context) => DashboardAdmin(),
          '/admin/employees': (context) => EmployeesAdmin(),
          '/admin/shifts': (context) => const ShiftsAdmin(),
          '/admin/assign': (context) => const AssignShiftAdmin(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}