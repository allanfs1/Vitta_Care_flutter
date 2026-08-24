'use client';

import { Line, LineChart, ResponsiveContainer, XAxis, YAxis, CartesianGrid, Legend, Tooltip } from 'recharts';
import {
  ChartContainer,
} from '@/components/ui/chart';

interface WeeklyConsultationsChartProps {
    data: {
        name: string;
        PrimeiraConsulta: number;
        Retorno: number;
        Encaixe: number;
    }[];
}

const chartConfig = {
    PrimeiraConsulta: {
        label: "Primeira Consulta",
        color: "hsl(var(--chart-1))",
    },
    Retorno: {
        label: "Retorno",
        color: "hsl(var(--chart-2))",
    },
    Encaixe: {
        label: "Encaixe",
        color: "hsl(var(--chart-3))",
    },
};

export function WeeklyConsultationsChart({ data }: WeeklyConsultationsChartProps) {
  return (
    <ChartContainer config={chartConfig} className="min-h-[200px] w-full">
      <ResponsiveContainer width="100%" height={250}>
        <LineChart data={data} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} />
          <XAxis 
            dataKey="name"
            stroke="#888888"
            fontSize={12}
            tickLine={false}
            axisLine={false}
          />
          <YAxis
            stroke="#888888"
            fontSize={12}
            tickLine={false}
            axisLine={false}
          />
          <Tooltip 
             contentStyle={{
              backgroundColor: 'hsl(var(--background))',
              borderColor: 'hsl(var(--border))',
            }}
          />
          <Legend />
          <Line type="monotone" dataKey="PrimeiraConsulta" name="Primeira Consulta" stroke="hsl(var(--chart-1))" strokeWidth={2} />
          <Line type="monotone" dataKey="Retorno" name="Retorno" stroke="hsl(var(--chart-2))" strokeWidth={2} />
          <Line type="monotone" dataKey="Encaixe" name="Encaixe" stroke="hsl(var(--chart-3))" strokeWidth={2} />
        </LineChart>
      </ResponsiveContainer>
    </ChartContainer>
  );
}
