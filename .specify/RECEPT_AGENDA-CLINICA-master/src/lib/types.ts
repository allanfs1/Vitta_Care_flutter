

import type { DocumentReference } from 'firebase/firestore';

export type AppointmentStatus = "Confirmed" | "Pending" | "Cancelled" | "Agendado" | "Confirmado" | "Nao_agendado";
export type AppointmentType = "Internal" | "Client" | "Maintenance" | string;

export type Appointment = {
  id: string;
  title: string;
  description: string;
  start: Date;
  end: Date;
  patient: {
      name: string;
      avatarUrl?: string;
  },
  status: AppointmentStatus;
  type: AppointmentType;
  responsible: {
    name: string;
    avatarUrl?: string;
  };
};

export type User = {
  id: string;
  name: string;
  email: string;
  avatarUrl: string;
  crm?: string;
  specialty?: string;
};

export interface UserProfile {
  display_name: string;
  email: string;
  cpf?: string;
  photo_url?: string;
  roles?: ('admin' | 'med')[];
  phone_number?: string;
  endereco?: string;
  dataNascimento?: { toDate: () => Date };
  sexo?: 'Masculino' | 'Feminino' | 'Outro';
  idClinica?: DocumentReference | string;
}

export interface DoctorProfile {
  nomeCompleto: string;
  email: string;
  telefone: string;
  crm: string;
  especialidades: string[];
  endereco: string;
  fotoPerfil?: string;
  biografia?: string;
  idclinica?: DocumentReference | string;
}


export type Resource = {
  id: string;
  name: string;
  type: "Room" | "Equipment";
};

export interface DoctorAppointment {
  id: string;
  start: Date;
  patientName: string;
  type: string;
  status: string;
}

export interface AbsenceData {
    id: string;
    nomePaciente: string;
    photoUrl?: string;
    dataConsulta: Date;
    motivo: string;
    probabilidadeFalta?: number;
    riscoFalta: string;
}

export interface DoctorMetrics {
  todaysAppointments: DoctorAppointment[];
  consultationsStats: {
    name: string;
    total: number;
  }[];
  weeklyConsultations: {
    name: string;
    PrimeiraConsulta: number;
    Retorno: number;
    Encaixe: number;
  }[];
  consultationTypes: {
    name: string;
    value: number;
    fill: string;
  }[];
  performance: {
    labels: string[];
    data: {
      metric: string;
      value: number;
    }[];
  };
  absenceInsights: AbsenceData[];
}

export interface AppointmentData {
    id: string;
    dataConsulta: Date;
    status: string;
    nomeMedico?: string;
    pass?: string;
}

export interface CalendarEvent {
    id: string;
    title: string;
    start: Date;
    end: Date;
    type: 'appointment' | 'absence';
    status: string;
    patientName?: string;
    doctorName?: string;
}

// This type is deprecated, use CalendarEvent instead
export interface CalendarAppointment {
  id: string;
  title: string;
  start: Date;
  status: string;
  patientName?: string;
  doctorName?: string;
  roomName?: string;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  files?: FileInput[];
}

export interface FileInput {
    data: string; // base64 encoded
    mimeType: string;
    name?: string;
    previewUrl?: string; // For image previews
}

    