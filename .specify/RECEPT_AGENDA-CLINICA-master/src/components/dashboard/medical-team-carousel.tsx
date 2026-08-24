'use client';

import Image from "next/image";
import * as React from 'react';
import { collection, getDocs, query, where, limit } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import {
  Carousel,
  CarouselContent,
  CarouselItem,
  CarouselNext,
  CarouselPrevious,
} from "@/components/ui/carousel";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import type { DoctorProfile } from "@/lib/types";


interface MedicalTeamMember extends DoctorProfile {
    id: string;
}

interface MedicalTeamCarouselProps {
    clinicId: string;
}

export function MedicalTeamCarousel({ clinicId }: MedicalTeamCarouselProps) {
  const [team, setTeam] = React.useState<MedicalTeamMember[]>([]);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    const fetchTeam = async () => {
        if (!clinicId) {
            console.log("MedicalTeamCarousel: clinicId is missing, cannot fetch team.");
            setLoading(false);
            setTeam([]);
            return;
        }

        setLoading(true);
        try {
            console.log(`Fetching doctors for clinicId: ${clinicId}`);
            const medicosRef = collection(db, "tb_medicos");
            
            // This query assumes `idclinica` is stored as a STRING in the Firestore documents.
            const q = query(
                medicosRef, 
                where("idclinica", "==", clinicId),
                limit(10)
            );

            const querySnapshot = await getDocs(q);

            if (querySnapshot.empty) {
                console.warn(`No doctors found for clinicId: ${clinicId}`);
            }

            const fetchedTeam = querySnapshot.docs.map(doc => ({
                id: doc.id,
                ...(doc.data() as DoctorProfile)
            }));
            
            setTeam(fetchedTeam);

        } catch (error) {
            console.error("Failed to fetch medical team:", error);
            setTeam([]);
        } finally {
            setLoading(false);
        }
    }
    fetchTeam();
  }, [clinicId]);


  if (loading) {
      return (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {[...Array(3)].map((_, i) => (
                   <Card key={i}>
                       <CardContent className="flex flex-col items-center p-8 text-center h-full">
                           <Skeleton className="h-[100px] w-[100px] rounded-full mb-4" />
                           <Skeleton className="h-6 w-3/4 mb-2" />
                           <Skeleton className="h-4 w-1/2" />
                       </CardContent>
                   </Card>
              ))}
          </div>
      )
  }
  
  if (team.length === 0) {
      return (
          <div className="flex items-center justify-center h-40 text-sm text-muted-foreground border rounded-lg">
              <p>Nenhum membro da equipe encontrado para esta clínica.</p>
          </div>
      )
  }


  return (
    <Carousel
      opts={{
        align: "start",
        loop: team.length > 2,
      }}
      className="w-full"
    >
      <CarouselContent className="-ml-4">
        {team.map((member, index) => {
          const isPrimaryTheme = index % 2 === 0;
          return (
            <CarouselItem key={member.id} className="pl-4 md:basis-1/2 lg:basis-1/3">
              <Card className={cn(
                  "overflow-hidden transition-all duration-300 h-full border-2 border-transparent",
                  isPrimaryTheme ? "hover:border-primary/30" : "hover:border-accent/30"
              )}>
                <CardContent className={cn(
                    "flex flex-col items-center p-8 text-center h-full",
                    isPrimaryTheme ? "bg-primary/5 dark:bg-primary/10" : "bg-accent/10 dark:bg-accent/20"
                )}>
                  <Image
                    src={member.fotoPerfil || "https://placehold.co/100x100.png"}
                    alt={`Foto de ${member.nomeCompleto}`}
                    width={100}
                    height={100}
                    className="rounded-full border-4 border-background object-cover shadow-lg mb-4"
                    data-ai-hint="person portrait"
                  />
                  <h3 className="text-xl font-bold font-headline text-card-foreground">{member.nomeCompleto}</h3>
                  <p className={cn(
                      "font-semibold text-sm",
                      isPrimaryTheme ? "text-primary" : "text-accent-foreground"
                  )}>{member.especialidades?.join(', ')}</p>
                  <p className="mt-2 text-sm text-muted-foreground">{member.crm}</p>
                </CardContent>
              </Card>
            </CarouselItem>
          );
        })}
      </CarouselContent>
      <CarouselPrevious className="ml-12" />
      <CarouselNext className="mr-12" />
    </Carousel>
  );
}
