
'use client';

import * as React from 'react';

interface FullScreenContextType {
  isFullScreen: boolean;
  toggleFullScreen: () => void;
  setFullScreen: (isFull: boolean) => void;
}

const FullScreenContext = React.createContext<FullScreenContextType | undefined>(undefined);

export function FullScreenProvider({ children }: { children: React.ReactNode }) {
  const [isFullScreen, setIsFullScreen] = React.useState(false);

  const toggleFullScreen = () => {
    setIsFullScreen(prev => !prev);
  };
  
  const setFullScreen = (isFull: boolean) => {
      setIsFullScreen(isFull);
  }

  return (
    <FullScreenContext.Provider value={{ isFullScreen, toggleFullScreen, setFullScreen }}>
      {children}
    </FullScreenContext.Provider>
  );
}

export const useFullScreen = () => {
  const context = React.useContext(FullScreenContext);
  if (context === undefined) {
    throw new Error('useFullScreen must be used within a FullScreenProvider');
  }
  return context;
};
