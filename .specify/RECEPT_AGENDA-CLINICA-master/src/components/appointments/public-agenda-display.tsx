
'use client';

import * as React from 'react';
import { collection, query, where, orderBy, getDocs, Timestamp, onSnapshot, Unsubscribe } from 'firebase/firestore';
import { format } from "date-fns";
import { ptBR } from 'date-fns/locale';
import { startOfToday, endOfToday } from 'date-fns';

import { db } from "@/lib/firebase";
import { Skeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Clock, UserCheck, Video, CheckCircle, Hourglass } from 'lucide-react';
import { Badge } from '../ui/badge';
import { cn } from '@/lib/utils';

interface AgendaItem {
    id: string;
    hora: string;
    paciente: string;
    medico: string;
    sala: string;
    status: string;
}

const getStatusStyles = (status: string) => {
    switch (status?.toLowerCase()) {
        case 'aguardando':
            return {
                icon: <Hourglass className="h-4 w-4" />,
                className: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300',
            };
        case 'em atendimento':
            return {
                icon: <UserCheck className="h-4 w-4" />,
                className: 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-300',
            };
         case 'finalizado':
            return {
                icon: <CheckCircle className="h-4 w-4" />,
                className: 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300',
            };
        default:
            return {
                icon: <Clock className="h-4 w-4" />,
                className: 'bg-gray-100 text-gray-800 dark:bg-gray-900/20 dark:text-gray-300',
            };
    }
};


const AgendaRowSkeleton = () => (
    <TableRow>
        <TableCell><Skeleton className="h-5 w-16" /></TableCell>
        <TableCell><Skeleton className="h-5 w-48" /></TableCell>
        <TableCell><Skeleton className="h-5 w-48" /></TableCell>
        <TableCell><Skeleton className="h-5 w-24" /></TableCell>
        <TableCell><Skeleton className="h-5 w-32" /></TableCell>
    </TableRow>
)

export function PublicAgendaDisplay() {
  const [agenda, setAgenda] = React.useState<AgendaItem[]>([]);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    setLoading(true);
    const appointmentsRef = collection(db, 'tb_agendamentos');
    const todayStart = startOfToday();
    const todayEnd = endOfToday();

    const q = query(
      appointmentsRef,
      where('dataConsulta', '>=', todayStart),
      where('dataConsulta', '<=', todayEnd),
      // Filter for statuses relevant to a public display
      where('status', 'in', ['confirmado', 'agendado', 'pendente']),
      orderBy('dataConsulta', 'asc')
    );

    const unsubscribe = onSnapshot(q, (querySnapshot) => {
      const fetchedAgenda = querySnapshot.docs.map((doc) => {
        const data = doc.data();
        const dataConsulta = (data.dataConsulta as Timestamp).toDate();

        // Anonymize patient name - show first name and last initial
        const nomeParts = (data.nomePaciente || 'Paciente').split(' ');
        const pacienteAnonimo = nomeParts.length > 1 
          ? `${nomeParts[0]} ${nomeParts[nomeParts.length - 1].charAt(0)}.` 
          : nomeParts[0];

        return {
          id: doc.id,
          hora: format(dataConsulta, "HH:mm"),
          paciente: pacienteAnonimo,
          medico: data.nomeMedico || 'N/D',
          sala: data.nomeSala || 'N/D',
          // This status is what is shown on the public screen, e.g., 'Aguardando', 'Em atendimento'
          status: data.statusAtendimento || 'Aguardando',
        };
      });
      setAgenda(fetchedAgenda);
      setLoading(false);
    }, (error) => {
       console.error("Error fetching real-time agenda: ", error);
       setLoading(false);
    });

    // Cleanup subscription on unmount
    return () => unsubscribe();

  }, []);

  return (
    <div className="w-full h-full rounded-lg border bg-card text-card-foreground shadow-sm flex flex-col">
        <Table>
          <TableHeader>
            <TableRow className="bg-primary/80 hover:bg-primary/80">
              <TableHead className="w-[100px] text-primary-foreground font-bold text-lg">Hora</TableHead>
              <TableHead className="text-primary-foreground font-bold text-lg">Paciente</TableHead>
              <TableHead className="text-primary-foreground font-bold text-lg">Médico</TableHead>
              <TableHead className="w-[120px] text-primary-foreground font-bold text-lg">Sala</TableHead>
              <TableHead className="w-[200px] text-primary-foreground font-bold text-lg">Status</TableHead>
            </TableRow>
          </TableHeader>
        </Table>
        <div className="flex-1 overflow-y-auto">
             <Table>
                <TableBody>
                    {loading ? (
                        <>
                            <AgendaRowSkeleton />
                            <AgendaRowSkeleton />
                            <AgendaRowSkeleton />
                            <AgendaRowSkeleton />
                            <AgendaRowSkeleton />
                            <AgendaRowSkeleton />
                        </>
                    ) : agenda.length > 0 ? (
                    agenda.map((item) => {
                        const statusInfo = getStatusStyles(item.status);
                        return (
                            <TableRow key={item.id} className="text-lg">
                            <TableCell className="font-medium w-[100px]">{item.hora}</TableCell>
                            <TableCell>{item.paciente}</TableCell>
                            <TableCell>{item.medico}</TableCell>
                            <TableCell className="w-[120px]">{item.sala}</TableCell>
                            <TableCell className="w-[200px]">
                                <Badge className={cn("text-base font-semibold gap-2 py-1.5 px-3 capitalize", statusInfo.className)}>
                                    {statusInfo.icon}
                                    {item.status}
                                </Badge>
                            </TableCell>
                            </TableRow>
                        )
                        })
                    ) : (
                    <TableRow>
                        <TableCell
                        colSpan={5}
                        className="h-48 text-center"
                        >
                            <div className='flex flex-col items-center justify-center gap-2 text-muted-foreground'>
                                <Clock className='w-10 h-10' />
                                <span>Nenhuma consulta agendada para hoje.</span>
                            </div>
                        </TableCell>
                    </TableRow>
                    )}
                </TableBody>
            </Table>
        </div>
    </div>
  );
}
