/// Model for trail-specific biodiversity and facility information
class TrailDetails {
  final List<String> trailType;
  final List<String> plants;
  final List<String> animals;
  final List<String> facilities;
  final List<String> utilities;
  final Map<String, String> warnings;

  TrailDetails({
    this.trailType = const [],
    this.plants = const [],
    this.animals = const [],
    this.facilities = const [],
    this.utilities = const [],
    this.warnings = const {},
  });

  /// Create from JSON
  factory TrailDetails.fromJson(Map<String, dynamic> json) {
    return TrailDetails(
      trailType: List<String>.from(json['trailType'] as List? ?? []),
      plants: List<String>.from(json['plants'] as List? ?? []),
      animals: List<String>.from(json['animals'] as List? ?? []),
      facilities: List<String>.from(json['facilities'] as List? ?? []),
      utilities: List<String>.from(json['utilities'] as List? ?? []),
      warnings: Map<String, String>.from(json['warnings'] as Map? ?? {}),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'trailType': trailType,
    'plants': plants,
    'animals': animals,
    'facilities': facilities,
    'utilities': utilities,
    'warnings': warnings,
  };

  /// Check if any data is available
  bool get hasData =>
      trailType.isNotEmpty ||
      plants.isNotEmpty ||
      animals.isNotEmpty ||
      facilities.isNotEmpty ||
      utilities.isNotEmpty ||
      warnings.isNotEmpty;
}
