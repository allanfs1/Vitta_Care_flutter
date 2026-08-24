
import { db } from "@/lib/firebase";
import { collection, getDocs, query, where, Timestamp } from "firebase/firestore";
import {
  startOfToday,
  endOfToday,
  startOfWeek,
  endOfWeek,
  startOfMonth,
  endOfMonth,
  subMonths,
  eachMonthOfInterval,
  format,
} from "date-fns";
import { ptBR } from 'date-fns/locale';

interface AppointmentData {
    id: string;
    dataConsulta: Date;
    status: string;
    nomeMedico?: string;
}

const AVERAGE_CONSULTATION_FEE = 250; // Valor médio por consulta em R$
const AVERAGE_MONTHLY_COST = 3000; // Custo mensal simulado para cálculo do ROI

export async function getDashboardMetrics() {
    const appointmentsRef = collection(db, "tb_agendamentos");
    const now = new Date();
    
    const q = query(appointmentsRef, where("dataConsulta", "!=", null));
    const querySnapshot = await getDocs(q);

    const appointments: AppointmentData[] = querySnapshot.docs.map(doc => {
        const data = doc.data();
        return {
            id: doc.id,
            dataConsulta: (data.dataConsulta as Timestamp).toDate(),
            status: data.status?.toLowerCase() || 'desconhecido',
            nomeMedico: data.nomeMedico,
        };
    });
    
    // --- Time-based Filters ---
    const todayStart = startOfToday();
    const todayEnd = endOfToday();
    const weekStart = startOfWeek(now);
    const weekEnd = endOfWeek(now);
    const monthStart = startOfMonth(now);
    const monthEnd = endOfMonth(now);
    const lastMonthStart = startOfMonth(subMonths(now, 1));
    const lastMonthEnd = endOfMonth(subMonths(now, 1));

    const todayAppointments = appointments.filter(a => a.dataConsulta >= todayStart && a.dataConsulta <= todayEnd);
    const thisWeekAppointments = appointments.filter(a => a.dataConsulta >= weekStart && a.dataConsulta <= weekEnd);
    const thisMonthAppointments = appointments.filter(a => a.dataConsulta >= monthStart && a.dataConsulta <= monthEnd);
    const lastMonthAppointments = appointments.filter(a => a.dataConsulta >= lastMonthStart && a.dataConsulta <= lastMonthEnd);

    // --- Calculations ---
    
    // StatsCards
    const statsCards = {
        appointmentsToday: todayAppointments.length,
        appointmentsThisWeek: thisWeekAppointments.length,
        appointmentsThisMonth: thisMonthAppointments.length,
        roomOccupancy: "68%", // Static value
    };
    
    // DetailedStatsCards
    const confirmedAndCompletedThisMonth = thisMonthAppointments.filter(a => ['confirmado', 'finalizado', 'agendado'].includes(a.status));
    const absenteeismThisMonth = thisMonthAppointments.filter(a => a.status === 'nao_agendado').length;
    
    const totalConsideredThisMonth = thisMonthAppointments.filter(a => ['confirmado', 'finalizado', 'agendado', 'nao_agendado'].includes(a.status)).length;
    
    const confirmationRate = totalConsideredThisMonth > 0 ? (confirmedAndCompletedThisMonth.length / totalConsideredThisMonth) * 100 : 0;
    const absenteeismRate = totalConsideredThisMonth > 0 ? (absenteeismThisMonth / totalConsideredThisMonth) * 100 : 0;
    
    const monthlyGrowth = lastMonthAppointments.length > 0
        ? ((thisMonthAppointments.length - lastMonthAppointments.length) / lastMonthAppointments.length) * 100
        : (thisMonthAppointments.length > 0 ? 100 : 0);

    // Revenue Calculation
    const thisMonthRevenue = confirmedAndCompletedThisMonth.length * AVERAGE_CONSULTATION_FEE;
    const lastMonthCompleted = lastMonthAppointments.filter(a => ['confirmado', 'finalizado', 'agendado'].includes(a.status));
    const lastMonthRevenue = lastMonthCompleted.length * AVERAGE_CONSULTATION_FEE;
    const revenueChange = lastMonthRevenue > 0
        ? ((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100
        : (thisMonthRevenue > 0 ? 100 : 0);

    // ROI Calculation
    const thisMonthROI = AVERAGE_MONTHLY_COST > 0 ? ((thisMonthRevenue - AVERAGE_MONTHLY_COST) / AVERAGE_MONTHLY_COST) * 100 : 0;
    const lastMonthROI = AVERAGE_MONTHLY_COST > 0 ? ((lastMonthRevenue - AVERAGE_MONTHLY_COST) / AVERAGE_MONTHLY_COST) * 100 : 0;
    const roiChange = thisMonthROI - lastMonthROI;


    const detailedStatsCards = {
        confirmationRate,
        absenteeismRate,
        monthlyGrowth,
        monthlyROI: {
            value: thisMonthROI,
            change: roiChange,
        },
        monthlyRevenue: {
            value: thisMonthRevenue,
            change: revenueChange,
        }
    };

    // AppointmentStatusPieChart
    const statusCounts = thisMonthAppointments.reduce((acc, curr) => {
        const status = curr.status.charAt(0).toUpperCase() + curr.status.slice(1);
        acc[status] = (acc[status] || 0) + 1;
        return acc;
    }, {} as Record<string, number>);

    const appointmentStatusPieChartData = [
        { status: "Confirmados", count: (statusCounts.Confirmado || 0) + (statusCounts.Agendado || 0) + (statusCounts.Finalizado || 0), fill: "hsl(var(--chart-1))" },
        { status: "Pendentes", count: statusCounts.Pendente || 0, fill: "hsl(var(--chart-2))" },
        { status: "Cancelados", count: statusCounts.Cancelado || 0, fill: "hsl(var(--chart-3))" },
        { status: "Faltas", count: statusCounts.Nao_agendado || 0, fill: "hsl(var(--chart-4))" },
    ].filter(item => item.count > 0);

    // AppointmentsChart (Line Chart)
    const monthsInterval = eachMonthOfInterval({ start: subMonths(now, 11), end: now });
    const appointmentsChartData = monthsInterval.map(monthStart => {
        const monthEnd = endOfMonth(monthStart);
        const monthName = format(monthStart, 'MMM', { locale: ptBR });
        const count = appointments.filter(a => a.dataConsulta >= monthStart && a.dataConsulta <= monthEnd).length;
        return { month: monthName, appointments: count };
    });

    // DoctorPerformanceRadarChart (based on new logic)
    const byDoctor = appointments.reduce((acc, r) => {
        const docName = r.nomeMedico || 'Sem nome';
        if (!acc[docName]) {
            acc[docName] = { total: 0, confirmados: 0 };
        }
        acc[docName].total++;
        if (['confirmado', 'finalizado', 'agendado'].includes(r.status)) {
            acc[docName].confirmados++;
        }
        return acc;
    }, {} as Record<string, { total: number; confirmados: number }>);
    
    const topDoctors = Object.entries(byDoctor)
        .sort(([, a], [, b]) => b.total - a.total)
        .slice(0, 2);

    const doctorPerformanceRadarChartData = {
        labels: ["Consultas", "Avaliação", "Retorno (%)", "Pontualidade (%)", "Novos Pacientes"],
        doctors: topDoctors.map(([name, data]) => ({
            name: name.split(' ').slice(0, 2).join(' '),
            consultas: data.total,
            avaliacao: (Math.random() * (4.9 - 4.5) + 4.5).toFixed(1), // Static simulation
            retorno: Math.floor(Math.random() * (85 - 70) + 70), // Static simulation
            pontualidade: Math.floor(Math.random() * (95 - 85) + 85), // Static simulation
            novosPacientes: Math.floor(Math.random() * (25-15) + 15), // Static simulation
        }))
    };

    if (doctorPerformanceRadarChartData.doctors.length === 0) {
        doctorPerformanceRadarChartData.doctors = [];
    }

    return {
        statsCards,
        detailedStatsCards,
        appointmentStatusPieChartData,
        appointmentsChartData,
        doctorPerformanceRadarChartData,
    };
}
