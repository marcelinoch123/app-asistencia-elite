import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/supabase_client.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/location_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/employee/dashboard_employee.dart';
import 'screens/employee/history_employee.dart';
import 'screens/employee/profile_employee.dart';
import 'screens/admin/dashboard_admin.dart';
import 'screens/admin/employees_admin.dart';
import 'screens/admin/shifts_admin.dart';
import 'screens/admin/assign_shift_admin.dart';
import 'screens/admin/permissions_admin.dart';
import 'screens/admin/clients_admin.dart';
import 'screens/admin/calendar_admin.dart';
import 'screens/admin/reports_admin.dart';
import 'screens/admin/daily_assignments_admin.dart';
import 'screens/admin/map_admin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await SupabaseConfig.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
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
          '/employee/profile': (context) => const ProfileEmployee(),
          '/admin/dashboard': (context) => DashboardAdmin(),
          '/admin/employees': (context) => EmployeesAdmin(),
          '/admin/shifts': (context) => const ShiftsAdmin(),
          '/admin/assign': (context) => const AssignShiftAdmin(),
          '/admin/permissions': (context) => const PermissionsAdmin(),
          '/admin/clients': (context) => const ClientsAdmin(),
          '/admin/calendar': (context) => const CalendarAdmin(),
          '/admin/reports': (context) => const ReportsAdmin(),
          '/admin/daily_assignments': (context) => const DailyAssignmentsAdmin(),
          '/admin/map': (context) => const MapAdmin(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}