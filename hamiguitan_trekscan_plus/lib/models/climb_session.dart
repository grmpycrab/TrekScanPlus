import 'station_data.dart';

/// Represents a single climbing/trekking session with time tracking
class ClimbSession {
  final String id;
  final String name;
  final String description;
  final String
  trekType; // 'special_trek', 'benchmarking_trek', 'research_trek', 'regular_trek'
  DateTime createdAt;
  DateTime? trekStartDate; // Planned trek start date
  DateTime? trekEndDate; // Planned trek end date
  DateTime? startedAt; // When first station was scanned
  DateTime? completedAt;
  String status; // 'ongoing', 'completed', 'abandoned'

  // Station tracking
  List<StationVisit> visitedStations;

  // Statistics
  Duration? totalDuration;
  double? totalDistance; // in km

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
  }) : visitedStations = visitedStations ?? [];

  /// Mark when the climb actually starts (first station scan)
  void startClimb() {
    if (startedAt == null) {
      startedAt = DateTime.now();
      status = 'ongoing';
    }
  }

  /// Add a visited station
  void addVisitedStation(StationData station) {
    final visit = StationVisit(
      stationId: station.id,
      stationName: station.name,
      scannedAt: DateTime.now(),
      elevation: station.elevation,
      distanceFromPrevious: station.distanceToNextKm,
    );
    visitedStations.add(visit);
  }

  /// Complete the climb session
  void completeClimb() {
    completedAt = DateTime.now();
    status = 'completed';

    if (startedAt != null && completedAt != null) {
      totalDuration = completedAt!.difference(startedAt!);
    }

    // Calculate total distance
    totalDistance = visitedStations.fold<double>(0.0, (sum, visit) {
      return sum + (visit.distanceFromPrevious ?? 0.0);
    });
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
    };
  }

  factory ClimbSession.fromMap(Map<String, dynamic> map) {
    return ClimbSession(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      trekType: map['trekType'] as String? ?? 'regular_trek',
      createdAt: DateTime.parse(map['createdAt'] as String),
      trekStartDate: map['trekStartDate'] != null
          ? DateTime.parse(map['trekStartDate'] as String)
          : null,
      trekEndDate: map['trekEndDate'] != null
          ? DateTime.parse(map['trekEndDate'] as String)
          : null,
      startedAt: map['startedAt'] != null
          ? DateTime.parse(map['startedAt'] as String)
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
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
    );
  }
}

/// Represents a station visit within a climb session
class StationVisit {
  final String stationId;
  final String stationName;
  final DateTime scannedAt;
  final int elevation;
  final double? distanceFromPrevious; // in km

  StationVisit({
    required this.stationId,
    required this.stationName,
    required this.scannedAt,
    required this.elevation,
    this.distanceFromPrevious,
  });

  /// Get time spent at this station (until next station or now)
  Duration getTimeSinceScanned() {
    return DateTime.now().difference(scannedAt);
  }

  Map<String, dynamic> toMap() {
    return {
      'stationId': stationId,
      'stationName': stationName,
      'scannedAt': scannedAt.toIso8601String(),
      'elevation': elevation,
      'distanceFromPrevious': distanceFromPrevious,
    };
  }

  factory StationVisit.fromMap(Map<String, dynamic> map) {
    return StationVisit(
      stationId: map['stationId'] as String,
      stationName: map['stationName'] as String,
      scannedAt: DateTime.parse(map['scannedAt'] as String),
      elevation: map['elevation'] as int,
      distanceFromPrevious: (map['distanceFromPrevious'] as num?)?.toDouble(),
    );
  }
}
