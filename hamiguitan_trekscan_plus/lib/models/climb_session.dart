import 'station_data.dart';
import 'trek_type.dart';

/// Represents a single climbing/trekking session with time tracking
class ClimbSession {
  final String id;
  final String name;
  final String description;
  final String
  trekType; // see TrekType enum for valid values
  DateTime createdAt;
  DateTime? trekStartDate; // Planned trek start date
  DateTime? trekEndDate; // Planned trek end date
  DateTime? startedAt; // When first station was scanned
  DateTime? completedAt;
  String status; // 'ongoing', 'completed', 'abandoned', 'auto_completed'

  // Station tracking
  List<StationVisit> visitedStations;

  // Statistics
  Duration? totalDuration;
  double? totalDistance; // in km

  // Offline / sync metadata
  /// Last time any station was scanned in this session. Updated on every scan.
  DateTime? lastActivityAt;

  /// True when this session has local changes not yet confirmed by Firestore.
  bool syncPending;

  /// True when this session was first created while the device was offline.
  final bool createdOffline;

  ClimbSession({
    required this.id,
    required this.name,
    required this.description,
    required this.trekType,
    required this.createdAt,
    this.trekStartDate,
    this.trekEndDate,
    this.startedAt,
    this.completedAt,
    this.status = 'ongoing',
    List<StationVisit>? visitedStations,
    this.totalDuration,
    this.totalDistance,
    this.lastActivityAt,
    this.syncPending = false,
    this.createdOffline = false,
  }) : visitedStations = visitedStations ?? [];

  /// Mark when the climb actually starts (first station scan)
  void startClimb() {
    if (startedAt == null) {
      startedAt = DateTime.now();
      status = 'ongoing';
    }
  }

  /// Add a visited station, stamp the previous station's [durationAtStation],
  /// update [lastActivityAt], and recompute running [totalDistance].
  void addVisitedStation(StationData station) {
    final now = DateTime.now();

    // Stamp how long the trekker spent at the previous station.
    if (visitedStations.isNotEmpty) {
      final prev = visitedStations.last;
      prev.durationAtStation ??= now.difference(prev.scannedAt);
    }

    // distanceFromPrevious = distance from the previous station TO this one,
    // which is stored on the previous station as distanceToNextKm.
    final double? distFromPrev = visitedStations.isNotEmpty
        ? visitedStations.last.distanceFromPrevious
        : null;

    final visit = StationVisit(
      stationId: station.id,
      stationName: station.name,
      scannedAt: now,
      elevation: station.elevation,
      // Pre-populate with the current station's distanceToNextKm so the
      // NEXT scan can read it as distanceFromPrevious.
      distanceFromPrevious: distFromPrev ?? station.distanceToNextKm,
    );
    visitedStations.add(visit);
    lastActivityAt = now;
    syncPending = true;

    // Keep running total of distance covered so far.
    totalDistance = visitedStations.fold<double>(
      0.0,
      (sum, v) => sum + (v.distanceFromPrevious ?? 0.0),
    );
  }

  /// Complete the climb session.
  ///
  /// Stamps the final station's [durationAtStation] and recalculates
  /// [totalDuration] and [totalDistance] from actual scan data.
  void completeClimb() {
    completedAt = DateTime.now();
    status = 'completed';

    // Stamp duration for the final station.
    if (visitedStations.isNotEmpty) {
      final last = visitedStations.last;
      last.durationAtStation ??= completedAt!.difference(last.scannedAt);
    }

    if (startedAt != null) {
      totalDuration = completedAt!.difference(startedAt!);
    }

    totalDistance = visitedStations.fold<double>(
      0.0,
      (sum, v) => sum + (v.distanceFromPrevious ?? 0.0),
    );
  }

  /// Calculate accurate stats without mutating the session.
  /// Used for display in detail screens.
  ({Duration? elapsed, double distanceKm, int stationCount}) get liveStats {
    final elapsed = startedAt != null
        ? (completedAt ?? lastActivityAt ?? DateTime.now()).difference(
            startedAt!,
          )
        : null;
    final dist = visitedStations.fold<double>(
      0.0,
      (sum, v) => sum + (v.distanceFromPrevious ?? 0.0),
    );
    return (
      elapsed: elapsed,
      distanceKm: dist,
      stationCount: visitedStations.length,
    );
  }

  /// Check if station was already visited in this session
  bool isStationVisited(String stationId) {
    return visitedStations.any((v) => v.stationId == stationId);
  }

  /// Get duration from session start to now
  Duration? getElapsedDuration() {
    if (startedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }

  /// Format duration for display (e.g., "2h 45m 30s")
  String formatDuration(Duration? duration) {
    if (duration == null) return '--:--:--';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return '${hours}h ${minutes}m ${seconds}s';
  }

  /// Get progress percentage (visited / total stations)
  double getProgressPercentage(int totalStations) {
    if (totalStations == 0) return 0;
    return (visitedStations.length / totalStations) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'trekType': trekType,
      'createdAt': createdAt.toIso8601String(),
      'trekStartDate': trekStartDate?.toIso8601String(),
      'trekEndDate': trekEndDate?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'status': status,
      'visitedStations': visitedStations.map((v) => v.toMap()).toList(),
      'totalDuration': totalDuration?.inSeconds,
      'totalDistance': totalDistance,
      'lastActivityAt': lastActivityAt?.toIso8601String(),
      'syncPending': syncPending,
      'createdOffline': createdOffline,
    };
  }

  factory ClimbSession.fromMap(Map<String, dynamic> map) {
    return ClimbSession(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      trekType: map['trekType'] as String? ?? TrekType.regular.value,
      createdAt: _parseDateTime(map['createdAt']),
      trekStartDate: map['trekStartDate'] != null
          ? _parseDateTime(map['trekStartDate'])
          : null,
      trekEndDate: map['trekEndDate'] != null
          ? _parseDateTime(map['trekEndDate'])
          : null,
      startedAt: map['startedAt'] != null
          ? _parseDateTime(map['startedAt'])
          : null,
      completedAt: map['completedAt'] != null
          ? _parseDateTime(map['completedAt'])
          : null,
      status: map['status'] as String? ?? 'ongoing',
      visitedStations:
          (map['visitedStations'] as List<dynamic>?)
              ?.map((v) => StationVisit.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      totalDuration: map['totalDuration'] != null
          ? Duration(seconds: map['totalDuration'] as int)
          : null,
      totalDistance: (map['totalDistance'] as num?)?.toDouble(),
      lastActivityAt: map['lastActivityAt'] != null
          ? _parseDateTime(map['lastActivityAt'])
          : null,
      syncPending: map['syncPending'] as bool? ?? false,
      createdOffline: map['createdOffline'] as bool? ?? false,
    );
  }

  /// Parse DateTime from either a Firestore Timestamp or an ISO-8601 string.
  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    // Firestore Timestamp (has .toDate())
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {}
    return DateTime.parse(value as String);
  }
}

/// Represents a station visit within a climb session
class StationVisit {
  final String stationId;
  final String stationName;
  final DateTime scannedAt;
  final int elevation;

  /// Distance from the previous station to this one, in km.
  /// Derived from [StationData.distanceToNextKm] of the previous station.
  final double? distanceFromPrevious;

  /// How long the trekker spent at this station before moving to the next.
  /// Null for the last station in the session (still ongoing or just completed).
  Duration? durationAtStation;

  StationVisit({
    required this.stationId,
    required this.stationName,
    required this.scannedAt,
    required this.elevation,
    this.distanceFromPrevious,
    this.durationAtStation,
  });

  /// Time elapsed since this station was scanned (live, for the last station).
  Duration get timeSinceScanned => DateTime.now().difference(scannedAt);

  Map<String, dynamic> toMap() {
    return {
      'stationId': stationId,
      'stationName': stationName,
      'scannedAt': scannedAt.toIso8601String(),
      'elevation': elevation,
      'distanceFromPrevious': distanceFromPrevious,
      'durationAtStation': durationAtStation?.inSeconds,
    };
  }

  factory StationVisit.fromMap(Map<String, dynamic> map) {
    return StationVisit(
      stationId: map['stationId'] as String,
      stationName: map['stationName'] as String,
      scannedAt: ClimbSession._parseDateTime(map['scannedAt']),
      elevation: map['elevation'] as int,
      distanceFromPrevious: (map['distanceFromPrevious'] as num?)?.toDouble(),
      durationAtStation: map['durationAtStation'] != null
          ? Duration(seconds: map['durationAtStation'] as int)
          : null,
    );
  }
}
