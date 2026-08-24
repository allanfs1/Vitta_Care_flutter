
'use client';

import * as React from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { doc, getDoc, Timestamp } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Loader2, CheckCircle, Printer, Home, HeartPulse } from 'lucide-react';
import { Skeleton } from '@/components/ui/skeleton';

interface AppointmentDetails {
    nomePaciente: string;
    nomeMedico: string;
    especialidade: string;
    dataConsulta: Date;
    sala?: string;
    pass?: string;
}

export default function SuccessPage() {
    const router = useRouter();
    const searchParams = useSearchParams();
    const appointmentId = searchParams.get('id');
    const isTest = searchParams.get('test') === 'true';

    const [appointment, setAppointment] = React.useState<AppointmentDetails | null>(null);
    const [loading, setLoading] = React.useState(true);
    const [error, setError] = React.useState<string | null>(null);
    
    // Memoize the password so it doesn't change on re-renders
    const testSenha = React.useMemo(() => `T${Math.floor(Math.random() * 900) + 100}`, []);


    React.useEffect(() => {
        if (isTest) {
            setAppointment({
                nomePaciente: 'Paciente de Teste',
                nomeMedico: 'Dr(a). Teste',
                especialidade: 'Clínica Geral',
                dataConsulta: new Date(),
                sala: 'T-01',
                pass: testSenha,
            });
            setLoading(false);
            return;
        }

        if (!appointmentId) {
            setError('ID do agendamento não fornecido.');
            setLoading(false);
            return;
        }

        const fetchAppointment = async () => {
            try {
                const appointmentRef = doc(db, 'tb_agendamentos', appointmentId);
                const docSnap = await getDoc(appointmentRef);

                if (docSnap.exists()) {
                    const data = docSnap.data();
                    
                    setAppointment({
                        nomePaciente: data.nomePaciente,
                        nomeMedico: data.nomeMedico,
                        especialidade: data.especialidade,
                        dataConsulta: (data.dataConsulta as Timestamp).toDate(),
                        sala: data.nomeSala || 'A definir',
                        pass: data.pass || 'N/A', // Read the password from Firestore
                    });
                } else {
                    setError('Agendamento não encontrado.');
                }
            } catch (err) {
                console.error("Error fetching appointment details:", err);
                setError('Erro ao buscar os detalhes do agendamento.');
            } finally {
                setLoading(false);
            }
        };

        fetchAppointment();
    }, [appointmentId, isTest, testSenha]);
    
    const handlePrint = () => {
        window.print();
    }

    const renderReceipt = () => {
        if (loading) {
            return (
                <div className="space-y-4 text-center">
                    <Skeleton className="h-8 w-3/4 mx-auto" />
                    <div className="space-y-2 pt-4">
                        <Skeleton className="h-4 w-full" />
                        <Skeleton className="h-4 w-5/6 mx-auto" />
                        <Skeleton className="h-4 w-full" />
                        <Skeleton className="h-4 w-4/5 mx-auto" />
                    </div>
                </div>
            )
        }

        if (error || !appointment) {
            return <p className="text-center text-destructive">{error || 'Não foi possível carregar os dados.'}</p>;
        }
        
        return (
             <div id="print-receipt" className="text-center">
                <div className="flex flex-col items-center mb-4">
                    <HeartPulse className="h-8 w-8" />
                    <p className="font-bold">Agenda Clínica</p>
                </div>
                <p className="text-xs">{format(new Date(), "dd/MM/yyyy HH:mm:ss", { locale: ptBR })}</p>
                <hr className="border-dashed border-t-2 my-2" />
                
                <p className="font-bold text-lg">SENHA</p>
                <p className="font-bold text-5xl tracking-wider my-2">{appointment.pass}</p>
                
                <hr className="border-dashed border-t-2 my-2" />
                
                <div className="space-y-1 text-left text-sm">
                    <p><strong>Paciente:</strong> {appointment.nomePaciente}</p>
                    <p><strong>Médico:</strong> {appointment.nomeMedico}</p>
                    <p><strong>Especialidade:</strong> {appointment.especialidade}</p>
                    <p><strong>Data:</strong> {format(appointment.dataConsulta, "dd/MM/yyyy 'às' HH:mm", { locale: ptBR })}</p>
                    <p><strong>Sala:</strong> {appointment.sala}</p>
                </div>
                 <hr className="border-dashed border-t-2 my-2" />
                <p className="text-xs mt-4">
                    Por favor, chegue com 15 minutos de antecedência.
                </p>
            </div>
        )
    }


    return (
        <div className="flex min-h-screen w-full items-center justify-center bg-muted/40 p-4">
            <Card className="w-full max-w-md shadow-2xl">
                <CardHeader className="text-center">
                    <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-green-100">
                        <CheckCircle className="h-10 w-10 text-green-600" />
                    </div>
                    <CardTitle className="mt-4 text-3xl font-bold tracking-tight text-primary">
                        Agendamento Confirmado!
                    </CardTitle>
                    <CardDescription>
                        Sua consulta foi agendada com sucesso.
                    </CardDescription>
                </CardHeader>
                <CardContent className="space-y-8">
                    <div className="rounded-lg border bg-background p-6">
                        {renderReceipt()}
                    </div>
                    <div className="flex flex-col gap-4">
                         <Button onClick={handlePrint} size="lg" className="w-full h-14 text-lg" disabled={loading || !!error}>
                            <Printer className="mr-2 h-5 w-5" />
                            Imprimir Comprovante
                        </Button>
                        <Button variant="ghost" onClick={() => router.push('/totem')} className="w-full">
                            <Home className="mr-2 h-4 w-4" />
                            Voltar ao Início
                        </Button>
                    </div>
                </CardContent>
            </Card>
        </div>
    );
}

    