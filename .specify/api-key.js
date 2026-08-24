// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyAbyyNeqQVvfJQfoig75f0Vbnz-w-6MxxE",
  authDomain: "agendaclinica-457713.firebaseapp.com",
  projectId: "agendaclinica-457713",
  storageBucket: "agendaclinica-457713.firebasestorage.app",
  messagingSenderId: "401017379288",
  appId: "1:401017379288:web:67f28064e7c78fd2147aad",
  measurementId: "G-Q498WXYX31"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);