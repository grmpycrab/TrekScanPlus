class UserModel {
  final String firstName;
  final String lastName;
  final String email;
  final String birthDate;
  final String gender;
  final String? profileImage;
  final List<String> badges;
  final int followingCount;
  final int followersCount;
  final int postsCount;
  final List<String>
  pendingFollowRequests; // Users who sent follow requests to this user
  final List<String>
  sentFollowRequests; // Users this user sent follow requests to

  UserModel({
    this.firstName = '',
    this.lastName = '',
    required this.email,
    required this.birthDate,
    required this.gender,
    this.profileImage,
    this.badges = const [],
    this.followingCount = 0,
    this.followersCount = 0,
    this.postsCount = 0,
    this.pendingFollowRequests = const [],
    this.sentFollowRequests = const [],
  });

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? birthDate,
    String? gender,
    String? profileImage,
    List<String>? badges,
    int? followingCount,
    int? followersCount,
    int? postsCount,
    List<String>? pendingFollowRequests,
    List<String>? sentFollowRequests,
  }) {
    return UserModel(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      profileImage: profileImage ?? this.profileImage,
      badges: badges ?? this.badges,
      followingCount: followingCount ?? this.followingCount,
      followersCount: followersCount ?? this.followersCount,
      postsCount: postsCount ?? this.postsCount,
      pendingFollowRequests:
          pendingFollowRequests ?? this.pendingFollowRequests,
      sentFollowRequests: sentFollowRequests ?? this.sentFollowRequests,
    );
  }
}
