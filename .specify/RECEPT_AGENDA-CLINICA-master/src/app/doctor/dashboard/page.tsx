
'use client';

import * as React from 'react';
import { useAuth } from '@/contexts/auth-context';
import { getDoctorDashboardMetrics } from '@/lib/doctor-metrics';
import { DoctorMetrics } from '@/lib/types';
import { LoadingScreen } from '@/components/loading-screen';
import { AppointmentsList } from '@/components/doctor-dashboard/appointments-list';
import { ConsultationsBarChart } from '@/components/doctor-dashboard/consultations-bar-chart';
import { WeeklyConsultationsChart } from '@/components/doctor-dashboard/weekly-consultations-chart';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { ConsultationTypePieChart } from '@/components/doctor-dashboard/consultation-type-pie-chart';
import { PersonalPerformanceRadarChart } from '@/components/doctor-dashboard/personal-performance-radar-chart';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { ChevronsUpDown, Expand } from 'lucide-react';
import { AbsenceInsights } from '@/components/doctor-dashboard/absence-insights';
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';

type ChartKey = 'consultationTypes' | 'performance' | 'weeklyConsultations' | 'recentAttendances';

export default function DoctorDashboardPage() {
  const { user } = useAuth();
  const [metrics, setMetrics] = React.useState<DoctorMetrics | null>(null);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    if (user?.email) {
      const fetchMetrics = async () => {
        setLoading(true);
        try {
          const fetchedMetrics = await getDoctorDashboardMetrics(user.email!);
          setMetrics(fetchedMetrics);
        } catch (error) {
          console.error("Failed to fetch doctor metrics:", error);
          setMetrics(null);
        } finally {
          setLoading(false);
        }
      };
      fetchMetrics();
    } else if (!user) {
        setLoading(false);
    }
  }, [user]);

  if (loading) {
    return <LoadingScreen />;
  }

  if (!metrics) {
    return (
      <div className="flex items-center justify-center h-full">
        <p>Não foi possível carregar as métricas do médico.</p>
      </div>
    );
  }

  const today = format(new Date(), "dd 'de' MMMM 'de' yyyy", { locale: ptBR });
  
  const chartComponents: Record<ChartKey, { title: string; component: React.ReactNode }> = {
    consultationTypes: {
      title: "Tipos de Consulta (Mês)",
      component: <ConsultationTypePieChart data={metrics.consultationTypes} />,
    },
    performance: {
      title: "Desempenho Pessoal",
      component: <PersonalPerformanceRadarChart data={metrics.performance} />,
    },
    weeklyConsultations: {
      title: "Consultas na Semana",
      component: <WeeklyConsultationsChart data={metrics.weeklyConsultations} />,
    },
    recentAttendances: {
      title: "Atendimentos Recentes",
      component: <ConsultationsBarChart data={metrics.consultationsStats} />,
    },
  };

  const renderChartCard = (key: ChartKey) => {
    const { title, component } = chartComponents[key];
    return (
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-xl font-headline text-primary">{title}</CardTitle>
           <Dialog>
              <DialogTrigger asChild>
                <Button variant="ghost" size="icon">
                  <Expand className="h-4 w-4" />
                </Button>
              </DialogTrigger>
              <DialogContent className="max-w-4xl h-4/5 flex flex-col">
                  <DialogHeader>
                      <DialogTitle>{title}</DialogTitle>
                  </DialogHeader>
                  <div className="flex-1 h-full w-full">
                      {component}
                  </div>
              </DialogContent>
           </Dialog>
        </CardHeader>
        <CardContent>
          {component}
        </CardContent>
      </Card>
    );
  };


  return (
    <div className="flex flex-col gap-8">
      <div className="flex items-center justify-between">
          <h1 className="font-headline text-3xl font-semibold bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">
            Minhas Consultas
          </h1>
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-start">
        <div className="lg:col-span-1 flex flex-col gap-8">
          <Tabs defaultValue="agenda" className="w-full">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="agenda">Agenda de Hoje</TabsTrigger>
                <TabsTrigger value="ausencias">Análise de Ausências</TabsTrigger>
              </TabsList>
              <TabsContent value="agenda">
                <Card className="h-full">
                  <CardHeader>
                    <CardTitle className="text-xl font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">
                      Agenda de Hoje - {today}
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <AppointmentsList appointments={metrics.todaysAppointments} />
                  </CardContent>
                </Card>
              </TabsContent>
              <TabsContent value="ausencias">
                 <Card>
                    <CardHeader>
                        <CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Análise de Ausências</CardTitle>
                        <CardDescription>Acompanhe faltas recentes e pacientes com alto risco de ausência.</CardDescription>
                    </CardHeader>
                    <CardContent>
                        <AbsenceInsights absenceData={metrics.absenceInsights} />
                    </CardContent>
                </Card>
              </TabsContent>
            </Tabs>
        </div>

        <div className="lg:col-span-1 grid grid-cols-1 md:grid-cols-2 gap-8">
          {renderChartCard('consultationTypes')}
          {renderChartCard('performance')}
          {renderChartCard('weeklyConsultations')}
          {renderChartCard('recentAttendances')}
        </div>
      </div>
    </div>
  );
}

