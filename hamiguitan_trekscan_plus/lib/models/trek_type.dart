/// Trek/climb type for bookings, sessions, and group bookings.
///
/// The [value] getter returns the canonical string stored in Firestore and
/// local storage. Always use [TrekType.fromValue] when deserialising to avoid
/// scattered raw-string comparisons across the codebase.
enum TrekType {
  regular('regular_trek', 'Regular Trek'),
  special('special_trek', 'Special Trek'),
  benchmarking('benchmarking_trek', 'Benchmarking Trek'),
  research('research_trek', 'Research Trek');

  const TrekType(this.value, this.displayName);

  /// The canonical string written to / read from Firestore.
  final String value;

  /// Human-readable label suitable for display in the UI.
  final String displayName;

  /// Returns the [TrekType] whose [value] matches [raw], falling back to
  /// [TrekType.regular] for unknown / null values so deserialization never
  /// throws.
  static TrekType fromValue(String? raw) => TrekType.values.firstWhere(
    (e) => e.value == raw,
    orElse: () => TrekType.regular,
  );
}
