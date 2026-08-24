
'use client';

import * as React from 'react';
import { usePathname, useRouter } from 'next/navigation';
import {
  AlertDialog,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
} from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { Loader2 } from 'lucide-react';

const INACTIVITY_TIMEOUT = 120 * 1000; // 2 minutes
const WARNING_TIME = 10 * 1000; // 10 seconds before timeout

interface TotemSessionContextType {
  resetTimer: () => void;
  sessionCountdown: number;
}

const TotemSessionContext = React.createContext<TotemSessionContextType | undefined>(undefined);

export function TotemSessionProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [showWarning, setShowWarning] = React.useState(false);
  const [warningCountdown, setWarningCountdown] = React.useState(WARNING_TIME / 1000);
  const [sessionCountdown, setSessionCountdown] = React.useState(INACTIVITY_TIMEOUT / 1000);
  const [sessionEnded, setSessionEnded] = React.useState(false);

  const mainIntervalRef = React.useRef<NodeJS.Timeout | null>(null);
  const warningTimeoutRef = React.useRef<NodeJS.Timeout | null>(null);
  const warningIntervalRef = React.useRef<NodeJS.Timeout | null>(null);
  
  const isTotemPage = ['/totem/schedule', '/totem/reschedule', '/totem/confirm', '/totem/success'].some(p => pathname.startsWith(p));


  const endSession = React.useCallback(() => {
    setSessionEnded(true);
  }, []);

  React.useEffect(() => {
    if (sessionEnded) {
      router.push('/totem');
    }
  }, [sessionEnded, router]);


  const startWarning = React.useCallback(() => {
    setShowWarning(true);
    setWarningCountdown(WARNING_TIME / 1000);

    warningIntervalRef.current = setInterval(() => {
      setWarningCountdown(prev => {
        if (prev <= 1) {
          clearInterval(warningIntervalRef.current!);
          endSession();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  }, [endSession]);


  const resetTimer = React.useCallback(() => {
    // Clear all existing timers
    if (mainIntervalRef.current) clearInterval(mainIntervalRef.current);
    if (warningTimeoutRef.current) clearTimeout(warningTimeoutRef.current);
    if (warningIntervalRef.current) clearInterval(warningIntervalRef.current);
    
    setSessionEnded(false);
    setShowWarning(false);
    setWarningCountdown(WARNING_TIME / 1000);
    setSessionCountdown(INACTIVITY_TIMEOUT / 1000);

    if (isTotemPage) {
      // Start the main session countdown
      mainIntervalRef.current = setInterval(() => {
          setSessionCountdown(prev => {
              if (prev <= 1) {
                  clearInterval(mainIntervalRef.current!);
                  // The session ends, but the warning dialog will handle the redirect
                  return 0;
              }
              return prev - 1;
          });
      }, 1000);

      // Set a timeout to show the warning dialog
      warningTimeoutRef.current = setTimeout(startWarning, INACTIVITY_TIMEOUT - WARNING_TIME);
    }
  }, [isTotemPage, startWarning]);


  React.useEffect(() => {
    if (isTotemPage) {
      const events = ['mousemove', 'keydown', 'click', 'touchstart'];
      events.forEach(event => window.addEventListener(event, resetTimer));
      resetTimer();

      return () => {
        events.forEach(event => window.removeEventListener(event, resetTimer));
        if (mainIntervalRef.current) clearInterval(mainIntervalRef.current);
        if (warningTimeoutRef.current) clearTimeout(warningTimeoutRef.current);
        if (warningIntervalRef.current) clearInterval(warningIntervalRef.current);
      };
    }
  }, [pathname, isTotemPage, resetTimer]);
  
  const keepSession = () => {
      setShowWarning(false);
      if (warningIntervalRef.current) clearInterval(warningIntervalRef.current);
      resetTimer();
  }

  return (
    <TotemSessionContext.Provider value={{ resetTimer, sessionCountdown }}>
      {children}
      <AlertDialog open={showWarning}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="text-center text-2xl font-bold">Sessão Expirando!</AlertDialogTitle>
            <AlertDialogDescription asChild>
                <div className="text-center text-lg py-4 text-muted-foreground">
                    <p>Você está inativo. A sessão será encerrada em</p>
                    <div className="text-6xl font-bold text-primary my-4">{warningCountdown}</div>
                    <p>segundos.</p>
                </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <Button onClick={keepSession} size="lg" className="w-full h-12 text-lg">
                Continuar Agendamento
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </TotemSessionContext.Provider>
  );
}

export const useTotemSession = () => {
  const context = React.useContext(TotemSessionContext);
  if (context === undefined) {
    throw new Error('useTotemSession must be used within a TotemSessionProvider');
  }
  return context;
};
