import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyDYYGj-PNS-P4jcMp00BN3EXzYKqZ-WGws',
  authDomain: 'testing-bc269.firebaseapp.com',
  projectId: 'testing-bc269',
  storageBucket: 'testing-bc269.firebasestorage.app',
  messagingSenderId: '471821678431',
  appId: '1:471821678431:web:426ca40330b7c219c3e8ea',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
