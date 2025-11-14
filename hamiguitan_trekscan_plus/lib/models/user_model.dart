class UserModel {
  final String firstName;
  final String lastName;
  final String email;
  final String birthDate;
  final String gender;
  final String? profileImage;
  final List<String> badges;

  UserModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.birthDate,
    required this.gender,
    this.profileImage,
    this.badges = const [],
  });

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? birthDate,
    String? gender,
    String? profileImage,
    List<String>? badges,
  }) {
    return UserModel(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      profileImage: profileImage ?? this.profileImage,
      badges: badges ?? this.badges,
    );
  }
}
