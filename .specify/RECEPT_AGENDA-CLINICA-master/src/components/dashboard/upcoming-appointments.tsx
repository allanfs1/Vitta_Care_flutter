'use client';

import * as React from 'react';
import { collection, query, where, orderBy, getDocs, Timestamp, getDoc, DocumentReference } from 'firebase/firestore';
import { format, startOfToday, endOfToday } from "date-fns";
import { ptBR } from 'date-fns/locale';

import { db } from "@/lib/firebase";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";
import type { UserProfile } from '@/lib/types';
import {
  Carousel,
  CarouselContent,
  CarouselItem,
  CarouselNext,
  CarouselPrevious,
} from "@/components/ui/carousel";
import { Card, CardContent } from '../ui/card';
import { cn } from '@/lib/utils';
import { Clock } from 'lucide-react';


interface FetchedAppointment {
    id: string;
    title: string;
    start: Date;
    pacienteName: string;
    pacientePhotoUrl?: string; 
    tipo: string;
    especialidade: string;
    responsible: {
        name: string;
    };
}

const AppointmentCardSkeleton = () => (
    <CarouselItem className="pl-4 md:basis-1/2 lg:basis-1/3">
        <div className="p-1">
            <Card>
                <CardContent className="flex flex-col items-start gap-4 p-6">
                    <div className="flex items-center gap-4">
                        <Skeleton className="h-12 w-12 rounded-full" />
                        <div className='space-y-2'>
                            <Skeleton className="h-5 w-32" />
                            <Skeleton className="h-4 w-48" />
                        </div>
                    </div>
                     <Skeleton className="h-4 w-full" />
                     <Skeleton className="h-4 w-3/4" />
                </CardContent>
            </Card>
        </div>
    </CarouselItem>
);

export function UpcomingAppointments() {
  const [appointments, setAppointments] = React.useState<FetchedAppointment[]>([]);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    const fetchUpcomingAppointments = async () => {
      try {
        const appointmentsRef = collection(db, 'tb_agendamentos');
        const todayStart = startOfToday();
        const todayEnd = endOfToday();

        const q = query(
          appointmentsRef,
          where('dataConsulta', '>=', todayStart),
          where('dataConsulta', '<=', todayEnd),
          where('status', 'in', ['confirmado', 'agendado']),
          orderBy('dataConsulta', 'asc')
        );

        const querySnapshot = await getDocs(q);
        
        const upcomingAppointmentsPromises = querySnapshot.docs.map(async (docSnapshot) => {
          const data = docSnapshot.data();
          let pacientePhotoUrl: string | undefined;

          if (data.idpaciente && data.idpaciente instanceof DocumentReference) {
              try {
                const userDocSnap = await getDoc(data.idpaciente);
                if (userDocSnap.exists()) {
                    const userData = userDocSnap.data() as UserProfile;
                    pacientePhotoUrl = userData.photo_url;
                }
              } catch(e) {
                  console.error("Error fetching patient profile for upcoming appointment", e);
              }
          }
          
          return {
            id: docSnapshot.id,
            title: data.motivoConsulta || 'Consulta',
            start: (data.dataConsulta as Timestamp).toDate(),
            pacienteName: data.nomePaciente || 'Paciente não informado',
            pacientePhotoUrl,
            tipo: data.tipoConsulta || 'Não informado',
            especialidade: data.especialidade || 'Não informada',
            responsible: {
              name: data.nomeMedico || 'Médico não informado',
            },
          };
        });
        
        const upcomingAppointments = await Promise.all(upcomingAppointmentsPromises);

        setAppointments(upcomingAppointments);
      } catch (error) {
        console.error("Error fetching upcoming appointments: ", error);
      } finally {
        setLoading(false);
      }
    };

    fetchUpcomingAppointments();
  }, []);

  const getInitials = (name: string | null | undefined) => {
    if (!name) return 'P';
    return name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
  }

  if (loading) {
    return (
       <Carousel opts={{ align: "start" }} className="w-full">
            <CarouselContent className="-ml-4">
                <AppointmentCardSkeleton />
                <AppointmentCardSkeleton />
                <AppointmentCardSkeleton />
            </CarouselContent>
            <CarouselPrevious />
            <CarouselNext />
       </Carousel>
    );
  }

  if (appointments.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-32 text-sm text-muted-foreground rounded-lg border border-dashed">
         <Clock className="w-8 h-8 mb-2" />
        <span>Nenhuma consulta confirmada para hoje.</span>
      </div>
    );
  }

  return (
    <Carousel
      opts={{
        align: "start",
        loop: appointments.length > 2,
      }}
      className="w-full"
    >
      <CarouselContent className="-ml-4">
        {appointments.map((appointment, index) => (
           <CarouselItem key={appointment.id} className="pl-4 md:basis-1/2 lg:basis-1/3">
              <div className="p-1 h-full">
                <Card className="h-full border-l-4 border-primary shadow-sm hover:shadow-md transition-shadow">
                    <CardContent className="flex flex-col items-start justify-center gap-3 p-6 h-full">
                        <div className="flex items-center gap-4">
                            <Avatar className="h-12 w-12 border">
                                <AvatarImage
                                    src={appointment.pacientePhotoUrl || undefined}
                                    alt={appointment.pacienteName}
                                    data-ai-hint="person portrait"
                                />
                                <AvatarFallback className='text-lg'>
                                    {getInitials(appointment.pacienteName)}
                                </AvatarFallback>
                            </Avatar>
                             <div className="flex-1 text-sm">
                                <p className="text-base font-bold text-primary">{appointment.title}</p>
                                <p className="font-semibold text-card-foreground">
                                    {appointment.pacienteName}
                                </p>
                            </div>
                        </div>

                        <div className='space-y-1 text-sm'>
                            <p className="text-muted-foreground">
                                <span className='text-accent font-medium'>Dr(a). </span>{appointment.responsible.name} ({appointment.especialidade})
                            </p>
                            <p className='font-bold text-lg text-card-foreground'>
                                {format(appointment.start, "HH:mm")}h
                            </p>
                            <p className='text-muted-foreground'>
                                <span className='text-accent font-medium'>Tipo: </span>{appointment.tipo}
                            </p>
                        </div>
                    </CardContent>
                </Card>
              </div>
            </CarouselItem>
        ))}
      </CarouselContent>
      <CarouselPrevious className="ml-12" />
      <CarouselNext className="mr-12" />
    </Carousel>
  );
}
