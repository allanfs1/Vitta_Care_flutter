
'use client';

import * as React from 'react';
import Image from 'next/image';
import { collection, getDocs } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { PublicAgendaDisplay } from "@/components/appointments/public-agenda-display";
import { PageHeader } from '@/components/page-header';
import { useFullScreen } from '@/contexts/fullscreen-context';
import { Button } from '@/components/ui/button';
import { Expand, Shrink } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Skeleton } from '@/components/ui/skeleton';

interface ClinicInfo {
    name: string;
    logoUrl: string;
}


export default function AppointmentsPage() {
    const { isFullScreen, toggleFullScreen } = useFullScreen();
   
    return (
        <div className={cn(
            "flex flex-col gap-8 h-full", 
            isFullScreen ? "h-screen w-screen" : "p-4 sm:p-6 lg:p-8"
        )}>
            {!isFullScreen && (
                 <div className="flex items-center justify-between">
                    <div>
                        <PageHeader 
                            title="Agenda Clínica"
                            description="Visualização em tempo real dos agendamentos do dia para a recepção."
                            showFavoriteButton={false}
                        />
                    </div>
                     <Button variant="outline" onClick={toggleFullScreen}>
                        <Expand className="mr-2 h-4 w-4" />
                        Expandir
                    </Button>
                </div>
            )}
             {isFullScreen && (
                <div className="absolute top-4 right-4 z-50">
                    <Button variant="outline" onClick={toggleFullScreen}>
                        <Shrink className="mr-2 h-4 w-4" />
                        Recolher
                    </Button>
                </div>
            )}
            <div className="w-full flex-1 h-full">
                <PublicAgendaDisplay />
            </div>
        </div>
    );
}
