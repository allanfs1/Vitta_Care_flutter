"use client"

import { Pie, PieChart, ResponsiveContainer, Cell } from "recharts"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  ChartLegend,
  ChartLegendContent
} from "@/components/ui/chart"

interface AppointmentStatusPieChartProps {
  data: {
    status: string;
    count: number;
    fill: string;
  }[];
}

const chartConfig = {
  count: {
    label: "Agendamentos",
  },
  Confirmados: {
    label: "Confirmados",
    color: "hsl(var(--chart-1))",
  },
  Pendentes: {
    label: "Pendentes",
    color: "hsl(var(--chart-2))",
  },
  Cancelados: {
    label: "Cancelados",
    color: "hsl(var(--chart-3))",
  },
  Faltas: {
    label: "Faltas",
    color: "hsl(var(--chart-4))",
  },
}

export function AppointmentStatusPieChart({ data }: AppointmentStatusPieChartProps) {
  return (
    <ChartContainer config={chartConfig} className="min-h-[200px] w-full">
      <ResponsiveContainer width="100%" height={250}>
        <PieChart>
          <ChartTooltip
            cursor={false}
            content={<ChartTooltipContent hideLabel nameKey="status" />}
          />
          <Pie
            data={data}
            dataKey="count"
            nameKey="status"
            innerRadius={50}
            strokeWidth={5}
          >
             {data.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={entry.fill} />
            ))}
          </Pie>
          <ChartLegend
            content={<ChartLegendContent nameKey="status" />}
            className="-mt-4"
          />
        </PieChart>
      </ResponsiveContainer>
    </ChartContainer>
  )
}
