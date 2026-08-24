'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { eachDayOfInterval, format, addDays, isSameDay, startOfDay, getDay, setHours, setMinutes, isBefore, isPast, addHours } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { Check, ChevronsUpDown, Clock, Heart, ArrowLeft, CalendarIcon, Timer } from 'lucide-react';
import { collection, query, where, getDocs, Timestamp, DocumentReference, doc, limit } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import type { DoctorProfile } from '@/lib/types';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command';
import { Calendar } from '@/components/ui/calendar';
import { useTotemSession } from '@/contexts/totem-session-context';


const HeartIcon = (props: React.SVGProps<SVGSVGElement>) => (
  <svg
    width="24"
    height="24"
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    {...props}
  >
    <path
      d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
      stroke="hsl(var(--primary))"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className="group-hover:fill-primary transition-colors"
    />
  </svg>
);

const specialties = [
    'Todos', 'Cardiologia', 'Dermatologia', 'Ortopedia', 'Pediatria', 'Ginecologia', 'Neurologia', 
    'Endocrinologia', 'Oftalmologia', 'Otorrinolaringologia', 'Urologia', 'Psiquiatria', 
    'Pneumologia', 'Reumatologia', 'Nefrologia', 'Gastroenterologia', 'Oncologia', 'Infectologia', 
    'Geriatria', 'Angiologia', 'Hematologia'
];


interface Doctor extends DoctorProfile {
    id: string;
    ref: DocumentReference;
}

interface AvailableSlot {
  time: string;
  doctor: Doctor;
  isPreBooked: boolean;
}

const generateTimeSlots = (startStr: string, endStr: string, selectedDate: Date): string[] => {
    const slots: string[] = [];
    if (!startStr || !endStr) return slots;

    const [startHour, startMinute] = startStr.split(':').map(Number);
    const [endHour, endMinute] = endStr.split(':').map(Number);

    let currentTime = setMinutes(setHours(startOfDay(selectedDate), startHour), startMinute);
    const endTime = setMinutes(setHours(startOfDay(selectedDate), endHour), endMinute);

    while (isBefore(currentTime, endTime)) {
        slots.push(format(currentTime, 'HH:mm'));
        currentTime = addHours(currentTime, 1);
    }

    return slots;
}

const getInitials = (name: string | null | undefined) => {
    if (!name) return 'P';
    return name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
}


export default function RescheduleAppointmentPage() {
  const router = useRouter();
  const [selectedSpecialty, setSelectedSpecialty] = React.useState<string>('Todos');
  const [selectedDate, setSelectedDate] = React.useState<Date>(startOfDay(new Date()));
  const [selectedTime, setSelectedTime] = React.useState<string | null>(null);
  const [availableSlots, setAvailableSlots] = React.useState<AvailableSlot[]>([]);
  const [selectedDoctor, setSelectedDoctor] = React.useState<Doctor | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [loadingMessage, setLoadingMessage] = React.useState('Verificando horários...');
  const [popoverOpen, setPopoverOpen] = React.useState(false);
  const { sessionCountdown } = useTotemSession();

  const formatCountdown = (seconds: number) => {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${String(minutes).padStart(2, '0')}:${String(remainingSeconds).padStart(2, '0')}`;
  };


  React.useEffect(() => {
    const fetchAvailableSlots = async () => {
      setLoading(true);
      setSelectedTime(null);
      setSelectedDoctor(null);
      setAvailableSlots([]);

      try {
        setLoadingMessage('Buscando médicos...');
        const medicosRef = collection(db, 'tb_medicos');
        
        let medicosQuery;
        if (selectedSpecialty === 'Todos') {
            medicosQuery = query(medicosRef, limit(20)); // Limit to avoid fetching too many
        } else {
            medicosQuery = query(medicosRef, where('especialidades', 'array-contains', selectedSpecialty));
        }
        
        const medicosSnapshot = await getDocs(medicosQuery);

        if (medicosSnapshot.empty) {
          console.log(`Nenhum médico encontrado para a especialidade: ${selectedSpecialty}`);
          setAvailableSlots([]);
          setLoading(false);
          return;
        }

        const doctors: Doctor[] = medicosSnapshot.docs.map(doc => ({
            id: doc.id,
            ref: doc.ref,
            ...(doc.data() as DoctorProfile)
        }));
        
        setLoadingMessage('Verificando horários...');
        const dayOfWeek = getDay(selectedDate); // Sunday - 0, Monday - 1, ...
        const allPossibleSlots: Omit<AvailableSlot, 'isPreBooked'>[] = [];

        // Step 1: Get all possible slots from all doctors' schedules
        for (const doctor of doctors) {
            const hourScheduleRef = collection(db, 'tb_hour_atendimento_medico');
            const hourScheduleQuery = query(hourScheduleRef, where('idmedico', '==', doctor.ref), limit(1));
            const hourScheduleSnapshot = await getDocs(hourScheduleQuery);

            if (!hourScheduleSnapshot.empty) {
                const scheduleDoc = hourScheduleSnapshot.docs[0].data();
                
                if (scheduleDoc.statusSM && scheduleDoc.statusSM[dayOfWeek]) {
                     const startHour = scheduleDoc.hourStart?.[dayOfWeek];
                     const endHour = scheduleDoc.hourFinal?.[dayOfWeek];

                     if (startHour && endHour) {
                         // Generate slots based on the doctor's specific schedule for that day
                         const slotsForDay = generateTimeSlots(startHour, endHour, selectedDate);
                         slotsForDay.forEach(time => {
                             allPossibleSlots.push({ time, doctor });
                         });
                     }
                }
            }
        }
        
        if (allPossibleSlots.length === 0) {
             setAvailableSlots([]);
             setLoading(false);
             return;
        }

        // Step 2: Find all 'confirmed' or 'finalizado' appointments on that day to mark as unavailable
        const start = startOfDay(selectedDate);
        const end = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 23, 59, 59, 999);
        const appointmentsRef = collection(db, 'tb_agendamentos');
        const appointmentsQuery = query(appointmentsRef, 
            where('dataConsulta', '>=', start), 
            where('dataConsulta', '<=', end),
            where('status', 'in', ['confirmado', 'finalizado', 'agendado', 'pendente'])
        );
        const appointmentsSnapshot = await getDocs(appointmentsQuery);

        const existingAppointments = new Map<string, { status: string }>();
        appointmentsSnapshot.forEach(doc => {
            const data = doc.data();
            const appTime = format((data.dataConsulta as Timestamp).toDate(), 'HH:mm');
            const doctorId = (data.idMedico as DocumentReference)?.id;
            if (doctorId) {
              existingAppointments.set(`${appTime}-${doctorId}`, { status: data.status?.toLowerCase() || '' });
            }
        });
        
        // Step 3: Combine schedules with existing appointments
        const finalSlots = allPossibleSlots
            .map(slot => {
                const appointmentKey = `${slot.time}-${slot.doctor.id}`;
                const existing = existingAppointments.get(appointmentKey);
                
                const isConfirmedOrFinished = existing?.status === 'confirmado' || existing?.status === 'finalizado';
                const isPreBooked = !!existing && !isConfirmedOrFinished;

                // Return null for confirmed slots so we can filter them out
                if (isConfirmedOrFinished) {
                    return null;
                }

                return {
                    ...slot,
                    isPreBooked,
                };
            })
            .filter((slot): slot is AvailableSlot => slot !== null); // Type guard to remove nulls

        setAvailableSlots(finalSlots.sort((a, b) => a.time.localeCompare(b.time)));

      } catch (error) {
        console.error("Error fetching available slots: ", error);
        setAvailableSlots([]);
      } finally {
        setLoading(false);
        setLoadingMessage('');
      }
    };
    
    fetchAvailableSlots();
  }, [selectedDate, selectedSpecialty]);

  const handleTimeSelection = (slot: AvailableSlot) => {
    setSelectedTime(slot.time);
    setSelectedDoctor(slot.doctor);
  }

  const handleReschedule = () => {
    if (!selectedDoctor || !selectedTime || !selectedDate) return;

    const queryParams = new URLSearchParams({
      doctorId: selectedDoctor.id,
      doctorName: selectedDoctor.nomeCompleto,
      specialty: selectedDoctor.especialidades?.[0] || 'Clínico Geral',
      date: selectedDate.toISOString(),
      time: selectedTime,
      clinicId: selectedDoctor.idclinica instanceof DocumentReference ? selectedDoctor.idclinica.id : selectedDoctor.idclinica || '',
    });

    router.push(`/totem/confirm?${queryParams.toString()}`);
  }

  const weekStart = startOfDay(new Date());
  const weekDays = eachDayOfInterval({
    start: weekStart,
    end: addDays(weekStart, 6),
  });

  return (
    <div className="flex min-h-screen w-full items-center justify-center bg-muted/40 p-4">
      <Card className="w-full max-w-md shadow-2xl">
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle className="text-3xl font-bold tracking-tight text-primary">
              Remarcar Consulta
            </CardTitle>
             <div className="flex items-center gap-2 text-lg font-medium text-muted-foreground">
                <Timer className="h-6 w-6" />
                <span>{formatCountdown(sessionCountdown)}</span>
              </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-8">
          {/* Especialidade */}
          <div className="space-y-2">
            <label className="text-sm font-medium">Especialidade</label>
            <Popover open={popoverOpen} onOpenChange={setPopoverOpen}>
              <PopoverTrigger asChild>
                <Button
                  variant="outline"
                  role="combobox"
                  aria-expanded={popoverOpen}
                  className="w-full justify-between h-12 text-lg capitalize"
                >
                  {selectedSpecialty}
                  <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                </Button>
              </PopoverTrigger>
              <PopoverContent className="w-[--radix-popover-trigger-width] p-0">
                <Command>
                  <CommandInput placeholder="Pesquisar especialidade..." />
                  <CommandList>
                    <CommandEmpty>Nenhuma especialidade encontrada.</CommandEmpty>
                    <CommandGroup>
                      {specialties.map((specialty) => (
                        <CommandItem
                          key={specialty}
                          value={specialty}
                          onSelect={(currentValue) => {
                            setSelectedSpecialty(currentValue === 'todos' ? 'Todos' : currentValue)
                            setPopoverOpen(false)
                          }}
                          className="capitalize"
                        >
                          <Check
                            className={cn(
                              "mr-2 h-4 w-4",
                              selectedSpecialty.toLowerCase() === specialty.toLowerCase() ? "opacity-100" : "opacity-0"
                            )}
                          />
                          {specialty}
                        </CommandItem>
                      ))}
                    </CommandGroup>
                  </CommandList>
                </Command>
              </PopoverContent>
            </Popover>
          </div>

          {/* Data */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <label className="text-sm font-medium">Data</label>
              <Popover>
                <PopoverTrigger asChild>
                  <Button variant={"outline"} size="icon">
                    <CalendarIcon className="h-4 w-4" />
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0">
                  <Calendar
                    mode="single"
                    selected={selectedDate}
                    onSelect={(date) => {
                      if (date) {
                        setSelectedDate(startOfDay(date));
                      }
                    }}
                    disabled={(date) => isPast(date) && !isSameDay(date, new Date())}
                    initialFocus
                  />
                </PopoverContent>
              </Popover>
            </div>
            <div className="grid grid-cols-7 gap-2 text-center">
              {weekDays.map((day) => {
                const isPastDay = isPast(day) && !isSameDay(day, new Date());
                return (
                  <div
                    key={day.toString()}
                    onClick={() => !isPastDay && setSelectedDate(startOfDay(day))}
                    className={cn(
                      "flex flex-col items-center justify-center p-1 rounded-lg transition-colors",
                      isPastDay
                        ? "text-muted-foreground opacity-50 cursor-not-allowed"
                        : "cursor-pointer hover:bg-muted",
                      isSameDay(day, selectedDate) &&
                        !isPastDay &&
                        "bg-primary text-primary-foreground hover:bg-primary/90"
                    )}
                  >
                    <span className="text-xs uppercase">
                      {format(day, "EEE", { locale: ptBR })}
                    </span>
                    <span className="text-xl font-bold">
                      {format(day, "dd")}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Horário */}
          <div className="space-y-4">
            <label className="text-sm font-medium">Horário</label>
            {loading ? (
                <div className="flex items-center justify-center h-24 text-center text-muted-foreground bg-muted/50 rounded-md">
                    <p>{loadingMessage}</p>
                </div>
            ) : availableSlots.length > 0 ? (
                <div className="grid grid-cols-3 gap-3">
                {availableSlots.map((slot) => (
                    <Button
                        key={slot.time + slot.doctor.id}
                        variant={selectedTime === slot.time && selectedDoctor?.id === slot.doctor.id ? 'default' : 'outline'}
                        size="lg"
                        onClick={() => handleTimeSelection(slot)}
                        className={cn(
                            'h-12 text-base relative',
                             slot.isPreBooked && 'border-yellow-500 text-yellow-600',
                             selectedTime === slot.time && selectedDoctor?.id === slot.doctor.id && slot.isPreBooked && 'bg-yellow-500/80 text-white'
                        )}
                    >
                        {slot.isPreBooked && (
                            <Clock className="absolute top-1 right-1 h-3 w-3" />
                        )}
                        {slot.time}
                    </Button>
                ))}
                </div>
            ) : (
                <div className="flex items-center justify-center h-24 text-center text-muted-foreground bg-muted/50 rounded-md">
                    <p>Nenhum horário disponível para esta data e especialidade.</p>
                </div>
            )}
          </div>

          {/* Doctor Info */}
          {selectedDoctor && (
             <div className="space-y-4 pt-4 border-t">
                <label className="text-sm font-medium">Profissional Selecionado</label>
                <div className="flex items-start gap-4 rounded-lg border p-4 bg-muted/30">
                    <Avatar className="h-20 w-20 border-2 border-primary">
                        <AvatarImage src={selectedDoctor.fotoPerfil || undefined} alt={selectedDoctor.nomeCompleto} />
                        <AvatarFallback className="text-xl">{getInitials(selectedDoctor.nomeCompleto)}</AvatarFallback>
                    </Avatar>
                    <div className="space-y-1 flex-1">
                        <p className="font-bold text-lg text-primary">{selectedDoctor.nomeCompleto}</p>
                        <div className="flex flex-wrap gap-1">
                            {selectedDoctor.especialidades?.map(spec => (
                                <Badge key={spec} variant="secondary">{spec}</Badge>
                            ))}
                        </div>
                        <p className="text-sm text-muted-foreground pt-1">{selectedDoctor.crm}</p>
                        {selectedDoctor.biografia && (
                            <p className="text-xs text-muted-foreground pt-2 italic">
                                &quot;{selectedDoctor.biografia}&quot;
                            </p>
                        )}
                    </div>
                </div>
            </div>
          )}

          <div className="flex flex-col gap-4">
            <Button size="lg" className="w-full h-14 text-lg" disabled={!selectedTime || loading} onClick={handleReschedule}>
                Remarcar
            </Button>
            <Button asChild variant="ghost" className="w-full">
                <Link href="/totem">
                    <ArrowLeft className="mr-2 h-4 w-4" />
                    Voltar
                </Link>
            </Button>
          </div>

        </CardContent>
      </Card>
    </div>
  );
}
