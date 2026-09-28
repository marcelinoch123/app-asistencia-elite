import 'package:flutter_test/flutter_test.dart';
import 'package:app_asistencia_elite/models/attendance_model.dart';

void main() {
  group('Pruebas de Reglas de Negocio - Asistencia y Descuentos', () {
    test('AttendanceModel mapea correctamente tolerance_minutes_used, early_leave_minutes y notes', () {
      final map = {
        'id': 'test-1',
        'user_id': 'user-123',
        'date': '2026-09-17',
        'status': 'late',
        'late_minutes': 5,
        'late_fee': 5.0,
        'tolerance_minutes_used': 8,
        'early_leave_minutes': 25,
        'notes': 'Retraso por congestión vehicular',
      };

      final model = AttendanceModel.fromMap(map);

      expect(model.toleranceMinutesUsed, equals(8));
      expect(model.earlyLeaveMinutes, equals(25));
      expect(model.lateMinutes, equals(5));
      expect(model.lateFee, equals(5.0));
      expect(model.notes, equals('Retraso por congestión vehicular'));

      final serialized = model.toMap();
      expect(serialized['tolerance_minutes_used'], equals(8));
      expect(serialized['early_leave_minutes'], equals(25));
      expect(serialized['notes'], equals('Retraso por congestión vehicular'));
    });

    test('Regla 1 y 3: Cálculo de tolerancia y retraso en check-in', () {
      const tolerance = 10;
      const feePerMinute = 1.0;

      // Caso A: Llegada dentro de la tolerancia (ej. 7 minutos tarde)
      int diffMinutesA = 7;
      int toleranceA = 0;
      int lateMinutesA = 0;
      double lateFeeA = 0.0;

      if (diffMinutesA > 0 && diffMinutesA <= tolerance) {
        toleranceA = diffMinutesA;
        lateMinutesA = 0;
        lateFeeA = 0.0;
      }

      expect(toleranceA, equals(7));
      expect(lateMinutesA, equals(0));
      expect(lateFeeA, equals(0.0));

      // Caso B: Llegada superando la tolerancia (ej. 15 minutos tarde)
      int diffMinutesB = 15;
      int toleranceB = 0;
      int lateMinutesB = 0;
      double lateFeeB = 0.0;

      if (diffMinutesB > tolerance) {
        toleranceB = 0; // NO se acumula en tolerancia
        lateMinutesB = diffMinutesB - tolerance;
        lateFeeB = lateMinutesB * feePerMinute;
      }

      expect(toleranceB, equals(0));
      expect(lateMinutesB, equals(5));
      expect(lateFeeB, equals(5.0));

      // Caso C: Llegada a tiempo o antes (diffMinutes <= 0)
      int diffMinutesC = -5;
      int toleranceC = 0;
      int lateMinutesC = 0;
      double lateFeeC = 0.0;

      if (diffMinutesC > 0 && diffMinutesC <= tolerance) {
        toleranceC = diffMinutesC;
      } else if (diffMinutesC > tolerance) {
        toleranceC = 0;
        lateMinutesC = diffMinutesC - tolerance;
      } else {
        toleranceC = 0;
        lateMinutesC = 0;
        lateFeeC = 0.0;
      }

      expect(toleranceC, equals(0));
      expect(lateMinutesC, equals(0));
      expect(lateFeeC, equals(0.0));
    });

    test('Regla 7 y 8: Cálculo de salida anticipada (early_leave_minutes)', () {
      final shiftEnd = DateTime(2026, 9, 17, 17, 0);

      // Salida anticipada: se retira a las 16:35 (25 minutos antes)
      final exitEarly = DateTime(2026, 9, 17, 16, 35);
      int earlyMinutesA = 0;
      if (exitEarly.isBefore(shiftEnd)) {
        earlyMinutesA = shiftEnd.difference(exitEarly).inMinutes;
      }
      expect(earlyMinutesA, equals(25));

      // Salida puntual o tardía: se retira a las 17:10
      final exitLate = DateTime(2026, 9, 17, 17, 10);
      int earlyMinutesB = 0;
      if (exitLate.isBefore(shiftEnd)) {
        earlyMinutesB = shiftEnd.difference(exitLate).inMinutes;
      }
      expect(earlyMinutesB, equals(0));
    });

    test('Turno con cruce de medianoche (22:00 a 06:00)', () {
      final shiftStart = DateTime(2026, 9, 17, 22, 0);
      DateTime shiftEnd = DateTime(2026, 9, 17, 6, 0);

      if (shiftEnd.isBefore(shiftStart)) {
        shiftEnd = shiftEnd.add(const Duration(days: 1));
      }

      // shiftEnd debe ser el 18 de septiembre a las 06:00
      expect(shiftEnd, equals(DateTime(2026, 9, 18, 6, 0)));

      // Salida anticipada a las 05:40 del día siguiente
      final nowEarly = DateTime(2026, 9, 18, 5, 40);
      int earlyMinutes = 0;
      if (nowEarly.isBefore(shiftEnd)) {
        earlyMinutes = shiftEnd.difference(nowEarly).inMinutes;
      }
      expect(earlyMinutes, equals(20));

      // Salida completada a las 06:05 del día siguiente
      final nowCompleted = DateTime(2026, 9, 18, 6, 5);
      int completedMinutes = 0;
      if (nowCompleted.isBefore(shiftEnd)) {
        completedMinutes = shiftEnd.difference(nowCompleted).inMinutes;
      }
      expect(completedMinutes, equals(0));
    });

    test('Caso Pedro Ramírez: Turno 11:00-19:00 Bolivia y check_out a las 12:46 UTC (614 min)', () {
      // Turno en fecha 2026-09-17: 11:00 a 19:00 Bolivia (UTC-4)
      const shiftYear = 2026;
      const shiftMonth = 9;
      const shiftDay = 17;
      const startHour = 11;
      const startMinute = 0;
      const endHour = 19;
      const endMinute = 0;

      // Conversión de hora de turno de Bolivia (UTC-4) a UTC (+4 horas)
      DateTime shiftEndUtc = DateTime.utc(
        shiftYear,
        shiftMonth,
        shiftDay,
        endHour,
        endMinute,
      ).add(const Duration(hours: 4)); // 23:00 UTC

      final shiftStartUtc = DateTime.utc(
        shiftYear,
        shiftMonth,
        shiftDay,
        startHour,
        startMinute,
      ).add(const Duration(hours: 4)); // 15:00 UTC

      if (shiftEndUtc.isBefore(shiftStartUtc)) {
        shiftEndUtc = shiftEndUtc.add(const Duration(days: 1));
      }

      // Check-out registrado a las 12:46 UTC (08:46 AM Bolivia)
      final checkOutUtc = DateTime.utc(2026, 9, 17, 12, 46, 35);
      final checkOutMinuteUtc = DateTime.utc(
        checkOutUtc.year,
        checkOutUtc.month,
        checkOutUtc.day,
        checkOutUtc.hour,
        checkOutUtc.minute,
      );

      int earlyLeaveMinutes = 0;
      if (checkOutMinuteUtc.isBefore(shiftEndUtc)) {
        earlyLeaveMinutes = shiftEndUtc.difference(checkOutMinuteUtc).inMinutes;
      }

      // 23:00 UTC - 12:46 UTC = 10h 14m = 614 minutos exactos
      expect(earlyLeaveMinutes, equals(614));
    });

    test('Cálculo de penalidades mensuales (tolerancia >= 60 min y faltas)', () {
      // 1. Tolerancia < 60 min
      int toleranceMin1 = 45;
      double feeTol1 = toleranceMin1 >= 60 ? 100.0 : 0.0;
      expect(feeTol1, equals(0.0));

      // 2. Tolerancia >= 60 min (multa de Bs 100)
      int toleranceMin2 = 62;
      double feeTol2 = toleranceMin2 >= 60 ? 100.0 : 0.0;
      expect(feeTol2, equals(100.0));

      // 3. Faltas (Bs 200 por cada falta)
      int absences = 3;
      double absenceFee = absences * 200.0;
      expect(absenceFee, equals(600.0));

      // 4. Gran Total
      double lateFee = 15.0;
      double grandTotal = lateFee + feeTol2 + absenceFee;
      expect(grandTotal, equals(715.0));
    });

    test('Restricción de horario: solo se puede marcar desde 5 min antes de inicio de turno', () {
      // Turno configurado para iniciar a las 18:00
      final shiftStart = DateTime(2026, 9, 20, 18, 0);
      final earliestAllowed = shiftStart.subtract(const Duration(minutes: 5)); // 17:55

      // Caso A: Intento a las 17:50 (10 min antes -> BLOQUEADO)
      final attemptTooEarly = DateTime(2026, 9, 20, 17, 50);
      final isTooEarlyA = attemptTooEarly.isBefore(earliestAllowed);
      expect(isTooEarlyA, isTrue);

      // Caso B: Intento a las 17:55 (límite exacto de 5 min -> PERMITIDO)
      final attemptOnWindow = DateTime(2026, 9, 20, 17, 55);
      final isTooEarlyB = attemptOnWindow.isBefore(earliestAllowed);
      expect(isTooEarlyB, isFalse);

      // Caso C: Intento a las 17:56 (4 min antes -> PERMITIDO)
      final attemptInsideWindow = DateTime(2026, 9, 20, 17, 56);
      final isTooEarlyC = attemptInsideWindow.isBefore(earliestAllowed);
      expect(isTooEarlyC, isFalse);

      // Caso D: Intento a las 18:00 (inicio exacto -> PERMITIDO)
      final attemptAtStart = DateTime(2026, 9, 20, 18, 0);
      final isTooEarlyD = attemptAtStart.isBefore(earliestAllowed);
      expect(isTooEarlyD, isFalse);

      // Caso E: Intento a las 18:10 (turno en curso -> PERMITIDO)
      final attemptAfterStart = DateTime(2026, 9, 20, 18, 10);
      final isTooEarlyE = attemptAfterStart.isBefore(earliestAllowed);
      expect(isTooEarlyE, isFalse);
    });

    test('Lógica de conteo de faltas: turnos pasados sin check-in, feriados y permisos', () {
      // Simulación del algoritmo de countAbsences
      final assignedDays = {'2026-09-01', '2026-09-02', '2026-09-03', '2026-09-04', '2026-09-05'};
      final attendedDaysWithCheckIn = {'2026-09-01'}; // 1 de sep asistió
      final holidays = {'2026-09-02'}; // 2 de sep es feriado
      final permissionDays = {'2026-09-03'}; // 3 de sep permiso aprobado
      // 4 de sep: asignado, sin check-in, no feriado, no permiso -> FALTA
      // 5 de sep: asignado, sin check-in, no feriado, no permiso -> FALTA

      int countAbsencesSimulated(Set<String> assigned) {
        int absences = 0;
        for (final day in assigned) {
          if (attendedDaysWithCheckIn.contains(day)) continue;
          if (holidays.contains(day)) continue;
          if (permissionDays.contains(day)) continue;
          absences++;
        }
        return absences;
      }

      final total = countAbsencesSimulated(assignedDays);
      expect(total, equals(2)); // Exactamente 2 faltas (días 4 y 5)
    });
  });
}

