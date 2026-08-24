'use client';

import { DoctorAppointment } from '@/lib/types';
import { format } from 'date-fns';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';


interface AppointmentsListProps {
  appointments: DoctorAppointment[];
}

const getStatusBadgeClass = (status?: string) => {
  switch (status?.toLowerCase()) {
    case 'confirmado':
      return "bg-green-100 text-green-800 hover:bg-green-100 dark:bg-green-900/50 dark:text-green-300";
    case 'agendado':
      return "bg-blue-100 text-blue-800 hover:bg-blue-100 dark:bg-blue-900/50 dark:text-blue-300";
    case 'pendente':
      return "bg-yellow-100 text-yellow-800 hover:bg-yellow-100 dark:bg-yellow-900/50 dark:text-yellow-300";
    case 'cancelado':
      return "bg-red-100 text-red-800 hover:bg-red-100 dark:bg-red-900/50 dark:text-red-300";
    default:
      return "bg-gray-100 text-gray-800 hover:bg-gray-100 dark:bg-gray-900/50 dark:text-gray-300";
  }
};


export function AppointmentsList({ appointments }: AppointmentsListProps) {
  if (appointments.length === 0) {
    return (
      <div className="flex items-center justify-center h-40 text-sm text-muted-foreground">
        <p>Nenhuma consulta agendada para hoje.</p>
      </div>
    );
  }

  return (
    <div className="overflow-x-auto">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-[100px]">Horário</TableHead>
            <TableHead>Paciente</TableHead>
            <TableHead>Tipo</TableHead>
            <TableHead className="text-right">Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {appointments.map((appointment) => (
            <TableRow key={appointment.id}>
              <TableCell className="font-medium">{format(appointment.start, 'HH:mm')}</TableCell>
              <TableCell>{appointment.patientName}</TableCell>
              <TableCell className="capitalize">{appointment.type}</TableCell>
              <TableCell className="text-right">
                <Badge className={cn('capitalize', getStatusBadgeClass(appointment.status))}>
                  {appointment.status}
                </Badge>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
