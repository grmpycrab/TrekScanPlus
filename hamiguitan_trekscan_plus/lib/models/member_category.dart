/// Fee/discount category for individual booking members.
///
/// The [value] getter returns the canonical string stored in Firestore and
/// local storage. Always use [MemberCategory.fromValue] when deserialising.
enum MemberCategory {
  student('student', 'Student'),
  seniorCitizen('senior_citizen', 'Senior Citizen'),
  davaOrientalResident('davao_oriental_resident', 'Davao Oriental Resident'),
  ocfdo('ocfdo', 'OCFDO Member'),
  outsideDavaoOriental('outside_davao_oriental', 'Outside Davao Oriental'),
  children8to15('children_8_15', 'Children (8–15)'),
  mfsm('mfsm', 'MFSM Member');

  const MemberCategory(this.value, this.displayName);

  /// The canonical string written to / read from Firestore.
  final String value;

  /// Human-readable label suitable for display in the UI.
  final String displayName;

  /// Returns the [MemberCategory] whose [value] matches [raw], falling back
  /// to [MemberCategory.student] for unknown / null values.
  static MemberCategory fromValue(String? raw) =>
      MemberCategory.values.firstWhere(
        (e) => e.value == raw,
        orElse: () => MemberCategory.student,
      );
}
