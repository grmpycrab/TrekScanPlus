class Climb {
  String? id;
  String name;
  DateTime date;
  String type;
  String status;
  List<String> documents;

  Climb({
    this.id,
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
      id: m['id'],
      name: m['name'] ?? '',
      date: dt,
      type: m['type'] ?? 'General',
      status: m['status'] ?? 'Pending',
    );
  }

  Map<String, String> toMap() {
    final map = {
      'name': name,
      'date': date.toIso8601String(),
      'type': type,
      'status': status,
    };
    if (id != null) map['id'] = id!;
    return map;
  }

  String computedStatus() {
    final st = status.toLowerCase();
    if (st == 'cancelled') return 'Cancelled';
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (date.isBefore(todayDate)) return 'Expired';
    // Capitalize status for display (e.g. 'approved' -> 'Approved')
    if (st.isEmpty) return status;
    return st[0].toUpperCase() + st.substring(1);
  }
}
