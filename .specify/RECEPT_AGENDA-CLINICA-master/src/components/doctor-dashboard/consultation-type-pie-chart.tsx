'use client';

import { Pie, PieChart, ResponsiveContainer, Cell, Legend } from 'recharts';
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart';

interface ConsultationTypePieChartProps {
  data: {
    name: string;
    value: number;
    fill: string;
  }[];
}

const chartConfig = {
  value: {
    label: 'Consultas',
  },
};

export function ConsultationTypePieChart({ data }: ConsultationTypePieChartProps) {
    if (!data || data.length === 0) {
        return (
            <div className="flex items-center justify-center h-[250px] text-muted-foreground">
                <p>Sem dados de tipos de consulta para exibir.</p>
            </div>
        )
    }

  return (
    <ChartContainer config={chartConfig} className="min-h-[200px] w-full">
      <ResponsiveContainer width="100%" height={250}>
        <PieChart>
          <ChartTooltip cursor={false} content={<ChartTooltipContent hideLabel />} />
          <Pie
            data={data}
            dataKey="value"
            nameKey="name"
            innerRadius={60}
            strokeWidth={5}
          >
            {data.map((entry) => (
              <Cell key={`cell-${entry.name}`} fill={entry.fill} />
            ))}
          </Pie>
          <Legend />
        </PieChart>
      </ResponsiveContainer>
    </ChartContainer>
  );
}
