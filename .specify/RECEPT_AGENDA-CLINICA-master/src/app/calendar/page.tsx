
import { FullCalendar } from "@/components/calendar/full-calendar";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { AppointmentsChart } from "@/components/dashboard/appointments-chart";
import { AppointmentStatusPieChart } from "@/components/dashboard/appointment-status-pie-chart";
import { DoctorPerformanceRadarChart } from "@/components/dashboard/doctor-performance-radar-chart";
import { getDashboardMetrics } from "@/lib/metrics";
import { ConsultationsBarChart } from "@/components/doctor-dashboard/consultations-bar-chart";
import { eachDayOfInterval, format, startOfWeek, endOfWeek } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { collection, getDocs, Timestamp, query, where } from 'firebase/firestore';
import { db } from "@/lib/firebase";
import { PageHeader } from "@/components/page-header";

 
export default async function CalendarPage() {
  const metrics = await getDashboardMetrics();
  
  // Logic for daily appointments chart (bar chart)
  const appointmentsRef = collection(db, "tb_agendamentos");
  const q = query(appointmentsRef, where("dataConsulta", "!=", null));
  const querySnapshot = await getDocs(q);
  const allAppointments = querySnapshot.docs.map(doc => {
      const data = doc.data();
      // Ensure dataConsulta is a valid Date object before formatting
      if (data.dataConsulta && typeof data.dataConsulta.toDate === 'function') {
        return {
          ...data,
          dataConsulta: (data.dataConsulta as Timestamp).toDate(),
        }
      }
      // Handle cases where dataConsulta might be missing or not a Timestamp
      return {
        ...data,
        dataConsulta: new Date(), // Or some other default/error handling
      };
  });

  const weekStart = startOfWeek(new Date());
  const weekEnd = endOfWeek(new Date());
  const weekDays = eachDayOfInterval({ start: weekStart, end: weekEnd });

  const appointmentsByDay = weekDays.map(day => {
    const count = allAppointments.filter(
      a => format(a.dataConsulta, 'yyyy-MM-dd') === format(day, 'yyyy-MM-dd')
    ).length;
    return {
      name: format(day, 'EEE', { locale: ptBR }),
      total: count,
    };
  });


  return (
    <div className="flex flex-col gap-8">
      <PageHeader 
        title="Calendário"
        description="Visualize e gerencie as consultas e alertas de falta da clínica."
      />
      <FullCalendar />
      
      <div className="mt-8">
         <h2 className="font-headline text-2xl font-semibold mb-4 bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Análise de Agendamentos</h2>
         <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Status dos Agendamentos</CardTitle>
                <CardDescription>Distribuição dos status de agendamentos.</CardDescription>
              </CardHeader>
              <CardContent>
                <AppointmentStatusPieChart data={metrics.appointmentStatusPieChartData} />
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Consultas na Semana</CardTitle>
                <CardDescription>Volume de agendamentos por dia da semana.</CardDescription>
              </CardHeader>
              <CardContent>
                <ConsultationsBarChart data={appointmentsByDay} />
              </CardContent>
            </Card>
             <Card className="lg:col-span-2">
                <CardHeader>
                    <CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Tendência de Agendamentos</CardTitle>
                    <CardDescription>Total de agendamentos mensais no último ano.</CardDescription>
                </CardHeader>
                <CardContent>
                    <AppointmentsChart data={metrics.appointmentsChartData} />
                </CardContent>
            </Card>
            <Card className="lg:col-span-2">
                <CardHeader>
                    <CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Desempenho por Médico</CardTitle>
                    <CardDescription>Comparativo de métricas chave entre médicos.</CardDescription>
                </CardHeader>
                <CardContent className="pt-4">
                    <DoctorPerformanceRadarChart data={metrics.doctorPerformanceRadarChartData} />
                </CardContent>
            </Card>
         </div>
      </div>
    </div>
  );
}
