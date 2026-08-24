
"use client";

import * as React from "react";
import {
  addMonths,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isSameDay,
  isSameMonth,
  isToday,
  startOfMonth,
  startOfWeek,
  subMonths,
} from "date-fns";
import { ChevronLeft, ChevronRight, Check, Clock, AlertTriangle } from "lucide-react";
import { collection, getDocs, query, Timestamp, DocumentReference, getDoc } from 'firebase/firestore';

import { db } from '@/lib/firebase';
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import type { CalendarEvent, DoctorProfile } from "@/lib/types";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Skeleton } from "../ui/skeleton";

const eventTypeColors: Record<string, string> = {
  confirmado: "bg-green-100 text-green-800 border-green-200 dark:bg-green-900/50 dark:text-green-300 dark:border-green-800/50",
  agendado: "bg-yellow-100 text-yellow-800 border-yellow-200 dark:bg-yellow-900/50 dark:text-yellow-300 dark:border-yellow-800/50",
  pendente: "bg-yellow-100 text-yellow-800 border-yellow-200 dark:bg-yellow-900/50 dark:text-yellow-300 dark:border-yellow-800/50",
  cancelado: "bg-red-100 text-red-800 border-red-200 dark:bg-red-900/50 dark:text-red-300 dark:border-red-800/50",
  falta: "bg-red-100 text-red-800 border-red-200 dark:bg-red-900/50 dark:text-red-300 dark:border-red-800/50",
  default: "bg-gray-100 text-gray-800 border-gray-200 dark:bg-gray-900/50 dark:text-gray-300 dark:border-gray-800/50",
};

const EventIcon = ({ eventType, status }: { eventType: 'appointment' | 'absence', status: string }) => {
    if (eventType === 'absence') {
        return <AlertTriangle className="h-3 w-3 mr-1.5 flex-shrink-0" />;
    }
    switch(status) {
        case 'confirmado':
            return <Check className="h-3 w-3 mr-1.5 flex-shrink-0" />;
        case 'agendado':
        case 'pendente':
            return <Clock className="h-3 w-3 mr-1.5 flex-shrink-0" />;
        default:
            return null;
    }
}


export function FullCalendar() {
  const [currentDate, setCurrentDate] = React.useState(new Date());
  const [events, setEvents] = React.useState<CalendarEvent[]>([]);
  const [loading, setLoading] = React.useState(true);
  
  React.useEffect(() => {
    const fetchEvents = async () => {
      setLoading(true);
      try {
        const medicoCache: { [key: string]: DoctorProfile } = {};

        const getMedico = async (ref: DocumentReference): Promise<DoctorProfile | null> => {
            if (medicoCache[ref.id]) {
                return medicoCache[ref.id];
            }
            try {
                const docSnap = await getDoc(ref);
                if (docSnap.exists()) {
                    const medicoData = docSnap.data() as DoctorProfile;
                    medicoCache[ref.id] = medicoData;
                    return medicoData;
                }
                return null;
            } catch (e) {
                console.error("Error fetching doctor:", e);
                return null;
            }
        };

        // 1. Fetch ALL Appointments
        const appointmentsRef = collection(db, 'tb_agendamentos');
        const appointmentsQuery = query(appointmentsRef);
        const appointmentsSnapshot = await getDocs(appointmentsQuery);

        const appointmentEventsPromises: Promise<CalendarEvent | null>[] = appointmentsSnapshot.docs.map(async (doc) => {
          const data = doc.data();
          if (data.dataConsulta && data.dataConsulta.toDate) {
            const startDate = (data.dataConsulta as Timestamp).toDate();
            let doctorName = data.nomeMedico || 'N/A';

            if (data.idMedico instanceof DocumentReference) {
                const medico = await getMedico(data.idMedico);
                if(medico) doctorName = medico.nomeCompleto;
            }

            return {
              id: doc.id,
              title: data.motivoConsulta || 'Consulta',
              start: startDate,
              end: new Date(startDate.getTime() + 60 * 60 * 1000),
              type: 'appointment',
              status: data.status?.toLowerCase() || 'desconhecido',
              patientName: data.nomePaciente || 'N/A',
              doctorName: doctorName,
            };
          }
          return null;
        });
        
        const appointmentEvents = (await Promise.all(appointmentEventsPromises)).filter(e => e !== null) as CalendarEvent[];

        // 2. Fetch ALL Absence Alerts
        const absenceRef = collection(db, 'tb_faltas_data');
        const absenceQuery = query(absenceRef);
        const absenceSnapshot = await getDocs(absenceQuery);

        const absenceEventsPromises: Promise<CalendarEvent | null>[] = absenceSnapshot.docs.map(async (doc) => {
            const data = doc.data();
            if (data.data_falta_consulta && data.data_falta_consulta.toDate) {
                let patientName = "N/A";
                let doctorName = "N/A";

                if (data.idConsulta instanceof DocumentReference) {
                    try {
                        const agendamentoSnap = await getDoc(data.idConsulta);
                        if (agendamentoSnap.exists()) {
                            const agendamentoData = agendamentoSnap.data();
                            patientName = agendamentoData.nomePaciente || 'N/A';
                            
                            if (agendamentoData.idMedico instanceof DocumentReference) {
                                const medico = await getMedico(agendamentoData.idMedico);
                                if (medico) doctorName = medico.nomeCompleto;
                            }
                        }
                    } catch (e) {
                         console.error("Error fetching appointment for absence:", e);
                    }
                }
                
                const startDate = (data.data_falta_consulta as Timestamp).toDate();
                return {
                    id: doc.id,
                    title: `Risco de Falta: ${patientName}`,
                    start: startDate,
                    end: new Date(startDate.getTime() + 60 * 60 * 1000),
                    type: 'absence',
                    status: 'falta',
                    patientName: patientName,
                    doctorName: doctorName,
                };
            }
            return null;
        });
        
        const absenceEvents = (await Promise.all(absenceEventsPromises)).filter(e => e !== null) as CalendarEvent[];

        setEvents([...appointmentEvents, ...absenceEvents]);

      } catch (error) {
        console.error("Failed to fetch calendar events:", error);
        setEvents([]);
      } finally {
        setLoading(false);
      }
    }
    fetchEvents();
  }, []);

  const nextMonth = () => setCurrentDate(addMonths(currentDate, 1));
  const prevMonth = () => setCurrentDate(subMonths(currentDate, 1));

  const start = startOfWeek(startOfMonth(currentDate));
  const end = endOfWeek(endOfMonth(currentDate));
  const days = eachDayOfInterval({ start, end });
  
  if (loading) {
      return (
          <div className="rounded-lg border bg-card text-card-foreground shadow-sm">
            <div className="p-4 flex justify-between items-center border-b">
                <Skeleton className="h-8 w-48" />
                <Skeleton className="h-8 w-24" />
            </div>
            <div className="grid grid-cols-7">
                {[...Array(7)].map((_, i) => <div key={i} className="p-2 border-r border-b"><Skeleton className="h-6 w-12"/></div>)}
                {[...Array(35)].map((_, i) => <div key={i} className="h-40 p-2 border-r border-b"><Skeleton className="h-full w-full"/></div>)}
            </div>
          </div>
      )
  }

  return (
    <TooltipProvider>
      <div className="rounded-lg border bg-card text-card-foreground shadow-sm">
        <div className="flex items-center justify-between p-4 border-b">
          <div className="flex items-center gap-2">
            <Button variant="outline" size="icon" onClick={prevMonth}>
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <h2 className="text-lg font-semibold font-headline w-32 text-center">
              {format(currentDate, "MMMM yyyy")}
            </h2>
            <Button variant="outline" size="icon" onClick={nextMonth}>
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
          <Button variant="outline" onClick={() => setCurrentDate(new Date())}>Today</Button>
        </div>
        <div className="grid grid-cols-7">
          {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map((day) => (
            <div key={day} className="p-2 text-center text-sm font-medium text-muted-foreground border-r border-b">
              {day}
            </div>
          ))}
          {days.map((day) => {
            const dayEvents = events.filter((event) =>
              isSameDay(day, event.start)
            );
            return (
              <div
                key={day.toString()}
                className={cn(
                  "h-40 p-2 border-r border-b flex flex-col gap-1 overflow-hidden",
                  !isSameMonth(day, currentDate) && "bg-muted/50 text-muted-foreground"
                )}
              >
                <time
                  dateTime={format(day, "yyyy-MM-dd")}
                  className={cn(
                    "h-8 w-8 flex items-center justify-center rounded-full text-sm",
                    isToday(day) && "bg-primary text-primary-foreground"
                  )}
                >
                  {format(day, "d")}
                </time>
                <div className="flex-1 overflow-y-auto -mx-1 px-1 space-y-1">
                  {dayEvents.map((event) => (
                    <Tooltip key={event.id}>
                      <TooltipTrigger asChild>
                        <div
                          className={cn(
                            "rounded-md p-1.5 text-xs border cursor-pointer flex items-center",
                            eventTypeColors[event.status.toLowerCase()] || eventTypeColors.default
                          )}
                        >
                           <EventIcon eventType={event.type} status={event.status.toLowerCase()} />
                           <div className="flex-1 overflow-hidden">
                             <p className="font-semibold truncate">{event.title}</p>
                             <p className="truncate">{format(event.start, "h:mm a")}</p>
                           </div>
                        </div>
                      </TooltipTrigger>
                      <TooltipContent>
                        <p className="font-bold">{event.title}</p>
                        {event.patientName && <p>Paciente: {event.patientName}</p>}
                        {event.doctorName && <p>Médico: {event.doctorName}</p>}
                        <p>{format(event.start, "MMMM d, h:mm a")}</p>
                        <Badge variant="secondary" className="capitalize mt-1">{event.status.replace(/_/g, ' ')}</Badge>
                      </TooltipContent>
                    </Tooltip>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </TooltipProvider>
  );
}

    