
'use client';

import * as React from 'react';
import { usePathname } from 'next/navigation';
import { Pin } from 'lucide-react';

import { useFavorites } from '@/contexts/favorites-context';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { useAuth } from '@/contexts/auth-context';

interface PageHeaderProps {
    title: string;
    description: string;
    showFavoriteButton?: boolean;
}

export function PageHeader({ title, description, showFavoriteButton = true }: PageHeaderProps) {
    const pathname = usePathname();
    const { isDoctor } = useAuth();
    const { isFavorite, toggleFavorite } = useFavorites();
    const isCurrentlyFavorite = isFavorite(pathname);
    
    const canShowFavoriteButton = showFavoriteButton && !isDoctor && ['/', '/calendar', '/appointments', '/settings'].includes(pathname);


    return (
        <div className="flex items-center justify-between gap-4">
            <div>
                <h1 className="font-headline text-3xl font-semibold text-primary">{title}</h1>
                <p className="text-muted-foreground">{description}</p>
            </div>
            {canShowFavoriteButton && (
                <Button 
                    variant="ghost" 
                    size="icon"
                    onClick={() => toggleFavorite(pathname)}
                    aria-label={isCurrentlyFavorite ? 'Remove from favorites' : 'Add to favorites'}
                    className="text-muted-foreground hover:text-primary"
                >
                    <Pin className={cn(
                        "h-6 w-6 transition-all",
                        isCurrentlyFavorite && "fill-primary text-primary"
                    )} />
                </Button>
            )}
        </div>
    );
}
