
'use client';

import * as React from 'react';
import { AppointmentsChart } from "@/components/dashboard/appointments-chart";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { UpcomingAppointments } from "@/components/dashboard/upcoming-appointments";
import { getDashboardMetrics } from "@/lib/metrics";
import { AppointmentStatusPieChart } from "@/components/dashboard/appointment-status-pie-chart";
import { DoctorPerformanceRadarChart } from "@/components/dashboard/doctor-performance-radar-chart";
import { PageHeader } from "@/components/page-header";
import { useAuth } from '@/contexts/auth-context';
import { Skeleton } from '@/components/ui/skeleton';


export default function DashboardPage() {
  const { clinicId, loading: authLoading } = useAuth();
  const [metrics, setMetrics] = React.useState<any>(null);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    const fetchMetrics = async () => {
      setLoading(true);
      try {
        const fetchedMetrics = await getDashboardMetrics();
        setMetrics(fetchedMetrics);
      } catch (error) {
        console.error("Failed to fetch dashboard metrics:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchMetrics();
  }, []);

  if (loading || authLoading || !metrics) {
    return (
        <div className="flex flex-col gap-8">
            <PageHeader 
                title="Dashboard"
                description="Uma visão geral completa de seus agendamentos e métricas de desempenho."
            />
             <div className="grid grid-cols-1 gap-8">
                {/* Skeleton for Upcoming Appointments Carousel */}
                <Card>
                    <CardHeader>
                       <Skeleton className="h-6 w-1/3 mb-2" />
                       <Skeleton className="h-4 w-2/3" />
                    </CardHeader>
                    <CardContent>
                       <div className="flex space-x-4">
                           <Skeleton className="h-48 w-full" />
                           <Skeleton className="h-48 w-full" />
                           <Skeleton className="h-48 w-full" />
                       </div>
                    </CardContent>
                </Card>

                <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
                    <Skeleton className="lg:col-span-2 h-[400px]" />
                    <Skeleton className="h-[400px]" />
                </div>
                 <div className="grid grid-cols-1 gap-8 lg:grid-cols-5">
                    <Skeleton className="lg:col-span-3 h-[400px]" />
                    <Skeleton className="lg:col-span-2 h-[400px]" />
                </div>
            </div>
        </div>
    );
  }


  return (
    <div className="flex flex-col gap-8">
      <PageHeader 
        title="Dashboard"
        description="Uma visão geral completa de seus agendamentos e métricas de desempenho."
      />

      <div className="grid grid-cols-1 gap-8">
        
        <Card>
            <CardHeader>
                <CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Próximas Consultas do Dia</CardTitle>
                <CardDescription>Acompanhe os próximos agendamentos confirmados para hoje.</CardDescription>
            </CardHeader>
            <CardContent>
                <UpcomingAppointments />
            </CardContent>
        </Card>
        
        <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
            <Card className="lg:col-span-2">
                <CardHeader>
                    <CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Tendência de Agendamentos</CardTitle>
                    <CardDescription>Total de agendamentos mensais no último ano.</CardDescription>
                </CardHeader>
                <CardContent>
                    <AppointmentsChart data={metrics.appointmentsChartData} />
                </CardContent>
            </Card>
             <Card className="lg:col-span-1">
              <CardHeader>
                <CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Status dos Agendamentos</CardTitle>
                <CardDescription>Distribuição dos status de agendamentos este mês.</CardDescription>
              </CardHeader>
              <CardContent>
                <AppointmentStatusPieChart data={metrics.appointmentStatusPieChartData} />
              </CardContent>
            </Card>
        </div>
        
         <div className="grid grid-cols-1 gap-8 lg:grid-cols-5">
            <Card className="lg:col-span-5">
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
