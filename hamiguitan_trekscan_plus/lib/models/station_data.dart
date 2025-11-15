class StationData {
  final String id; // This will match the QR code key
  final String name;
  final String description;
  final String difficulty;
  final int elevation;
  final String coordinates;
  final double? latitude;
  final double? longitude;
  final List<String> images;
  final Map<String, dynamic> metadata;
  final DateTime? lastScanned;
  final int? steps; // Steps from previous station
  final String? nextStationId; // For linear progression
  final String? nextStationName; // Name of the next station
  final double? distanceToNextKm; // Distance to next station in kilometers
  final List<String> flora; // Notable flora in the area
  final List<String> fauna; // Notable fauna in the area
  final Map<String, String> warnings; // Safety warnings for this station
  final bool isCheckpoint; // Whether this is a major checkpoint
  bool isVisited; // Track if station has been visited

  StationData({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.elevation,
    required this.coordinates,
    required this.images,
    this.latitude,
    this.longitude,
    this.metadata = const {},
    this.lastScanned,
    this.steps,
    this.nextStationId,
    this.nextStationName,
    this.distanceToNextKm,
    this.flora = const [],
    this.fauna = const [],
    this.warnings = const {},
    this.isCheckpoint = false,
    this.isVisited = false,
  });

  factory StationData.fromJson(Map<String, dynamic> json) {
    return StationData(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      difficulty: json['difficulty'],
      elevation: json['elevation'],
      coordinates: json['coordinates'],
      images: List<String>.from(json['images']),
      metadata: json['metadata'] ?? {},
      lastScanned: json['lastScanned'] != null
          ? DateTime.parse(json['lastScanned'])
          : null,
      steps: json['steps'],
      nextStationId: json['nextStationId'],
      nextStationName: json['nextStationName'],
      distanceToNextKm: (json['distanceToNextKm'] as num?)?.toDouble(),
      flora: List<String>.from(json['flora'] ?? []),
      fauna: List<String>.from(json['fauna'] ?? []),
      warnings: Map<String, String>.from(json['warnings'] ?? {}),
      isCheckpoint: json['isCheckpoint'] ?? false,
      isVisited: json['isVisited'] ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'difficulty': difficulty,
      'elevation': elevation,
      'coordinates': coordinates,
      'latitude': latitude,
      'longitude': longitude,
      'images': images,
      'metadata': metadata,
      'lastScanned': lastScanned?.toIso8601String(),
      'steps': steps,
      'nextStationId': nextStationId,
      'nextStationName': nextStationName,
      'distanceToNextKm': distanceToNextKm,
      'flora': flora,
      'fauna': fauna,
      'warnings': warnings,
      'isCheckpoint': isCheckpoint,
      'isVisited': isVisited,
    };
  }

  void updateVisited(bool value) {
    isVisited = value;
  }
}
