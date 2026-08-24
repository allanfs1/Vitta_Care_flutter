
'use client';

import * as React from 'react';

type FavoritePath = string;

interface FavoritesContextType {
  favorites: FavoritePath[];
  addFavorite: (path: FavoritePath) => void;
  removeFavorite: (path: FavoritePath) => void;
  isFavorite: (path: FavoritePath) => boolean;
}

const FavoritesContext = React.createContext<FavoritesContextType | undefined>(undefined);

const FAVORITES_STORAGE_KEY = 'app-favorites';

export function FavoritesProvider({ children }: { children: React.ReactNode }) {
  const [favorites, setFavorites] = React.useState<FavoritePath[]>([]);

  React.useEffect(() => {
    try {
      const storedFavorites = localStorage.getItem(FAVORITES_STORAGE_KEY);
      if (storedFavorites) {
        setFavorites(JSON.parse(storedFavorites));
      } else {
        // Set default favorites if none are stored
        setFavorites(['/', '/calendar']);
      }
    } catch (error) {
        console.error("Could not read favorites from localStorage", error);
        setFavorites(['/', '/calendar']);
    }
  }, []);

  const updateStoredFavorites = (newFavorites: FavoritePath[]) => {
      try {
        localStorage.setItem(FAVORITES_STORAGE_KEY, JSON.stringify(newFavorites));
      } catch (error) {
        console.error("Could not save favorites to localStorage", error);
      }
  }

  const addFavorite = (path: FavoritePath) => {
    setFavorites(prevFavorites => {
        if (prevFavorites.includes(path)) {
            return prevFavorites;
        }
        const newFavorites = [...prevFavorites, path];
        updateStoredFavorites(newFavorites);
        return newFavorites;
    });
  };

  const removeFavorite = (path: FavoritePath) => {
    setFavorites(prevFavorites => {
        const newFavorites = prevFavorites.filter(fav => fav !== path);
        updateStoredFavorites(newFavorites);
        return newFavorites;
    });
  };

  const isFavorite = (path: FavoritePath) => {
    return favorites.includes(path);
  };
  
  const toggleFavorite = (path: FavoritePath) => {
      if(isFavorite(path)) {
          removeFavorite(path);
      } else {
          addFavorite(path);
      }
  }

  const value = {
    favorites,
    addFavorite,
    removeFavorite,
    isFavorite,
    toggleFavorite,
  };

  return (
    <FavoritesContext.Provider value={value}>
      {children}
    </FavoritesContext.Provider>
  );
}

export const useFavorites = () => {
  const context = React.useContext(FavoritesContext);
  if (context === undefined) {
    throw new Error('useFavorites must be used within a FavoritesProvider');
  }
  return context;
};
