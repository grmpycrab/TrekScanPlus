import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: const Color(0xFF252B30),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Welcome to TrekScan Plus!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
