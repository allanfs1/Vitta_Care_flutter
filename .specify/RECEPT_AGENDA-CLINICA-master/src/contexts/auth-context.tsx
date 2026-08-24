
'use client';

import * as React from 'react';
import { onAuthStateChanged, User as FirebaseUser } from 'firebase/auth';
import { doc, getDoc, collection, query, where, getDocs, DocumentReference, limit } from 'firebase/firestore';
import { auth, db } from '@/lib/firebase';
import { LoadingScreen } from '@/components/loading-screen';
import type { UserProfile, DoctorProfile } from '@/lib/types';

interface AuthContextType {
  user: FirebaseUser | null;
  userProfile: UserProfile | null;
  doctorProfile: DoctorProfile | null,
  isDoctor: boolean;
  loading: boolean;
  doctorId: string | null;
  clinicId: string | null;
}

const AuthContext = React.createContext<AuthContextType>({
  user: null,
  userProfile: null,
  doctorProfile: null,
  isDoctor: false,
  loading: true,
  doctorId: null,
  clinicId: null,
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = React.useState<FirebaseUser | null>(null);
  const [userProfile, setUserProfile] = React.useState<UserProfile | null>(null);
  const [doctorProfile, setDoctorProfile] = React.useState<DoctorProfile | null>(null);
  const [isDoctor, setIsDoctor] = React.useState(false);
  const [loading, setLoading] = React.useState(true);
  const [doctorId, setDoctorId] = React.useState<string | null>(null);
  const [clinicId, setClinicId] = React.useState<string | null>(null);


  React.useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      setLoading(true);
      if (firebaseUser) {
        setUser(firebaseUser);
        
        // Reset states
        setUserProfile(null);
        setDoctorProfile(null);
        setIsDoctor(false);
        setDoctorId(null);
        setClinicId(null);

        try {
          // 1. Fetch base user profile
          const userDocRef = doc(db, 'users', firebaseUser.uid);
          const userDocSnap = await getDoc(userDocRef);
          const currentUserProfile = userDocSnap.exists() ? userDocSnap.data() as UserProfile : null;
          setUserProfile(currentUserProfile);
          
          const userIsDoctor = !!currentUserProfile?.roles?.includes('med');
          setIsDoctor(userIsDoctor);

          let finalClinicId: string | null = null;

          // 2. Handle doctor-specific logic
          if (userIsDoctor && firebaseUser.email) {
              const medicosRef = collection(db, "tb_medicos");
              const q = query(medicosRef, where("email", "==", firebaseUser.email), limit(1));
              const medicoSnap = await getDocs(q);
              
              if(!medicoSnap.empty) {
                  const medicoDoc = medicoSnap.docs[0];
                  const doctorData = medicoDoc.data() as DoctorProfile;
                  setDoctorProfile(doctorData);
                  setDoctorId(medicoDoc.id);

                  // Extract clinic ID from doctor's profile using the correct field name "idclinica"
                  if (doctorData.idclinica) {
                      if (doctorData.idclinica instanceof DocumentReference) {
                          finalClinicId = doctorData.idclinica.id;
                      } else if (typeof doctorData.idclinica === 'string') {
                          finalClinicId = doctorData.idclinica;
                      }
                  }
              }
          } 
          // 3. Handle non-doctor logic (e.g., admin)
          else if (currentUserProfile) {
              // Extract clinic ID from admin's user profile
              if (currentUserProfile.idClinica) {
                 if (currentUserProfile.idClinica instanceof DocumentReference) {
                      finalClinicId = currentUserProfile.idClinica.id;
                  } else if (typeof currentUserProfile.idClinica === 'string') {
                      finalClinicId = currentUserProfile.idClinica;
                  }
              }
          }
          
          setClinicId(finalClinicId);

        } catch (error) {
           console.error("Error fetching user data:", error);
           // Clear all profile states on error to prevent inconsistent state
           setUserProfile(null);
           setDoctorProfile(null);
           setIsDoctor(false);
           setDoctorId(null);
           setClinicId(null);
        }
      } else {
        // No user is logged in, clear all states
        setUser(null);
        setUserProfile(null);
        setDoctorProfile(null);
        setIsDoctor(false);
        setDoctorId(null);
        setClinicId(null);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const value = { user, userProfile, doctorProfile, isDoctor, loading, doctorId, clinicId };

  return (
    <AuthContext.Provider value={value}>
      {loading ? <LoadingScreen /> : children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = React.useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
