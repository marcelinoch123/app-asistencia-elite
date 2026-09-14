class AttendanceModel {
  final String id;
  final String userId;
  final String date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final String? photoUrl;
  final double? locationLat;
  final double? locationLng;
  final int lateMinutes;
  final double lateFee;
  final int workedMinutes;
  final DateTime createdAt;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.photoUrl,
    this.locationLat,
    this.locationLng,
    this.lateMinutes = 0,
    this.lateFee = 0.0,
    this.workedMinutes = 0,
    required this.createdAt,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      date: map['date'] ?? '',
      // ✅ CONVERTIR A HORA LOCAL
      checkIn: map['check_in'] != null
          ? DateTime.parse(map['check_in']).toLocal()
          : null,
      checkOut: map['check_out'] != null
          ? DateTime.parse(map['check_out']).toLocal()
          : null,
      status: map['status'] ?? 'absent',
      photoUrl: map['photo_url'],
      locationLat: map['location_lat']?.toDouble(),
      locationLng: map['location_lng']?.toDouble(),
      lateMinutes: map['late_minutes'] ?? 0,
      lateFee: (map['late_fee'] as num?)?.toDouble() ?? 0.0,
      workedMinutes: map['worked_minutes'] ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at']).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date,
      'check_in': checkIn?.toUtc().toIso8601String(),
      'check_out': checkOut?.toUtc().toIso8601String(),
      'status': status,
      'photo_url': photoUrl,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'late_minutes': lateMinutes,
      'late_fee': lateFee,
      'worked_minutes': workedMinutes,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}