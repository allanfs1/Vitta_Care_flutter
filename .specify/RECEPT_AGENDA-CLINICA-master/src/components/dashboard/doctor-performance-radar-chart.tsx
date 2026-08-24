
"use client"

import { PolarAngleAxis, PolarGrid, Radar, RadarChart, ResponsiveContainer, Legend } from "recharts"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  ChartLegend,
  ChartLegendContent,
} from "@/components/ui/chart"
import { useMemo } from "react";

interface DoctorPerformanceRadarChartProps {
  data: {
    labels: string[];
    doctors: {
      name: string;
      consultas: number;
      avaliacao: string;
      retorno: number;
      pontualidade: number;
      novosPacientes: number;
    }[];
  }
}

export function DoctorPerformanceRadarChart({ data }: DoctorPerformanceRadarChartProps) {
  
  if (!data || !data.doctors || data.doctors.length === 0) {
    return (
      <div className="flex h-[350px] w-full items-center justify-center text-muted-foreground">
        <p>Dados de desempenho de médicos indisponíveis.</p>
      </div>
    );
  }

  const { labels, doctors } = data;

  const chartData = useMemo(() => {
    return labels.map((metric, i) => {
      const entry: { metric: string; [key: string]: any } = { metric };
      doctors.forEach((doc, docIndex) => {
        const key = `doc${docIndex + 1}`;
        if (metric === "Consultas") entry[key] = doc.consultas;
        if (metric === "Avaliação") entry[key] = parseFloat(doc.avaliacao);
        if (metric === "Retorno (%)") entry[key] = doc.retorno;
        if (metric === "Pontualidade (%)") entry[key] = doc.pontualidade;
        if (metric === "Novos Pacientes") entry[key] = doc.novosPacientes;
      });
      return entry;
    });
  }, [labels, doctors]);
  
  const fullMarks: { [key: string]: number } = {
      "Consultas": 150,
      "Avaliação": 5,
      "Retorno (%)": 100,
      "Pontualidade (%)": 100,
      "Novos Pacientes": 30,
  }

  const chartConfig = doctors.reduce((acc, doc, index) => {
    const key = `doc${index + 1}`;
    acc[key] = {
      label: doc.name,
      color: `hsl(var(--chart-${index + 1}))`,
    };
    return acc;
  }, {} as any);

  return (
    <ChartContainer config={chartConfig} className="min-h-[300px] w-full">
      <ResponsiveContainer width="100%" height={350}>
        <RadarChart data={chartData}>
            <ChartTooltip cursor={false} content={<ChartTooltipContent indicator="line" />} />
            <PolarGrid />
            <PolarAngleAxis dataKey="metric" />
            
            {doctors.map((doc, index) => (
                 <Radar 
                    key={doc.name}
                    name={doc.name}
                    dataKey={`doc${index + 1}`} 
                    fill={`var(--color-doc${index+1})`}
                    fillOpacity={0.6} 
                    stroke={`var(--color-doc${index+1})`}
                />
            ))}

             <ChartLegend content={<ChartLegendContent />} />
        </RadarChart>
      </ResponsiveContainer>
    </ChartContainer>
  )
}
