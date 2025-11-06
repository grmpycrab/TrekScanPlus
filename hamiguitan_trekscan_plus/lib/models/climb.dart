class Climb {
  String name;
  DateTime date;
  String type;
  String status;
  List<String> documents;

  Climb({
    required this.name,
    required this.date,
    this.type = 'General',
    this.status = 'Pending',
    List<String>? documents,
  }) : documents = documents ?? [];

  factory Climb.fromMap(Map<String, String> m) {
    DateTime dt;
    try {
      dt = DateTime.parse(m['date'] ?? '1970-01-01');
    } catch (_) {
      dt = DateTime(1970);
    }
    return Climb(
      name: m['name'] ?? '',
      date: dt,
      type: m['type'] ?? 'General',
      status: m['status'] ?? 'Pending',
    );
  }

  Map<String, String> toMap() => {
    'name': name,
    'date': date.toIso8601String(),
    'type': type,
    'status': status,
  };

  String computedStatus() {
    if (status == 'Cancelled') return 'Cancelled';
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (date.isBefore(todayDate)) return 'Expired';
    return status;
  }
}
