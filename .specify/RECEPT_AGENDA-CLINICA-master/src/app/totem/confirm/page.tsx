
'use client';

import * as React from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { useForm, FormProvider } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { collection, query, where, getDocs, addDoc, doc, serverTimestamp, limit } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { format, parseISO } from 'date-fns';
import { ptBR } from 'date-fns/locale';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { useToast } from '@/hooks/use-toast';
import { Loader2, User, Calendar, Clock, Stethoscope, ArrowLeft } from 'lucide-react';
import type { UserProfile } from '@/lib/types';
import { Skeleton } from '@/components/ui/skeleton';

const cpfSchema = z.object({
  cpf: z.string().min(14, { message: 'CPF deve ter 11 dígitos.' }), // Length is 14 with mask
});

const newUserSchema = z.object({
  name: z.string().min(3, 'Nome é obrigatório.'),
  email: z.string().email('Email inválido.'),
  phone: z.string().min(10, 'Telefone é obrigatório.'),
  birthDate: z.string().optional(),
  gender: z.enum(['Masculino', 'Feminino', 'Outro']).optional(),
});

type CpfFormValues = z.infer<typeof cpfSchema>;
type NewUserFormValues = z.infer<typeof newUserSchema>;

const formatCPF = (value: string) => {
  return value
    .replace(/\D/g, '') // Remove all non-digits
    .replace(/(\d{3})(\d)/, '$1.$2')
    .replace(/(\d{3})(\d)/, '$1.$2')
    .replace(/(\d{3})(\d{1,2})/, '$1-$2')
    .substring(0, 14); // Limit to 14 chars (XXX.XXX.XXX-XX)
};

const formatPhone = (value: string) => {
  return value
    .replace(/\D/g, '')
    .replace(/(\d{2})(\d)/, '($1) $2')
    .replace(/(\d{5})(\d)/, '$1-$2')
    .substring(0, 15); // Limit to (XX) XXXXX-XXXX
};


export default function ConfirmAppointmentPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { toast } = useToast();

  const [step, setStep] = React.useState<'cpf' | 'form' | 'confirm'>('cpf');
  const [loading, setLoading] = React.useState(false);
  const [existingUser, setExistingUser] = React.useState<UserProfile & { id: string } | null>(null);
  const [cpf, setCpf] = React.useState('');

  // Get data from URL
  const doctorId = searchParams.get('doctorId');
  const doctorName = searchParams.get('doctorName');
  const specialty = searchParams.get('specialty');
  const date = searchParams.get('date');
  const time = searchParams.get('time');
  const clinicId = searchParams.get('clinicId');

  const cpfForm = useForm<CpfFormValues>({
    resolver: zodResolver(cpfSchema),
    defaultValues: { cpf: '' },
  });

  const newUserForm = useForm<NewUserFormValues>({
    resolver: zodResolver(newUserSchema),
    defaultValues: {
      name: '',
      email: '',
      phone: '',
      birthDate: '',
    },
  });

  const sendConfirmationEmail = async (appointmentDetails: {
    toEmail: string;
    patientName: string;
    doctorName: string;
    specialty?: string | null;
    dateTime: Date;
    password?: string;
  }) => {
      const { toEmail, patientName, doctorName, specialty, dateTime, password } = appointmentDetails;
      const functionUrl = "https://us-central1-agendaclinica-457713.cloudfunctions.net/sendGenericEmailADM";

      const formattedDate = format(dateTime, "EEEE, dd 'de' MMMM 'de' yyyy 'às' HH:mm'h'", { locale: ptBR });

      const subject = "Sua consulta foi agendada com sucesso!";

      const messageHtml = `
          <div style="font-family: Arial, sans-serif; line-height: 1.6;">
              <h2 style="color: #333;">Olá, ${patientName}!</h2>
              <p>Sua consulta foi agendada com sucesso através do nosso totem de atendimento.</p>
              <p><strong>Detalhes da Consulta:</strong></p>
              <ul>
                  <li><strong>Médico(a):</strong> ${doctorName}</li>
                  ${specialty ? `<li><strong>Especialidade:</strong> ${specialty}</li>` : ''}
                  <li><strong>Data e Hora:</strong> ${formattedDate}</li>
                  ${password ? `<li><strong>Sua Senha de Atendimento:</strong> <span style="font-weight: bold; font-size: 1.2em;">${password}</span></li>` : ''}
              </ul>
              <p>Por favor, chegue com 15 minutos de antecedência. Se precisar remarcar ou cancelar, entre em contato conosco.</p>
              <p>Atenciosamente,<br>Agenda Clínica</p>
          </div>
      `;

      const messageText = `
          Olá, ${patientName}!\n\n
          Sua consulta foi agendada com sucesso através do nosso totem de atendimento.\n\n
          Detalhes da Consulta:\n
          - Médico(a): ${doctorName}\n
          ${specialty ? `- Especialidade: ${specialty}\n` : ''}
          - Data e Hora: ${formattedDate}\n
          ${password ? `- Sua Senha de Atendimento: ${password}\n` : ''}\n
          Por favor, chegue com 15 minutos de antecedência. Se precisar remarcar ou cancelar, entre em contato conosco.\n\n
          Atenciosamente,\n
          Agenda Clínica
      `;

      try {
          await fetch(functionUrl, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                  data: { // Wrap payload in a 'data' object
                      toEmail,
                      fromEmail: "confirmar@agendaclinicas.com.br",
                      replyTo: "confirmar@agendaclinicas.com.br",
                      subject,
                      messageHtml,
                      messageText,
                  }
              })
          });
          console.log("E-mail de confirmação enviado para:", toEmail);
      } catch (error) {
          console.error("Erro ao enviar e-mail de confirmação:", error);
          // Don't block user flow, just log the error
      }
  };

  const sendSecondConfirmationEmail = async (appointmentId: string, emailPaciente: string) => {
    const functionUrl = "https://api-wriqcan55q-uc.a.run.app/sendConfirmationEmail";
    try {
        await fetch(functionUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
               "appointmentId" : appointmentId,
               "emailPaciente" : emailPaciente
            })
        });
        console.log("Segundo e-mail de confirmação disparado para:", emailPaciente);
    } catch (error) {
        console.error("Erro ao disparar o segundo e-mail de confirmação:", error);
    }
  };

  if (!doctorId || !date || !time || !clinicId) {
    return (
      <div className="flex min-h-screen w-full items-center justify-center p-4">
        <Card>
          <CardHeader>
            <CardTitle>Erro</CardTitle>
          </CardHeader>
          <CardContent>
            <p>Dados do agendamento incompletos. Por favor, volte e tente novamente.</p>
            <Button onClick={() => router.push('/totem')} className="mt-4">Voltar ao Início</Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  const handleCpfCheck = async ({ cpf }: CpfFormValues) => {
    setLoading(true);
    const numericCpf = cpf.replace(/\D/g, ''); // Use only numbers for DB query
    setCpf(numericCpf);
    try {
      const usersRef = collection(db, 'users');
      // Ensure you have an index on the 'cpf' field in Firestore
      const q = query(usersRef, where('cpf', '==', numericCpf), limit(1));
      const querySnapshot = await getDocs(q);

      if (!querySnapshot.empty) {
        const userDoc = querySnapshot.docs[0];
        setExistingUser({ id: userDoc.id, ...userDoc.data() as UserProfile });
        setStep('confirm');
      } else {
        toast({
            variant: 'destructive',
            title: 'CPF não encontrado',
            description: 'Seu CPF não foi encontrado. Por favor, complete o cadastro.',
        });
        setStep('form');
      }
    } catch (error) {
      console.error("Error checking CPF:", error);
      toast({
        variant: 'destructive',
        title: 'Erro ao verificar CPF',
        description: 'Não foi possível completar a verificação. Tente novamente ou preencha os dados manualmente.',
      });
    } finally {
      setLoading(false);
    }
  };

  const handleCreateAppointment = async (patientData: { id: string; name: string; email: string; phone: string; }) => {
    setLoading(true);
    try {
        const appointmentDateTime = parseISO(date!);
        const [hour, minute] = time!.split(':').map(Number);
        appointmentDateTime.setHours(hour, minute);

        // Generate unique password
        const specialtyInitial = specialty ? specialty.substring(0, 1).toUpperCase() : 'G';
        const password = `${specialtyInitial}${Math.floor(Math.random() * 900) + 100}`;

        const newAppointment = {
            idMedico: doc(db, 'tb_medicos', doctorId),
            idPaciente: doc(db, 'users', patientData.id),
            idclinica: doc(db, 'tb_clinica', clinicId),
            nomeMedico: doctorName,
            nomePaciente: patientData.name,
            emailPaciente: patientData.email,
            telefonePaciente: patientData.phone,
            especialidade: specialty,
            dataConsulta: appointmentDateTime,
            status: 'agendado',
            tipoConsulta: 'Presencial',
            modalidade: 'Presencial',
            formaPagamento: 'A definir',
            motivoConsulta: 'Consulta agendada via totem',
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
            cpf: cpf,
            pass: password, // Save the generated password
            calendarSyncError: "inicio=undefined; fim=undefined",
            calendarSyncStatus: "invalid_datetime",
        };

        const appointmentRef = await addDoc(collection(db, 'tb_agendamentos'), newAppointment);

        // Send email confirmation in the background
        sendConfirmationEmail({
            toEmail: patientData.email,
            patientName: patientData.name,
            doctorName: doctorName!,
            specialty: specialty,
            dateTime: appointmentDateTime,
            password: password,
        });

        // Send second confirmation email
        sendSecondConfirmationEmail(appointmentRef.id, patientData.email);

        toast({
            title: 'Agendamento Realizado!',
            description: 'Sua consulta foi agendada com sucesso.',
        });
        
        router.push(`/totem/success?id=${appointmentRef.id}`);

    } catch (error) {
        console.error("Error creating appointment:", error);
        toast({
            variant: 'destructive',
            title: 'Erro ao Agendar',
            description: 'Não foi possível criar o agendamento. Tente novamente.',
        });
        setLoading(false);
    }
  }

  const handleNewUserSubmit = async (values: NewUserFormValues) => {
      setLoading(true);
      try {
          // Create new user in 'users' collection
          const newUser = {
              cpf: cpf,
              display_name: values.name,
              email: values.email,
              phone_number: values.phone,
              created_time: serverTimestamp(),
              updatedAt: serverTimestamp(),
              photo_url: `https://i.ibb.co/TmgcZ2Q/blank-profile-picture-973460-960-720.webp`,
          }
          const userDocRef = await addDoc(collection(db, 'users'), newUser);

          // Now create appointment
          await handleCreateAppointment({
              id: userDocRef.id,
              name: values.name,
              email: values.email,
              phone: values.phone,
          });

      } catch (error) {
           console.error("Error creating new user or appointment:", error);
           toast({
            variant: 'destructive',
            title: 'Erro no Cadastro',
            description: 'Não foi possível criar seu cadastro ou agendamento. Tente novamente.',
        });
        setLoading(false);
      }
  };

  const appointmentDate = format(parseISO(date!), "EEEE, dd 'de' MMMM", { locale: ptBR });
  const appointmentTime = time;

  return (
    <div className="flex min-h-screen w-full items-center justify-center bg-muted/40 p-4">
      <Card className="w-full max-w-lg shadow-2xl">
        <CardHeader>
          <CardTitle className="text-3xl font-bold tracking-tight text-primary">
            {step === 'form' ? 'Complete seu Cadastro' : 'Confirme seu Agendamento'}
          </CardTitle>
          <CardDescription>
            {step === 'cpf' ? 'Para começar, por favor, insira seu CPF.' : 'Confira os detalhes e confirme para finalizar.'}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
            {/* Resumo do Agendamento */}
            <div className="space-y-4 rounded-lg border bg-muted/30 p-4">
                <h3 className="font-semibold text-center text-lg">Resumo da Consulta</h3>
                <div className="flex items-center gap-4">
                    <Stethoscope className="h-5 w-5 text-primary" />
                    <p><span className="font-medium">Médico(a):</span> {doctorName}</p>
                </div>
                <div className="flex items-center gap-4">
                    <Calendar className="h-5 w-5 text-primary" />
                    <p className="capitalize"><span className="font-medium">Data:</span> {appointmentDate}</p>
                </div>
                <div className="flex items-center gap-4">
                    <Clock className="h-5 w-5 text-primary" />
                    <p><span className="font-medium">Horário:</span> {appointmentTime}</p>
                </div>
            </div>

            {/* Steps */}
            {step === 'cpf' && (
                <FormProvider {...cpfForm}>
                <form onSubmit={cpfForm.handleSubmit(handleCpfCheck)} className="space-y-4">
                    <FormField
                        control={cpfForm.control}
                        name="cpf"
                        render={({ field }) => (
                        <FormItem>
                            <FormLabel className="text-base">CPF</FormLabel>
                            <FormControl>
                            <Input 
                                placeholder="000.000.000-00" 
                                {...field}
                                onChange={(e) => {
                                    const formatted = formatCPF(e.target.value);
                                    field.onChange(formatted);
                                }}
                                className="h-12 text-lg" 
                                maxLength={14}
                            />
                            </FormControl>
                            <FormMessage />
                        </FormItem>
                        )}
                    />
                    <Button type="submit" size="lg" className="w-full h-14 text-lg" disabled={loading}>
                        {loading && <Loader2 className="mr-2 h-5 w-5 animate-spin" />}
                        Verificar
                    </Button>
                     <Button variant="link" className="w-full" onClick={() => setStep('form')}>
                        Não tem cadastro? Clique aqui para agendar
                    </Button>
                </form>
                </FormProvider>
            )}

            {step === 'confirm' && existingUser && (
                <div className="space-y-6">
                    <div className="space-y-2">
                        <h4 className="font-semibold text-lg">Seus Dados</h4>
                        <div className="space-y-2 rounded-md border p-4">
                            <p><span className="font-medium">Nome:</span> {existingUser.display_name}</p>
                            <p><span className="font-medium">Email:</span> {existingUser.email}</p>
                            <p><span className="font-medium">Telefone:</span> {existingUser.phone_number || 'Não informado'}</p>
                        </div>
                    </div>
                    <Button onClick={() => handleCreateAppointment({
                        id: existingUser.id,
                        name: existingUser.display_name,
                        email: existingUser.email,
                        phone: existingUser.phone_number || '',
                    })} size="lg" className="w-full h-14 text-lg" disabled={loading}>
                       {loading && <Loader2 className="mr-2 h-5 w-5 animate-spin" />}
                       Confirmar Agendamento
                    </Button>
                     <Button variant="link" onClick={() => { setStep('cpf'); setExistingUser(null); cpfForm.reset(); }}>
                        Não é você? Tente com outro CPF.
                    </Button>
                </div>
            )}

            {step === 'form' && (
                <FormProvider {...newUserForm}>
                <form onSubmit={newUserForm.handleSubmit(handleNewUserSubmit)} className="space-y-4">
                     { !cpf && (
                       <div className='p-4 bg-amber-100 dark:bg-amber-900/20 border-l-4 border-amber-500 rounded-r-md text-amber-800 dark:text-amber-200'>
                         <p className='text-sm font-medium'>Seu CPF não foi encontrado ou você optou por pular a verificação. Por favor, preencha seus dados para continuar.</p>
                       </div>
                    )}
                    <FormField name="name" control={newUserForm.control} render={({ field }) => (
                        <FormItem><FormLabel>Nome Completo</FormLabel><FormControl><Input placeholder="Seu nome" {...field} /></FormControl><FormMessage /></FormItem>
                    )} />
                    <FormField name="email" control={newUserForm.control} render={({ field }) => (
                        <FormItem><FormLabel>Email</FormLabel><FormControl><Input placeholder="seu@email.com" {...field} /></FormControl><FormMessage /></FormItem>
                    )} />
                    <FormField name="phone" control={newUserForm.control} render={({ field }) => (
                        <FormItem><FormLabel>Telefone</FormLabel><FormControl><Input placeholder="(00) 00000-0000" {...field} onChange={(e) => field.onChange(formatPhone(e.target.value))} /></FormControl><FormMessage /></FormItem>
                    )} />
                     <Button type="submit" size="lg" className="w-full h-14 text-lg" disabled={loading}>
                        {loading && <Loader2 className="mr-2 h-5 w-5 animate-spin" />}
                        Cadastrar e Agendar
                    </Button>
                      <Button variant="link" className="w-full" onClick={() => { setStep('cpf'); setCpf(''); cpfForm.reset(); }}>
                        Já tem cadastro? Verificar CPF
                    </Button>
                </form>
                 </FormProvider>
            )}

            {loading && (step === 'confirm' || step === 'form') && (
                 <div className="flex flex-col items-center justify-center space-y-4 pt-8">
                     <Loader2 className="h-8 w-8 animate-spin text-primary" />
                     <p className="text-muted-foreground">Finalizando seu agendamento...</p>
                 </div>
            )}
            
            <Button variant="ghost" onClick={() => router.back()} className="w-full mt-4">
                <ArrowLeft className="mr-2 h-4 w-4" />
                Voltar
            </Button>

        </CardContent>
      </Card>
    </div>
  );
}

    