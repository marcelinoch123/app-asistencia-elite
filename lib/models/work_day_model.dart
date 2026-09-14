/// Modelo de datos para representar la jornada laboral esperada y días festivos.
class WorkDayModel {
  final String id;
  final DateTime date;
  final String expectedStartTime; // Formato HH:mm (ej. "08:00")
  final String expectedEndTime;   // Formato HH:mm (ej. "17:00")
  final bool isHoliday;
  final String? notes;

  WorkDayModel({
    required this.id,
    required this.date,
    this.expectedStartTime = '08:00',
    this.expectedEndTime = '17:00',
    this.isHoliday = false,
    this.notes,
  });

  /// Determina si es un día laborable estándar (no festivo y no fin de semana)
  bool get isWorkingDay => !isHoliday && date.weekday != DateTime.sunday;

  /// Conversión desde JSON de Supabase
  factory WorkDayModel.fromJson(Map<String, dynamic> json) {
    return WorkDayModel(
      id: json['id']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expectedStartTime: json['expected_start_time'] as String? ?? '08:00',
      expectedEndTime: json['expected_end_time'] as String? ?? '17:00',
      isHoliday: json['is_holiday'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  /// Conversión a JSON para Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String().split('T').first,
      'expected_start_time': expectedStartTime,
      'expected_end_time': expectedEndTime,
      'is_holiday': isHoliday,
      'notes': notes,
    };
  }

  /// Copia modificada
  WorkDayModel copyWith({
    String? id,
    DateTime? date,
    String? expectedStartTime,
    String? expectedEndTime,
    bool? isHoliday,
    String? notes,
  }) {
    return WorkDayModel(
      id: id ?? this.id,
      date: date ?? this.date,
      expectedStartTime: expectedStartTime ?? this.expectedStartTime,
      expectedEndTime: expectedEndTime ?? this.expectedEndTime,
      isHoliday: isHoliday ?? this.isHoliday,
      notes: notes ?? this.notes,
    );
  }
}
