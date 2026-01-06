import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../lib/firebase_options.dart';

/// Script to add 30 test bookings for a specific date
/// This is used to test the booking limit functionality
///
/// Usage:
/// 1. Update the TARGET_DATE variable below
/// 2. Run: flutter run -t scripts/add_test_bookings.dart
///
/// To clear test bookings:
/// Go to Firebase Console > Firestore > bookings collection > Delete test documents

void main() async {
  print('🚀 Starting test booking creation script...\n');

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  // ============================================
  // CONFIGURE THESE SETTINGS
  // ============================================

  // The date you want to test (format: YYYY-MM-DD)
  final targetDate = DateTime(2025, 11, 30); // November 30, 2025

  // Number of bookings to create (max 30 for Mt. Hamiguitan)
  const numberOfBookings = 30;

  // Number of porters per booking (porters don't count towards slots)
  const portersPerBooking = 0; // Porters are excluded from slot calculation

  // ============================================

  print('📅 Target Date: ${targetDate.toString().split(' ')[0]}');
  print('📊 Bookings to create: $numberOfBookings');
  print('👷 Porters per booking: $portersPerBooking (not counted in slots)');
  print('💺 Slots per booking: 1 (trekker only)\n');

  // Check if user is authenticated
  User? currentUser = auth.currentUser;
  if (currentUser == null) {
    print('⚠️  No user is currently logged in.');
    print('Please ensure you are logged in before running this script.\n');
    print('You can either:');
    print('1. Run the app and log in first');
    print(
      '2. Sign in anonymously in this script (add auth.signInAnonymously())\n',
    );
    return;
  }

  print('✅ Logged in as: ${currentUser.email ?? currentUser.uid}\n');

  // Confirm before proceeding
  print('⚠️  This will create $numberOfBookings test bookings.');
  print('Press Ctrl+C to cancel, or wait 3 seconds to continue...\n');
  await Future.delayed(const Duration(seconds: 3));

  // Create test bookings
  int successCount = 0;
  int failCount = 0;

  print('📝 Creating bookings...\n');

  for (int i = 1; i <= numberOfBookings; i++) {
    try {
      final bookingData = {
        'userId': currentUser.uid,
        'affiliation': 'Test Affiliation $i',
        'trekDate': Timestamp.fromDate(targetDate),
        'numberOfPorters': portersPerBooking,
        'trekType': 'recreational',
        'location': 'inside_san_isidro',
        'notes': 'Test booking $i - Created for testing booking limits',
        'adminNotes': null,
        'attachments': [],
        'status': 'approved', // Mark as approved to count towards the limit
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await firestore.collection('bookings').add(bookingData);
      successCount++;

      // Progress indicator
      if (i % 5 == 0) {
        print('✅ Created $i/$numberOfBookings bookings...');
      }
    } catch (e) {
      failCount++;
      print('❌ Error creating booking $i: $e');
    }
  }

  print('\n✨ Completed!\n');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📊 Results:');
  print('   ✅ Successful: $successCount');
  print('   ❌ Failed: $failCount');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Count total bookings for this date
  final querySnapshot = await firestore
      .collection('bookings')
      .where('trekDate', isEqualTo: Timestamp.fromDate(targetDate))
      .get();

  // Calculate slots used (only count trekkers, not porters)
  int totalSlotsUsed = querySnapshot
      .docs
      .length; // 1 trekker per booking (porters excluded from count)

  print('📈 Current Status for ${targetDate.toString().split(' ')[0]}:');
  print('   📋 Total bookings: ${querySnapshot.docs.length}');
  print('   💺 Slots used: $totalSlotsUsed / 30');

  if (totalSlotsUsed >= 30) {
    print('   🔴 Date is FULL (≥30 slots)');
  } else if (totalSlotsUsed >= 25) {
    print('   🟡 Date is CRITICAL (≥25 slots)');
  } else {
    print('   🟢 Date has available slots');
  }

  print('\n💡 Next Steps:');
  print('1. Open the app and navigate to Book a Climb');
  print('2. Try to book on ${targetDate.toString().split(' ')[0]}');
  print('3. Verify that the system prevents booking if slots are full\n');

  print('🗑️  To clean up test data:');
  print('   Go to Firebase Console > Firestore > bookings collection');
  print('   Filter by notes containing "Test booking"');
  print('   Delete the test documents\n');
}
