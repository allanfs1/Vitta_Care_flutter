import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  CheckCircle,
  XCircle,
  TrendingUp,
  ArrowUpRight,
  Percent,
  DollarSign,
} from "lucide-react";
import { cn } from "@/lib/utils";

interface DetailedStatsCardsProps {
  data: {
    confirmationRate: number;
    absenteeismRate: number;
    monthlyGrowth: number;
    monthlyROI: {
        value: number;
        change: number;
    },
    monthlyRevenue: {
        value: number;
        change: number;
    }
  }
}

export function DetailedStatsCards({ data }: DetailedStatsCardsProps) {
  const growthDescription = data.monthlyGrowth >= 0 
    ? `+${data.monthlyGrowth.toFixed(1)}% vs. mês anterior`
    : `${data.monthlyGrowth.toFixed(1)}% vs. mês anterior`;
    
  const roiDescription = data.monthlyROI.change >= 0
    ? `+${data.monthlyROI.change.toFixed(2)} pts vs. mês anterior`
    : `${data.monthlyROI.change.toFixed(2)} pts vs. mês anterior`;

  const revenueDescription = data.monthlyRevenue.change >= 0
    ? `+${data.monthlyRevenue.change.toFixed(1)}% vs. mês anterior`
    : `${data.monthlyRevenue.change.toFixed(1)}% vs. mês anterior`;

  const formatCurrency = (value: number) => {
      return new Intl.NumberFormat('pt-BR', {
          style: 'currency',
          currency: 'BRL',
      }).format(value);
  }

  const detailedStats = [
    {
      title: "Taxa de Confirmação",
      value: `${data.confirmationRate.toFixed(0)}%`,
      description: "Agendamentos confirmados no mês",
      icon: CheckCircle,
    },
    {
      title: "Taxa de Absenteísmo",
      value: `${data.absenteeismRate.toFixed(0)}%`,
      description: "Faltas registradas no mês",
      icon: XCircle,
    },
    {
      title: "Crescimento (Agend.)",
      value: `${data.monthlyGrowth.toFixed(1)}%`,
      description: growthDescription,
      icon: ArrowUpRight,
    },
    {
      title: "ROI (Mês)",
      value: `${data.monthlyROI.value.toFixed(2)}%`,
      description: roiDescription,
      icon: Percent,
    },
    {
      title: "Receita (Mês)",
      value: formatCurrency(data.monthlyRevenue.value),
      description: revenueDescription,
      icon: DollarSign,
    },
  ];

  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
      {detailedStats.map((stat, index) => (
        <Card key={stat.title} className={cn(
            index === 4 && "lg:col-span-1 xl:col-span-1",
            index === 3 && "lg:col-span-1",
            index === 2 && "lg:col-span-1"
        )}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">
              {stat.title}
            </CardTitle>
            <stat.icon className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold bg-gradient-to-r from-primary to-accent text-transparent bg-clip-text">{stat.value}</div>
            <p className="text-xs text-muted-foreground">{stat.description}</p>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
