
'use client';

import * as React from 'react';

type Theme = 'dark' | 'light';
type SidebarStyle = 'default' | 'icon' | 'offcanvas';

interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  primaryColor: string;
  setPrimaryColor: (color: string) => void;
  sidebarStyle: SidebarStyle;
  setSidebarStyle: (style: SidebarStyle) => void;
}

const ThemeContext = React.createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = React.useState<Theme>('light');
  const [primaryColor, setPrimaryColorState] = React.useState('312 95% 58%');
  const [sidebarStyle, setSidebarStyleState] = React.useState<SidebarStyle>('default');

  React.useEffect(() => {
    const storedTheme = localStorage.getItem('theme') as Theme | null;
    if (storedTheme) {
      setThemeState(storedTheme);
    }
    const storedColor = localStorage.getItem('primary-color');
    if (storedColor) {
      setPrimaryColorState(storedColor);
    }
    const storedSidebarStyle = localStorage.getItem('sidebar-style') as SidebarStyle | null;
    if (storedSidebarStyle) {
        setSidebarStyleState(storedSidebarStyle);
    }
  }, []);

  const setTheme = (newTheme: Theme) => {
    setThemeState(newTheme);
    localStorage.setItem('theme', newTheme);
    document.documentElement.classList.remove('light', 'dark');
    document.documentElement.classList.add(newTheme);
  };

  const setPrimaryColor = (newColor: string) => {
    setPrimaryColorState(newColor);
    localStorage.setItem('primary-color', newColor);
    document.documentElement.style.setProperty('--primary', newColor);
    // Also update ring color for consistency
    const ringColor = newColor.split(' ').slice(0, -1).join(' ') + ' 50%';
    document.documentElement.style.setProperty('--ring', ringColor);
  };
  
  const setSidebarStyle = (newStyle: SidebarStyle) => {
    setSidebarStyleState(newStyle);
    localStorage.setItem('sidebar-style', newStyle);
  }

  // Set initial values on mount
  React.useEffect(() => {
     document.documentElement.classList.add(theme);
     document.documentElement.style.setProperty('--primary', primaryColor);
     const ringColor = primaryColor.split(' ').slice(0, -1).join(' ') + ' 50%';
     document.documentElement.style.setProperty('--ring', ringColor);
  }, [theme, primaryColor]);


  const value = {
    theme,
    setTheme,
    primaryColor,
    setPrimaryColor,
    sidebarStyle,
    setSidebarStyle,
  };

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => {
  const context = React.useContext(ThemeContext);
  if (context === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};
