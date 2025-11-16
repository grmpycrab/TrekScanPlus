# User Onboarding Flow - Complete Reference

## New User Journey Map

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMPLETE SIGNUP FLOW                         │
└─────────────────────────────────────────────────────────────────┘

[START] ↓

┌──────────────────────────────────────┐
│  1. LOGIN SCREEN (Anonymous User)    │
│  ─────────────────────────────────────│
│  • Option: "Sign up"                 │
└──────────────────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│  2. SIGNUP SCREEN                    │
│  ─────────────────────────────────────│
│  • Email input                       │
│  • Password input                    │
│  • Confirm password                  │
│  • Terms & conditions checkbox       │
│  • "Sign up" button                  │
│  • "Continue with Google" button     │
└──────────────────────────────────────┘
         ↓
    ✓ Firebase Auth
    ✓ User created in Firebase
         ↓
┌──────────────────────────────────────────────┐
│  3. ADDITIONAL INFORMATION SCREEN [NEW!]     │
│  ──────────────────────────────────────────── │
│  🎯 REQUIRED FIELDS:                        │
│  • First Name                               │
│  • Last Name                                │
│  • Contact Number                           │
│  • Birth Date (Date picker)                 │
│  • Gender (Dropdown: M/F/Other)             │
│                                             │
│  FEATURES:                                  │
│  ✓ Welcome banner with explanation          │
│  ✓ Form validation on every field           │
│  ✓ Date picker with calendar UI             │
│  ✓ Privacy notice section                   │
│  ✓ "Review & Confirm" button                │
│                                             │
│  [User clicks Review & Confirm]             │
│         ↓                                    │
│  ┌──────────────────────────────────┐       │
│  │ CONFIRMATION DIALOG              │       │
│  │ ─────────────────────────────────│       │
│  │ "Confirm Your Information"       │       │
│  │                                  │       │
│  │ First Name: [entered value]      │       │
│  │ Last Name:  [entered value]      │       │
│  │ Gender:     [entered value]      │       │
│  │ Birth Date: [entered value]      │       │
│  │ Contact:    [entered value]      │       │
│  │                                  │       │
│  │ 🔒 Security Assurance Box:      │       │
│  │ "Your personal information      │       │
│  │  will be securely stored...     │       │
│  │  We never share your data..."   │       │
│  │                                  │       │
│  │ [Edit] [Confirm & Continue]      │       │
│  └──────────────────────────────────┘       │
│                                             │
│  • Edit → Returns to form                   │
│  • Confirm → Saves to Firestore             │
└──────────────────────────────────────────────┘
         ↓
    ✓ Firestore saved with:
    ✓ firstName, lastName
    ✓ phoneNumber, birthDate
    ✓ gender, lastNameChangeAt
         ↓
    ✓ Success snackbar shown
    ✓ 2-second delay
         ↓
┌──────────────────────────────────────┐
│  4. MAIN SCREEN (App starts here)    │
│  ─────────────────────────────────────│
│  • Home tab with greeting using      │
│    firstName + lastName              │
│  • All features unlocked             │
│  • User data synced across app       │
└──────────────────────────────────────┘
         ↓
     [APP READY]


═══════════════════════════════════════════════════════════════════

                   IMPORTANT FLOW DETAILS

═══════════════════════════════════════════════════════════════════

⚡ FIREBASE AUTH FLOW:
─────────────────────
Email/Password Path:
  1. User enters email + password
  2. Confirm password matches
  3. Agree to terms
  4. → Firebase.signUp() creates user

Google Sign-In Path:
  1. User taps "Continue with Google"
  2. Google auth dialog appears
  3. → Firebase.signInWithGoogle() creates user


📝 ADDITIONAL INFORMATION COLLECTION:
──────────────────────────────────────
ALL users (email or Google) see this screen:
  ✓ Email/password signup → Additional Info Screen
  ✓ Google sign-in → Additional Info Screen
  ✓ No exceptions - every new user must complete


🔐 DATA SECURITY:
─────────────────
During Collection:
  • Client-side validation
  • Real-time error feedback
  • No data sent until all fields valid

During Storage:
  • Firestore with encryption
  • Server-side validation
  • User consent clearly shown
  • Privacy messaging prominent


✅ VALIDATION RULES:
────────────────────
Field               | Required | Validation
─────────────────────────────────────────────
First Name          | Yes      | Non-empty
Last Name           | Yes      | Non-empty
Contact Number      | Yes      | Non-empty
Birth Date          | Yes      | Selected
Gender              | Yes      | Selected (M/F/Other)

Error Display:
  • Red error banner with message
  • User can dismiss and fix
  • Form prevents submission if invalid


🎨 USER INTERFACE STATES:
─────────────────────────

INITIAL STATE:
  • All fields empty
  • Dropdown shows placeholder
  • Date field shows placeholder
  • Button enabled

FILLED STATE:
  • All fields contain values
  • Gender dropdown shows selection
  • Date shows formatted date
  • Button changes appearance on hover

VALIDATION ERROR STATE:
  • Red banner appears
  • Relevant field shows error context
  • Button still enabled to resubmit
  • User can dismiss banner

LOADING STATE (During Save):
  • All fields disabled
  • Button shows spinning indicator
  • Dialog cannot dismiss
  • Cannot interact with form

SUCCESS STATE:
  • Green success snackbar shows
  • Navigates to MainScreen after 2s
  • User sees welcome greeting


═══════════════════════════════════════════════════════════════════

                    CONFIRMATION DIALOG DETAILS

═══════════════════════════════════════════════════════════════════

Dialog Appearance:
  • Modal - Cannot dismiss by tapping outside
  • Shows all 5 fields with values
  • Professional formatting

Security Section:
  ┌─────────────────────────────────┐
  │ 🔒 Your Information is Secure   │
  ├─────────────────────────────────┤
  │ Your personal information will  │
  │ be securely stored in our       │
  │ encrypted database.             │
  │                                 │
  │ We are committed to protecting  │
  │ your privacy and will never     │
  │ share your data with third      │
  │ parties.                        │
  │                                 │
  │ Your trust is our priority.     │
  └─────────────────────────────────┘

Buttons:
  • Edit: TextButton (gray) - Dismisses dialog, returns focus to form
  • Confirm & Continue: ElevatedButton (blue) - Saves and proceeds


═══════════════════════════════════════════════════════════════════

                    DATA FLOW TO FIRESTORE

═══════════════════════════════════════════════════════════════════

Collection Path: /users/{uid}

Before Additional Info:
{
  "uid": "user123abc...",
  "email": "user@example.com",
  "displayName": null,
  "photoURL": null,
  "phoneNumber": null,
  "providerData": ["password"],
  "lastSeen": timestamp,
  "createdAt": timestamp
}

After Additional Info (Same doc, merged):
{
  "uid": "user123abc...",
  "email": "user@example.com",
  "displayName": null,
  "photoURL": null,
  "phoneNumber": "09123456789",  ← NEW
  "providerData": ["password"],
  "lastSeen": timestamp,
  "createdAt": timestamp,
  "firstName": "Juan",           ← NEW
  "lastName": "Dela Cruz",       ← NEW
  "birthDate": "1995-06-15",     ← NEW
  "gender": "Male",              ← NEW
  "lastNameChangeAt": timestamp  ← NEW (for cooldown)
}

SaveOptions: merge = true
  → Preserves existing fields
  → Adds/updates new fields
  → Atomic operation


═══════════════════════════════════════════════════════════════════

                    ERROR SCENARIOS & MESSAGES

═════════════════════════════════════════════════════════════════════

VALIDATION ERRORS (Before Submission):
─────────────────────────────────────────
1. Empty First Name
   Message: "Please enter your first and last name"
   
2. Empty Last Name
   Message: "Please enter your first and last name"
   
3. No Gender Selected
   Message: "Please select your gender"
   
4. Empty Contact Number
   Message: "Please enter your contact number"
   
5. No Birth Date Selected
   Message: "Please select your birth date"

FIRESTORE ERRORS (During Submission):
──────────────────────────────────────
1. Not Authenticated
   Message: "User not authenticated"
   Action: Show error, return to form
   
2. Write Denied (Permissions)
   Message: "Failed to save information: [error]"
   Action: Show error, user can retry
   
3. Network Error
   Message: "Failed to save information: Network error"
   Action: Show error, user can retry
   
4. Quota Exceeded
   Message: "Failed to save information: Quota exceeded"
   Action: Show error, inform user to try later


═══════════════════════════════════════════════════════════════════

                    AFTER ONBOARDING COMPLETE

═════════════════════════════════════════════════════════════════════

HOME SCREEN:
  "Welcome back, Juan!"  ← Uses firstName from Firestore

PROFILE SCREEN:
  Shows: Juan Dela Cruz
  Real-time synced from Firestore

ACCOUNT SETTINGS:
  All fields pre-populated:
  • First Name: Juan
  • Last Name: Dela Cruz
  • Contact Number: 09123456789
  • Birth Date: 1995-06-15
  • Gender: Male

LOGOUT:
  User can logout anytime
  Next login goes to Login Screen (not Additional Info)

RE-LOGIN:
  When existing user logs back in:
  → Skips Additional Info Screen
  → Goes directly to MainScreen
  → Because data already exists in Firestore


═══════════════════════════════════════════════════════════════════

                        TECHNICAL SUMMARY

═════════════════════════════════════════════════════════════════════

File: lib/screens/auth/additional_information.dart
Class: AdditionalInformationScreen (StatefulWidget)
Lines: 420

Key Dependencies:
  • firebase_auth: User authentication
  • cloud_firestore: Data persistence
  • flutter/material: UI components
  • services/user_service: Firestore operations
  • components/error_feedback: Error display

State Variables:
  • _firstNameController: TextEditingController
  • _lastNameController: TextEditingController
  • _phoneController: TextEditingController
  • _birthDateController: TextEditingController
  • _selectedGender: String? (Male/Female/Other)
  • _isLoading: bool (submission state)
  • _errorMessage: String? (validation/error messages)
  • _userService: UserService (Firestore operations)

Key Methods:
  • _selectDate(): Opens date picker
  • _showConfirmationDialog(): Shows review dialog
  • _buildConfirmationDialog(): Builds dialog content
  • _buildInfoRow(): Displays data in confirmation
  • _saveAdditionalInformation(): Saves to Firestore
  • _buildTextField(): Reusable text input widget
  • build(): Main UI scaffold

Navigation:
  SUCCESS PATH:
    Additional Information → [Save] → MainScreen
  
  ERROR PATH:
    Additional Information → [Error] → Shows error → [Retry] → Same screen
  
  CANCEL PATH:
    Additional Information → [Edit] → Form focus → Same screen

═════════════════════════════════════════════════════════════════════
```

## Integration with Existing Systems

### ✅ Firebase Authentication
- Works with both email/password and Google sign-in
- Uses FirebaseAuth.instance.currentUser for UID

### ✅ Firestore Integration
- Saves to `/users/{uid}` document
- Uses UserService.updateUserInfo()
- Merge option preserves existing data

### ✅ Error Feedback System
- Uses ErrorFeedback component
- Uses ErrorHandler for error messages
- Shows both inline and snackbar notifications

### ✅ Real-Time Sync
- Profile Screen automatically updates with firstName/lastName
- Home Screen welcome greeting uses new data
- Account Settings pre-populates from saved data

### ✅ Navigation
- SignUpScreen redirects to AdditionalInformationScreen
- MainScreen receives authenticated user with complete profile
- Existing logout/login flows unaffected

## Testing Recommendations

### Manual Testing
1. Complete full signup flow with email/password
2. Complete full signup flow with Google sign-in
3. Verify all fields are required
4. Test date picker (select past dates)
5. Test gender dropdown
6. Try submission with missing fields
7. Verify error messages display correctly
8. Confirm dialog shows all information correctly
9. Edit from confirmation dialog
10. Complete submission successfully
11. Check Firestore for saved data
12. Verify data appears in Profile Screen
13. Verify data appears in Home Screen greeting

### Automated Testing
- Unit tests for field validation
- Widget tests for form rendering
- Integration tests for Firestore operations

## Deployment Notes

- No database migrations needed (Firestore is schema-less)
- No configuration changes required
- Works with existing Firebase rules
- Fully backward compatible with existing users

---

**Status**: ✅ Ready for Production  
**Last Updated**: November 2025
