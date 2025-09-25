# Mt. Hamiguitan TrekScan+ 🏔️

A digital companion app enhancing the trekker experience in the Mt. Hamiguitan Range Wildlife Sanctuary, a UNESCO World Heritage Site in Davao Oriental, Philippines.

## 📖 Overview

Mt. Hamiguitan TrekScan+ is an enhanced mobile application designed to improve ecotourism experiences while supporting conservation efforts at the Mt. Hamiguitan Range Wildlife Sanctuary. This app addresses limitations of the original TrekScanApp by providing reliable offline navigation, location-verified learning stations, and comprehensive administrative tools.

## 🌟 Key Features

### Mobile Application
- **Offline GPS Navigation**: Reliable trail guidance with elevation tracking for remote areas
- **QR Code Eco-Stations**: Location-verified educational content and interactive tasks
- **Automated E-Certificate Generation**: Personalized certificates upon completion of designated stations
- **Gamified Rewards System**: Badges and mini-challenges to encourage engagement
- **Pre-Trek Verification**: Upload booking/payment documents for streamlined check-in
- **Social Sharing**: Upload and share media to promote environmental appreciation
- **Secure Authentication**: Google Sign-In and biometric verification support

### Web-Based Admin Dashboard
- **Booking Management**: Confirm and manage trekker reservations
- **User Management**: Monitor and verify trekker accounts
- **Analytics & Reporting**: Track usage patterns and generate insights
- **Real-time Monitoring**: View active trekker sessions and QR scan logs

## 🛠️ Technology Stack

### Mobile Development
- **Framework**: Flutter
- **Language**: Dart
- **Local Database**: SQLite
- **Maps Integration**: Google Maps API
- **QR Code Scanner**: flutter_barcode_scanner

### Backend & Cloud Services
- **Backend**: Firebase (Authentication, Firestore, Cloud Functions)
- **Storage**: Firebase Cloud Storage
- **Analytics**: Firebase Analytics

### Web Dashboard
- **Frontend**: React.js
- **Backend**: Node.js with Firebase Functions
- **Database**: Firebase Firestore

### Development Tools
- **IDE**: Visual Studio Code / Cursor
- **Version Control**: GitHub
- **Testing**: Flutter Test Framework

## 📋 Prerequisites

Before you begin, ensure you have:

- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / Xcode for mobile development
- Node.js (for web dashboard)
- Firebase CLI
- Git

## 🚀 Installation & Setup

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/mt-hamiguitan-trekscan-plus.git
cd mt-hamiguitan-trekscan-plus
```

### 2. Mobile App Setup
```bash
# Navigate to mobile app directory
cd mobile_app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### 3. Web Dashboard Setup
```bash
# Navigate to web dashboard directory
cd web_dashboard

# Install dependencies
npm install

# Start development server
npm start
```

### 4. Firebase Configuration
1. Create a new Firebase project
2. Enable Authentication, Firestore, and Storage
3. Add configuration files:
   - `android/app/google-services.json` (Android)
   - `ios/Runner/GoogleService-Info.plist` (iOS)
   - `web/firebase-config.js` (Web)

## 📱 Usage

### For Trekkers
1. **Sign Up/Login**: Use Google authentication or create an account
2. **Book a Trek**: Submit booking documents for verification
3. **Download Offline Maps**: Sync trail data before your trek
4. **Navigate Trails**: Use GPS guidance with elevation tracking
5. **Scan QR Codes**: Unlock educational content at eco-stations
6. **Complete Challenges**: Earn badges and certificates
7. **Share Experience**: Upload photos and journal entries

### For Administrators
1. **Access Dashboard**: Login to web-based admin panel
2. **Manage Bookings**: Review and approve trek requests
3. **Monitor Activity**: Track real-time trekker locations and progress
4. **Generate Reports**: Export analytics and usage data
5. **User Management**: Verify accounts and manage permissions

## 🔧 Configuration

### Environment Variables
Create `.env` files in respective directories:

**Mobile App** (`mobile_app/.env`):
```
GOOGLE_MAPS_API_KEY=your_maps_api_key
FIREBASE_API_KEY=your_firebase_api_key
```

**Web Dashboard** (`web_dashboard/.env`):
```
REACT_APP_FIREBASE_API_KEY=your_firebase_api_key
REACT_APP_FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
REACT_APP_FIREBASE_PROJECT_ID=your_project_id
```

## 🧪 Testing

### Run Mobile Tests
```bash
cd mobile_app
flutter test
```

### Run Web Tests
```bash
cd web_dashboard
npm test
```

## 📂 Project Structure

```
mt-hamiguitan-trekscan-plus/
├── mobile_app/
│   ├── lib/
│   │   ├── screens/
│   │   ├── widgets/
│   │   ├── services/
│   │   └── models/
│   ├── assets/
│   └── test/
├── web_dashboard/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   └── services/
│   └── public/
├── firebase_functions/
│   └── functions/
└── docs/
```

## 🌐 API Documentation

### Mobile App Endpoints
- Authentication: Firebase Auth REST API
- Database: Firestore REST API
- Storage: Firebase Storage REST API

### Admin Dashboard Endpoints
- User Management: `/api/users`
- Booking Management: `/api/bookings`
- Analytics: `/api/analytics`

## 🔒 Security Features

- Location-based QR code validation
- Biometric authentication support
- Secure document upload verification
- Role-based access control (RBAC)
- Data encryption for sensitive information

## 📋 Current Limitations

- Offline functionality limited to pre-downloaded content
- No payment processing (external payment verification required)
- GPS tracking for navigation assistance only (not real-time tracking)
- Social sharing requires internet connectivity
- QR validation has limited device-level spoofing protection

## 🗓️ Development Status

This project is currently in active development as part of a BSIT Capstone Project at Davao Oriental State University, targeting completion in May 2025.

### Current Phase: Development & Testing
- ✅ System design and mockups
- 🔄 Core feature implementation
- ⏳ Field testing
- ⏳ User acceptance testing

## 👥 Contributing

This is an academic capstone project. For collaboration inquiries, please contact the development team through the university.

### Development Team
- **Shannen G. Mendoza** - Lead Developer
- **Keynt Harly S. Adol** - Co-Developer

**Institution**: Davao Oriental State University  
**Faculty**: Computing, Engineering, and Technology

## 📄 License

This project is developed for academic purposes as part of a Bachelor of Science in Information Technology capstone project.

## 📧 Contact

For questions or collaboration opportunities:
- Email: [University Contact Information]
- Institution: Davao Oriental State University
- Location: City of Mati, Davao Oriental, Philippines

## 🙏 Acknowledgments

- Mt. Hamiguitan Range Wildlife Sanctuary Management
- UNESCO World Heritage Site Committee
- Department of Tourism (DOT) Philippines
- Department of Environment and Natural Resources (DENR)
- Davao Oriental State University Faculty

---

**Note**: This application is designed specifically for the Mt. Hamiguitan Range Wildlife Sanctuary and supports the Philippines' National Ecotourism Strategy and UNESCO's goals for technology-driven environmental stewardship.
