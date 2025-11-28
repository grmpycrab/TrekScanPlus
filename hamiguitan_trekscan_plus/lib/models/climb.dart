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
      adminNotes: _parseAdminNotes(m['adminNotes']),
    );
  }

  /// Parse adminNotes from various formats (String, List, Map) to clean text
  /// Firebase stores it as JSON string: '[{\"id\":\"...\",\"text\":\"...\",\"adminName\":\"...\"}]'
  static String? _parseAdminNotes(dynamic adminNotes) {
    if (adminNotes == null) return null;

    // If it's a String, try to parse it as JSON first
    if (adminNotes is String) {
      final trimmed = adminNotes.trim();
      if (trimmed.isEmpty) return null;

      // Check if it's a JSON string (starts with [ or {)
      if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
        try {
          // Extract text field from JSON string using regex
          final textMatch = RegExp(
            r'\"text\"\\s*:\\s*\"([^\"]+)\"',
          ).firstMatch(trimmed);
          if (textMatch != null && textMatch.groupCount > 0) {
            return textMatch.group(1);
          }
          final messageMatch = RegExp(
            r'\"message\"\\s*:\\s*\"([^\"]+)\"',
          ).firstMatch(trimmed);
          if (messageMatch != null && messageMatch.groupCount > 0) {
            return messageMatch.group(1);
          }
          // If no match found, return null to hide malformed data
          return null;
        } catch (e) {
          // If parsing fails, return null to hide malformed data
          return null;
        }
      }
      // Plain text string
      return trimmed;
    }

    // If it's a List (e.g., [{\"text\": \"...\"}]), extract first message
    if (adminNotes is List && adminNotes.isNotEmpty) {
      final first = adminNotes.first;
      if (first is Map) {
        // Try common field names for the message
        final message =
            first['text'] ??
            first['message'] ??
            first['note'] ??
            first['adminNotes'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      } else if (first is String) {
        return first.trim().isEmpty ? null : first.trim();
      }
    }

    // If it's a Map, extract message field
    if (adminNotes is Map) {
      final message =
          adminNotes['text'] ??
          adminNotes['message'] ??
          adminNotes['note'] ??
          adminNotes['adminNotes'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    // Fallback: return null to hide unparseable data
    return null;
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
    // Handle status formatting (e.g. 'changes_required' -> 'Changes Required')
    if (st.isEmpty) return status;
    // Replace underscores with spaces and capitalize each word
    final words = st.split('_');
    return words
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}
