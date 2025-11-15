import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;
  User? _firebaseUser;

  @override
  void initState() {
    super.initState();
    _firebaseUser = FirebaseAuthService.instance.currentUser;

    if (_firebaseUser != null) {
      final display = _firebaseUser!.displayName ?? '';
      final parts = display.isNotEmpty ? display.split(' ') : [];
      final first = parts.isNotEmpty
          ? parts.first
          : (_firebaseUser!.email?.split('@').first ?? '');
      final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      _user = UserModel(
        firstName: first,
        lastName: last,
        email: _firebaseUser!.email ?? '',
        birthDate: '01/01/1990',
        gender: 'Not specified',
        profileImage: _firebaseUser!.photoURL,
      );
      _loadBadges();
      _loadUserStats();
    } else {
      _user = UserModel(
        firstName: 'John',
        lastName: 'Doe',
        email: 'john.doe@example.com',
        birthDate: '01/01/1990',
        gender: 'Male',
      );
    }
  }

  Future<void> _loadBadges() async {
    try {
      final uid = _firebaseUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      final raw = data['badges'] as List<dynamic>?;
      final badges = raw?.whereType<String>().toList() ?? [];
      setState(() {
        _user = _user.copyWith(badges: badges);
      });
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load badges: $e');
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final uid = _firebaseUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      setState(() {
        _user = _user.copyWith(
          followingCount: data['followingCount'] as int? ?? 0,
          followersCount: data['followersCount'] as int? ?? 0,
          postsCount: data['postsCount'] as int? ?? 0,
        );
      });
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load user stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with back button and title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // To balance the layout
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Profile info section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _buildProfileSection(),
                    const SizedBox(height: 24),
                    _buildStatsSection(),
                    const SizedBox(height: 32),
                    if (_user.badges.isNotEmpty) _buildBadgesSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: ClipOval(
            child: _user.profileImage != null
                ? Image.network(_user.profileImage!, fit: BoxFit.cover)
                : CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[100],
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "${_user.firstName} ${_user.lastName}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _user.email,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            Text(
              _user.followingCount.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Following',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        Column(
          children: [
            Text(
              _user.followersCount.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Followers',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        Column(
          children: [
            Text(
              _user.postsCount.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Posts',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Badges Earned',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_user.badges.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const SettingsScreen(showBadgesOnly: true),
                    ),
                  );
                },
                child: Text(
                  'See More',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[600],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_user.badges.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'No badges earned yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _user.badges
                  .take(5) // Show only first 5 badges in horizontal view
                  .map((badge) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
      ],
    );
  }
}
