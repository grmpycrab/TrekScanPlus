class Climb {
  String? id;
  String name;
  DateTime date; // Keep for backwards compatibility
  DateTime? dateBooked; // Date when user created the booking
  DateTime? targetDate; // Date the user chooses for the trek
  DateTime? dateApproved; // Date admin approved the booking
  String type;
  String status;
  List<String> documents;
  String? adminNotes;

  Climb({
    this.id,
    required this.name,
    required this.date,
    this.dateBooked,
    this.targetDate,
    this.dateApproved,
    this.type = 'General',
    this.status = 'Pending',
    List<String>? documents,
    this.adminNotes,
  }) : documents = documents ?? [];

  factory Climb.fromMap(Map<String, dynamic> m) {
    DateTime dt;
    try {
      dt = DateTime.parse(m['date'] ?? '1970-01-01');
    } catch (_) {
      dt = DateTime(1970);
    }

    DateTime? dateBooked;
    try {
      if (m['dateBooked'] != null) {
        dateBooked = DateTime.parse(m['dateBooked']);
      }
    } catch (_) {}

    DateTime? targetDate;
    try {
      if (m['targetDate'] != null) {
        targetDate = DateTime.parse(m['targetDate']);
      }
    } catch (_) {}

    DateTime? dateApproved;
    try {
      if (m['dateApproved'] != null) {
        dateApproved = DateTime.parse(m['dateApproved']);
      }
    } catch (_) {}

    return Climb(
      id: m['id'],
      name: m['name'] ?? '',
      date: dt,
      dateBooked: dateBooked,
      targetDate: targetDate,
      dateApproved: dateApproved,
      type: m['type'] ?? 'General',
      status: m['status'] ?? 'Pending',
      adminNotes: m['adminNotes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'date': date.toIso8601String(),
      'type': type,
      'status': status,
    };
    if (id != null) {
      map['id'] = id!;
    }
    if (dateBooked != null) {
      map['dateBooked'] = dateBooked!.toIso8601String();
    }
    if (targetDate != null) {
      map['targetDate'] = targetDate!.toIso8601String();
    }
    if (dateApproved != null) {
      map['dateApproved'] = dateApproved!.toIso8601String();
    }
    final notes = adminNotes;
    if (notes != null) {
      map['adminNotes'] = notes;
    }
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
