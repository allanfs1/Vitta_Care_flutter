'use client';

import * as React from 'react';
import { collection, query, getDocs, Timestamp, getDoc, orderBy, limit, DocumentReference } from 'firebase/firestore';
import { format } from "date-fns";
import { ptBR } from 'date-fns/locale';

import { db } from "@/lib/firebase";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from '@/components/ui/badge';
import { UserX, AlertCircle, CheckCircle, HelpCircle, XCircle } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { Progress } from '@/components/ui/progress';
import type { UserProfile } from '@/lib/types';


interface AbsenceData {
    id: string;
    nomePaciente: string;
    photoUrl?: string;
    dataConsulta: Date;
    motivo: string;
    probabilidadeFalta?: number;
    riscoFalta: string;
}

const getInitials = (name: string | null | undefined) => {
    if (!name) return 'P';
    return name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
}

// Define risk styles in one place for consistency
const riskStyles: { [key: string]: { border: string; badge: string; icon: React.ElementType } } = {
    'risco elevado': {
        border: 'border-amber-500',
        badge: 'bg-amber-100 text-amber-800 dark:bg-amber-900/20 dark:text-amber-300 border-amber-500/30',
        icon: AlertCircle,
    },
    'falta confirmada': {
        border: 'border-red-500',
        badge: 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300 border-red-500/30',
        icon: XCircle,
    },
    'risco moderado': {
        border: 'border-sky-500',
        badge: 'bg-sky-100 text-sky-800 dark:bg-sky-900/20 dark:text-sky-300 border-sky-500/30',
        icon: HelpCircle,
    },
    'risco baixo': {
        border: 'border-green-500',
        badge: 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300 border-green-500/30',
        icon: CheckCircle,
    },
    'default': {
        border: 'border-border',
        badge: 'bg-muted text-muted-foreground',
        icon: HelpCircle,
    }
};

const getRiskStyle = (risk: string) => {
    const riskKey = risk?.toLowerCase() || 'default';
    return riskStyles[riskKey] || riskStyles.default;
};


const AbsenceItem = ({ absence }: { absence: AbsenceData }) => {
    const style = getRiskStyle(absence.riscoFalta);
    const Icon = style.icon;
    const probabilityPercent = absence.probabilidadeFalta != null ? Math.round(absence.probabilidadeFalta * 100) : null;

    return (
        <div className={cn("flex items-start gap-4 p-4 rounded-lg border-l-4 transition-colors hover:bg-muted/50", style.border)}>
            <Avatar className="h-10 w-10 border">
                <AvatarImage src={absence.photoUrl || undefined} alt={absence.nomePaciente} />
                <AvatarFallback>{getInitials(absence.nomePaciente)}</AvatarFallback>
            </Avatar>
            <div className="flex-1 grid gap-2">
                <div className="flex justify-between items-start gap-2">
                    <div>
                        <p className="font-semibold">{absence.nomePaciente}</p>
                        <p className="text-sm text-muted-foreground">
                            {format(absence.dataConsulta, "EEEE, dd 'de' MMMM 'às' HH:mm", { locale: ptBR })}
                        </p>
                    </div>
                     <Badge className={cn("flex items-center gap-1.5 whitespace-nowrap", style.badge)}>
                        <Icon className="h-3.5 w-3.5" />
                        <span>{absence.riscoFalta}</span>
                    </Badge>
                </div>
                
                {probabilityPercent !== null && (
                    <div className="space-y-1">
                        <div className="flex justify-between items-baseline text-sm">
                            <span className="text-muted-foreground">Probabilidade de Falta</span>
                            <span className="font-semibold">{probabilityPercent}%</span>
                        </div>
                        <Progress value={probabilityPercent} className="h-2" />
                    </div>
                )}

                <p className="text-sm text-muted-foreground">
                    <span className="font-medium text-foreground/80">Motivo:</span> {absence.motivo}
                </p>
            </div>
        </div>
    );
}

export function AbsenceInsights() {
  const [absences, setAbsences] = React.useState<AbsenceData[]>([]);
  const [loading, setLoading] = React.useState(true);
  const { toast } = useToast();

  React.useEffect(() => {
    const fetchAbsenceData = async () => {
      setLoading(true);
      try {
        const absenceRef = collection(db, 'tb_faltas_data');
        const q = query(absenceRef, orderBy('data_falta_consulta', 'desc'), limit(10));

        const snapshot = await getDocs(q);
        
        const promises = snapshot.docs.map(async (d) => {
            const data = d.data();
            let nomePaciente = 'Paciente não informado';
            let photoUrl: string | undefined;

            if (data.idpaciente instanceof DocumentReference) {
              try {
                const userDocSnap = await getDoc(data.idpaciente);
                if (userDocSnap.exists()) {
                  const userData = userDocSnap.data() as UserProfile;
                  nomePaciente = userData.display_name || 'Nome não encontrado';
                  photoUrl = userData.photo_url;
                }
              } catch (e) {
                console.error("Error fetching patient name for doc " + d.id, e);
              }
            }

            return {
              id: d.id,
              nomePaciente: nomePaciente,
              photoUrl: photoUrl,
              dataConsulta: (data.data_falta_consulta as Timestamp).toDate(),
              motivo: data.motivo || 'Motivo não informado',
              probabilidadeFalta: data.probabilidade_falta,
              riscoFalta: data.risco_falta || 'Desconhecido',
            };
          });

        const absenceData = await Promise.all(promises);
        setAbsences(absenceData);

      } catch (error: any) {
        console.error("Error fetching absence data: ", error);
        toast({
          variant: 'destructive',
          title: 'Erro ao buscar dados de faltas',
          description: 'Não foi possível carregar os dados. Verifique o console para mais detalhes.',
        });
      } finally {
        setLoading(false);
      }
    };

    fetchAbsenceData();
  }, [toast]);

  if (loading) {
    return (
      <div className="space-y-4">
        {[...Array(3)].map((_, i) => (
        <div key={i} className="flex items-start gap-4 p-4 border rounded-lg">
            <Skeleton className="h-10 w-10 rounded-full" />
            <div className="flex-1 space-y-2">
                <Skeleton className="h-4 w-3/5" />
                <Skeleton className="h-3 w-2/5" />
            </div>
        </div>
        ))}
      </div>
    );
  }

  return (
    <div className="w-full">
      {absences.length > 0 ? (
        <div className="space-y-3">
          {absences.map((absence) => <AbsenceItem key={absence.id} absence={absence} />)}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center h-32 text-center rounded-lg border border-dashed">
           <UserX className="h-8 w-8 text-muted-foreground mb-2"/>
          <p className="text-sm text-muted-foreground">Nenhum registro de falta ou risco de falta encontrado.</p>
        </div>
      )}
    </div>
  );
}
