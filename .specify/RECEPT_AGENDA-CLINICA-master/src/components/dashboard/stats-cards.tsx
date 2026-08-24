import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Calendar,
  CalendarCheck,
  CalendarClock,
  Users,
} from "lucide-react";

interface StatsCardsProps {
  data: {
    appointmentsToday: number;
    appointmentsThisWeek: number;
    appointmentsThisMonth: number;
    roomOccupancy: string; // This remains static as we can't calculate it yet
  }
}

export function StatsCards({ data }: StatsCardsProps) {
  const stats = [
    {
      title: "Consultas Hoje",
      value: data.appointmentsToday.toString(),
      description: "Agendamentos para a data de hoje",
      icon: Calendar,
    },
    {
      title: "Esta Semana",
      value: data.appointmentsThisWeek.toString(),
      description: "Total de agendamentos na semana",
      icon: CalendarCheck,
    },
    {
      title: "Este Mês",
      value: data.appointmentsThisMonth.toString(),
      description: "Total de agendamentos no mês",
      icon: CalendarClock,
    },
    {
      title: "Ocupação da Sala",
      value: data.roomOccupancy, // Static value
      description: "Ocupação média das salas",
      icon: Users,
    },
  ];

  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {stats.map((stat) => (
        <Card key={stat.title}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">
              {stat.title}
            </CardTitle>
            <stat.icon className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">
              {stat.value}
            </div>
            <p className="text-xs text-muted-foreground">{stat.description}</p>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
