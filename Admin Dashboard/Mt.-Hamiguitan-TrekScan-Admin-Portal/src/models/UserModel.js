// User Model - represents user profile data
class UserModel {
  constructor(data = {}) {
    this.firstName = data.firstName || '';
    this.lastName = data.lastName || '';
    this.email = data.email || '';
    this.birthDate = data.birthDate || '';
    this.gender = data.gender || '';
    this.profileImage = data.profileImage || null;
    this.badges = data.badges || [];
    this.followingCount = data.followingCount || 0;
    this.followersCount = data.followersCount || 0;
    this.postsCount = data.postsCount || 0;
  }

  // Create from map (for Firestore or API responses)
  static fromMap(map) {
    if (!map) return null;

    return new UserModel({
      firstName: map.firstName || '',
      lastName: map.lastName || '',
      email: map.email || '',
      birthDate: map.birthDate || '',
      gender: map.gender || '',
      profileImage: map.profileImage || null,
      badges: map.badges || [],
      followingCount: typeof map.followingCount === 'number'
        ? map.followingCount
        : parseInt(map.followingCount) || 0,
      followersCount: typeof map.followersCount === 'number'
        ? map.followersCount
        : parseInt(map.followersCount) || 0,
      postsCount: typeof map.postsCount === 'number'
        ? map.postsCount
        : parseInt(map.postsCount) || 0
    });
  }

  // Convert to map (for Firestore)
  toMap() {
    return {
      firstName: this.firstName,
      lastName: this.lastName,
      email: this.email,
      birthDate: this.birthDate,
      gender: this.gender,
      profileImage: this.profileImage,
      badges: this.badges,
      followingCount: this.followingCount,
      followersCount: this.followersCount,
      postsCount: this.postsCount
    };
  }

  // Convert to JSON (for API responses)
  toJSON() {
    return {
      firstName: this.firstName,
      lastName: this.lastName,
      email: this.email,
      birthDate: this.birthDate,
      gender: this.gender,
      profileImage: this.profileImage,
      badges: this.badges,
      followingCount: this.followingCount,
      followersCount: this.followersCount,
      postsCount: this.postsCount
    };
  }

  // Create a copy with updated fields
  copyWith({
    firstName,
    lastName,
    email,
    birthDate,
    gender,
    profileImage,
    badges,
    followingCount,
    followersCount,
    postsCount
  } = {}) {
    return new UserModel({
      firstName: firstName !== undefined ? firstName : this.firstName,
      lastName: lastName !== undefined ? lastName : this.lastName,
      email: email !== undefined ? email : this.email,
      birthDate: birthDate !== undefined ? birthDate : this.birthDate,
      gender: gender !== undefined ? gender : this.gender,
      profileImage: profileImage !== undefined ? profileImage : this.profileImage,
      badges: badges !== undefined ? badges : this.badges,
      followingCount: followingCount !== undefined ? followingCount : this.followingCount,
      followersCount: followersCount !== undefined ? followersCount : this.followersCount,
      postsCount: postsCount !== undefined ? postsCount : this.postsCount
    });
  }

  // Helper methods
  getFullName() {
    return `${this.firstName} ${this.lastName}`.trim();
  }

  hasProfileImage() {
    return !!this.profileImage;
  }

  getBadgeCount() {
    return this.badges ? this.badges.length : 0;
  }
}

export default UserModel;

