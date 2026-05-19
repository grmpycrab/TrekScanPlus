// Firebase Configuration
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

// Your Firebase configuration object
// Get these values from your Firebase Console: Project Settings > General > Your apps
const firebaseConfig = {
  apiKey: "AIzaSyAr-3aDayxiHaRjbQoJ6wll1QRTvCoPAf8",
  authDomain: "trekscanplus.firebaseapp.com",
  projectId: "trekscanplus",
  storageBucket: "trekscanplus.firebasestorage.app",
  messagingSenderId: "431638508645",
  appId: "1:431638508645:web:ad5f1ebd7e4c942baf028c",
  measurementId: "G-CBEBE1C4LL"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Export the app instance
export default app;

