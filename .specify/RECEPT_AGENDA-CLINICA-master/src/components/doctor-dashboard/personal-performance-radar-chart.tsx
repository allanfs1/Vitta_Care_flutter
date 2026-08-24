'use client';

import { PolarAngleAxis, PolarGrid, Radar, RadarChart, ResponsiveContainer } from 'recharts';
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart';


interface PersonalPerformanceRadarChartProps {
    data: {
        labels: string[];
        data: {
          metric: string;
          value: number;
        }[];
      }
}

const chartConfig = {
  value: {
    label: 'Valor',
    color: 'hsl(var(--chart-1))',
  },
};

export function PersonalPerformanceRadarChart({ data }: PersonalPerformanceRadarChartProps) {
  if (!data || !data.data || data.data.length === 0) {
    return (
        <div className="flex items-center justify-center h-[250px] text-muted-foreground">
            <p>Sem dados de desempenho para exibir.</p>
        </div>
    )
  }

  return (
    <ChartContainer config={chartConfig} className="min-h-[200px] w-full">
      <ResponsiveContainer width="100%" height={250}>
        <RadarChart
          data={data.data}
        >
          <ChartTooltip
            cursor={false}
            content={<ChartTooltipContent indicator="line" />}
          />
          <PolarGrid />
          <PolarAngleAxis dataKey="metric" />
          <Radar
            dataKey="value"
            fill="var(--color-value)"
            fillOpacity={0.6}
            stroke="var(--color-value)"
          />
        </RadarChart>
      </ResponsiveContainer>
    </ChartContainer>
  );
}
