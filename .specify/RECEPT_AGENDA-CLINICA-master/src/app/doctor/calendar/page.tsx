
'use client';

import * as React from 'react';
import { useAuth } from '@/contexts/auth-context';
import { getDoctorDashboardMetrics } from '@/lib/doctor-metrics';
import { DoctorMetrics } from '@/lib/types';
import { DoctorCalendar } from "@/components/doctor-dashboard/doctor-calendar";
import { Home } from "lucide-react";
import { Button } from "@/components/ui/button";
import Link from "next/link";
import { LoadingScreen } from '@/components/loading-screen';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { ConsultationTypePieChart } from '@/components/doctor-dashboard/consultation-type-pie-chart';
import { PersonalPerformanceRadarChart } from '@/components/doctor-dashboard/personal-performance-radar-chart';
import { WeeklyConsultationsChart } from '@/components/doctor-dashboard/weekly-consultations-chart';
import { ConsultationsBarChart } from '@/components/doctor-dashboard/consultations-bar-chart';
import { PageHeader } from '@/components/page-header';


export default function DoctorCalendarPage() { 
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
  
  return (
    <div className="flex  flex-col gap-8">
      <div className="flex items-center justify-between">
        <PageHeader 
            title="Meu Calendário"
            description="Visualize suas consultas, alertas e métricas de desempenho."
            showFavoriteButton={false}
        />
         <Button asChild variant="outline">
            <Link href="/doctor/dashboard">
              <Home className="mr-2 h-4 w-4" />
              Voltar ao Início
            </Link>
          </Button>
      </div>
      
      <DoctorCalendar />

       {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mt-8">
            <Card><CardHeader><CardTitle>Carregando métricas...</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardTitle>Carregando métricas...</CardTitle></CardHeader></Card>
        </div>
      ) : metrics ? (
         <div className="mt-8">
            <h2 className="font-headline text-2xl font-semibold mb-4 bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Minhas Métricas de Desempenho</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                <Card>
                    <CardHeader><CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Tipos de Consulta (Mês)</CardTitle></CardHeader>
                    <CardContent>
                        <ConsultationTypePieChart data={metrics.consultationTypes} />
                    </CardContent>
                </Card>
                 <Card>
                    <CardHeader><CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Desempenho Pessoal</CardTitle></CardHeader>
                    <CardContent>
                        <PersonalPerformanceRadarChart data={metrics.performance} />
                    </CardContent>
                </Card>
                 <Card>
                    <CardHeader><CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Consultas na Semana</CardTitle></CardHeader>
                    <CardContent>
                        <WeeklyConsultationsChart data={metrics.weeklyConsultations} />
                    </CardContent>
                </Card>
                 <Card>
                    <CardHeader><CardTitle className="font-headline bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">Atendimentos Recentes</CardTitle></CardHeader>
                    <CardContent>
                        <ConsultationsBarChart data={metrics.consultationsStats} />
                    </CardContent>
                </Card>
            </div>
         </div>
      ) : (
        <p className='text-center text-muted-foreground mt-8'>Não foi possível carregar as métricas.</p>
      )}
    </div>
  );
}
