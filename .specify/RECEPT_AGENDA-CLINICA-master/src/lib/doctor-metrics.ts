
import { db } from "@/lib/firebase";
import { collection, getDocs, query, where, Timestamp, DocumentReference, doc, getDoc, limit } from "firebase/firestore";
import {
  startOfToday,
  endOfToday,
  eachDayOfInterval,
  format,
  subDays,
  startOfMonth,
  endOfMonth,
  startOfWeek,
  endOfWeek
} from "date-fns";
import { ptBR } from 'date-fns/locale';
import { DoctorAppointment, DoctorMetrics, AbsenceData, CalendarEvent, UserProfile } from "./types";

async function getDoctorRefByEmail(doctorEmail: string): Promise<DocumentReference> {
    const medicosRef = collection(db, "tb_medicos");
    const medicoQuery = query(medicosRef, where("email", "==", doctorEmail));
    const medicoSnapshot = await getDocs(medicoQuery);

    if (medicoSnapshot.empty) {
        throw new Error(`Perfil do médico não encontrado na coleção tb_medicos com o email: ${doctorEmail}`);
    }
    
    return medicoSnapshot.docs[0].ref as DocumentReference;
}


export async function getDoctorCalendarData(doctorEmail: string): Promise<CalendarEvent[]> {
    const medicoRef = await getDoctorRefByEmail(doctorEmail);

    // 1. Fetch Appointments
    const appointmentsRef = collection(db, "tb_agendamentos");
    const appointmentsQuery = query(appointmentsRef, where("idMedico", "==", medicoRef));
    const appointmentsSnapshot = await getDocs(appointmentsQuery);

    const appointmentEvents: CalendarEvent[] = appointmentsSnapshot.docs.map(doc => {
        const data = doc.data();
        const startDate = (data.dataConsulta as Timestamp).toDate();
        return {
            id: doc.id,
            title: data.motivoConsulta || 'Consulta',
            start: startDate,
            end: new Date(startDate.getTime() + 60 * 60 * 1000), // Assuming 1 hour duration
            type: 'appointment',
            status: data.status.toLowerCase() || 'desconhecido',
            patientName: data.nomePaciente || 'N/A',
            doctorName: data.nomeMedico || 'N/A',
        };
    });

    const appointmentIds = appointmentsSnapshot.docs.map(doc => doc.ref);

    let absenceEvents: CalendarEvent[] = [];
    if (appointmentIds.length > 0) {
        // 2. Fetch Absence Alerts related to the appointments
        const absenceRef = collection(db, 'tb_faltas_data');
        // Firestore 'in' query is limited to 30 items. 
        // For a real app, we might need to batch this. For now, we take the most recent 30 appointments.
        const relevantAppointmentIds = appointmentIds.slice(0, 30);
        const absenceQuery = query(absenceRef, where('idConsulta', 'in', relevantAppointmentIds));
        const absenceSnapshot = await getDocs(absenceQuery);

        absenceEvents = absenceSnapshot.docs.map(doc => {
            const data = doc.data();
            const startDate = (data.data_falta_consulta as Timestamp).toDate();
            return {
                id: doc.id,
                title: `Risco de Falta: ${data.nomePaciente || ''}`,
                start: startDate,
                end: new Date(startDate.getTime() + 60 * 60 * 1000),
                type: 'absence',
                status: 'nao_agendado', // Custom status for coloring
                patientName: data.nomePaciente || 'N/A',
            };
        });
    }

    return [...appointmentEvents, ...absenceEvents];
}


export async function getDoctorDashboardMetrics(doctorEmail: string): Promise<DoctorMetrics> {
    
    const medicoRef = await getDoctorRefByEmail(doctorEmail);

    const appointmentsRef = collection(db, "tb_agendamentos");
    const doctorAppointmentsQuery = query(
        appointmentsRef, 
        where("idMedico", "==", medicoRef)
    );
    const doctorAppointmentsSnapshot = await getDocs(doctorAppointmentsQuery);
    
    const doctorAppointmentIds = doctorAppointmentsSnapshot.docs.map(doc => doc.ref);


    const allAppointments: DoctorAppointment[] = doctorAppointmentsSnapshot.docs.map(doc => {
        const data = doc.data();
        return {
            id: doc.id,
            start: (data.dataConsulta as Timestamp).toDate(),
            patientName: data.nomePaciente || 'Paciente não informado',
            type: data.tipoConsulta || 'Não especificado',
            status: data.status || 'Não especificado',
        };
    });

    // --- Metric Calculations ---
    const today = new Date();

    // Today's Appointments
    const todayStart = startOfToday();
    const todayEnd = endOfToday();
    const todaysAppointments = allAppointments
        .filter(a => a.start >= todayStart && a.start <= todayEnd)
        .sort((a, b) => a.start.getTime() - b.start.getTime());

    // Consultations Stats (Bar Chart) - Last 4 days for example
    const last4Days = eachDayOfInterval({
        start: subDays(todayStart, 3),
        end: todayStart
    });
    
    const consultationsStats = last4Days.map(day => {
        const dayStart = day;
        const dayEnd = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 23, 59, 59);
        const count = allAppointments.filter(a => {
            const appointmentDate = a.start;
            return appointmentDate >= dayStart && appointmentDate <= dayEnd;
        }).length;
        
        return {
            name: format(day, 'dd/MM'),
            total: count
        };
    });
    
    // Weekly Consultations (Line Chart) - Last 7 days
    const last7DaysInterval = eachDayOfInterval({
        start: subDays(new Date(), 6),
        end: new Date(),
    });

    const weeklyConsultations = last7DaysInterval.map(day => {
        const dayStart = new Date(day.setHours(0, 0, 0, 0));
        const dayEnd = new Date(day.setHours(23, 59, 59, 999));

        const dayAppointments = allAppointments.filter(a => a.start >= dayStart && a.start <= dayEnd);
        
        const primeiraConsulta = dayAppointments.filter(a => a.type.toLowerCase() === 'primeira consulta').length;
        const retorno = dayAppointments.filter(a => a.type.toLowerCase() === 'retorno').length;
        const encaixe = dayAppointments.filter(a => a.type.toLowerCase() === 'encaixe').length;

        return {
            name: format(day, 'EEE', { locale: ptBR }),
            'PrimeiraConsulta': primeiraConsulta,
            'Retorno': retorno,
            'Encaixe': encaixe
        }
    });

    // Consultation Types (Pie Chart) - Current Month
    const monthStart = startOfMonth(today);
    const monthEnd = endOfMonth(today);
    const thisMonthAppointments = allAppointments.filter(a => a.start >= monthStart && a.start <= monthEnd);

    const consultationTypes = thisMonthAppointments.reduce((acc, appt) => {
        const type = appt.type || 'Outro';
        acc[type] = (acc[type] || 0) + 1;
        return acc;
    }, {} as Record<string, number>);

    const consultationTypesData = Object.entries(consultationTypes).map(([name, value], index) => ({
        name,
        value,
        fill: `hsl(var(--chart-${index + 1}))`,
    }));

    // Personal Performance (Radar Chart) - Simulated data
    const performanceData = {
        labels: ["Pontualidade", "Avaliação", "Retorno", "Novos Pacientes", "Consultas (Mês)"],
        data: [
          {
            metric: "Pontualidade",
            value: 92, // Simulated
          },
          {
            metric: "Avaliação",
            value: 4.8, // Simulated
          },
          {
            metric: "Retorno",
            value: 78, // Simulated
          },
          {
            metric: "Novos Pacientes",
            value: 15, // Simulated
          },
          {
            metric: "Consultas (Mês)",
            value: thisMonthAppointments.length,
          },
        ],
    };

    // Absence Insights
    let absenceInsights: AbsenceData[] = [];
    if (doctorAppointmentIds.length > 0) {
        // Firestore 'in' query is limited to 30 items. 
        // For a real app, we might need to batch this. For now, we take the most recent 30 appointments.
        const relevantAppointmentIds = doctorAppointmentIds.slice(0, 30);
        const absenceRef = collection(db, 'tb_faltas_data');
        const absenceQuery = query(absenceRef, where('idConsulta', 'in', relevantAppointmentIds), limit(10));
        const absenceSnapshot = await getDocs(absenceQuery);
        
        const promises = absenceSnapshot.docs.map(async (d) => {
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
                console.error("Error fetching patient name for absence doc " + d.id, e);
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
        
        absenceInsights = await Promise.all(promises);
    }


    return {
        todaysAppointments,
        consultationsStats,
        weeklyConsultations,
        consultationTypes: consultationTypesData,
        performance: performanceData,
        absenceInsights,
    };
}
