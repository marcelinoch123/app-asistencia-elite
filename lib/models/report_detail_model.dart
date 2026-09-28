class DailyReportDetail {
  final String dateStr;
  final DateTime date;
  final String checkIn;
  final String checkOut;
  final int lateMinutes;
  final int toleranceMinutes;
  final int earlyLeaveMinutes;
  final String status;
  final String shiftSchedule;
  final String coordinates;
  final double discount;

  DailyReportDetail({
    required this.dateStr,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.lateMinutes,
    required this.toleranceMinutes,
    required this.earlyLeaveMinutes,
    required this.status,
    this.shiftSchedule = '—',
    this.coordinates = '—',
    this.discount = 0.0,
  });
}
