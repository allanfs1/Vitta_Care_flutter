
'use client';

import * as React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { LayoutDashboard, CalendarDays, ListTodo, Settings, HeartPulse, User } from 'lucide-react';
import { cn } from '@/lib/utils';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { useFavorites } from '@/contexts/favorites-context';

const routeConfig = {
    '/': { icon: LayoutDashboard, label: 'Dashboard' },
    '/calendar': { icon: CalendarDays, label: 'Calendar' },
    '/appointments': { icon: ListTodo, label: 'Appointments' },
    '/settings': { icon: Settings, label: 'Settings' },
    '/profile': { icon: User, label: 'Profile' },
    '/doctor/dashboard': { icon: HeartPulse, label: 'My Dashboard' },
    '/doctor/calendar': { icon: CalendarDays, label: 'My Calendar' },
};

export function FavoritesBar() {
    const { favorites } = useFavorites();
    const pathname = usePathname();

    if(favorites.length === 0) {
        return null;
    }

    return (
        <TooltipProvider>
            <div className="flex items-center gap-1 rounded-full border bg-background/70 p-1">
                {favorites.map((path) => {
                    const config = routeConfig[path as keyof typeof routeConfig];
                    if (!config) return null;

                    const Icon = config.icon;
                    const isActive = pathname === path;

                    return (
                         <Tooltip key={path}>
                            <TooltipTrigger asChild>
                                <Link
                                    href={path}
                                    className={cn(
                                        "flex h-8 w-8 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground",
                                        isActive && "bg-primary text-primary-foreground hover:bg-primary/90 hover:text-primary-foreground"
                                    )}
                                >
                                    <Icon className="h-5 w-5" />
                                    <span className="sr-only">{config.label}</span>
                                </Link>
                             </TooltipTrigger>
                            <TooltipContent>
                                <p>{config.label}</p>
                            </TooltipContent>
                        </Tooltip>
                    );
                })}
            </div>
        </TooltipProvider>
    );
}
