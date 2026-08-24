import { addDays, addHours, subDays } from "date-fns";
import type { User, Resource, Appointment } from "./types";

export const users: User[] = [
  { id: "user-1", name: "Alex Johnson", email: "alex@example.com", avatarUrl: "https://placehold.co/100x100" },
  { id: "user-2", name: "Maria Garcia", email: "maria@example.com", avatarUrl: "https://placehold.co/100x100" },
  { id: "user-3", name: "James Smith", email: "james@example.com", avatarUrl: "https://placehold.co/100x100" },
  { id: "user-4", name: "Priya Patel", email: "priya@example.com", avatarUrl: "https://placehold.co/100x100" },
];

export const medicalTeam: User[] = [
  { 
    id: "doc-1", 
    name: "Dr. Alex Johnson", 
    email: "alex.j@agendawise.com", 
    avatarUrl: "https://placehold.co/200x200", 
    crm: "CRM/SP 123456", 
    specialty: "Cardiologista" 
  },
  { 
    id: "doc-2", 
    name: "Dra. Maria Garcia", 
    email: "maria.g@agendawise.com", 
    avatarUrl: "https://placehold.co/200x200", 
    crm: "CRM/RJ 654321", 
    specialty: "Dermatologista" 
  },
  { 
    id: "doc-3", 
    name: "Dr. James Smith", 
    email: "james.s@agendawise.com", 
    avatarUrl: "https://placehold.co/200x200", 
    crm: "CRM/MG 112233", 
    specialty: "Ortopedista" 
  },
  { 
    id: "doc-4", 
    name: "Dra. Priya Patel", 
    email: "priya.p@agendawise.com", 
    avatarUrl: "https://placehold.co/200x200", 
    crm: "CRM/BA 445566", 
    specialty: "Pediatra" 
  },
    { 
    id: "doc-5", 
    name: "Dr. Carlos Oliveira", 
    email: "carlos.o@agendawise.com", 
    avatarUrl: "https://placehold.co/200x200", 
    crm: "CRM/SP 789012", 
    specialty: "Neurologista" 
  },
  { 
    id: "doc-6", 
    name: "Dra. Ana Pereira", 
    email: "ana.p@agendawise.com", 
    avatarUrl: "https://placehold.co/200x200", 
    crm: "CRM/RS 210987", 
    specialty: "Ginecologista" 
  },
];

export const resources: Resource[] = [
  { id: "room-1", name: "Conference Room A", type: "Room" },
  { id: "room-2", name: "Conference Room B", type: "Room" },
  { id: "equip-1", name: "Projector X1", type: "Equipment" },
  { id: "equip-2", name: "Video Conferencing Kit", type: "Equipment" },
];

const now = new Date();

export const appointments: Appointment[] = [
  {
    id: "appt-1",
    title: "Project Alpha Kick-off",
    description: "Initial meeting to discuss Project Alpha scope and deliverables.",
    start: addHours(now, 2),
    end: addHours(now, 3),
    participants: [users[0], users[1]],
    resource: resources[0],
    status: "Confirmed",
    type: "Internal",
    responsible: users[0],
  },
  {
    id: "appt-2",
    title: "Client Demo - Innovate Inc.",
    description: "Demonstration of the new platform features to Innovate Inc.",
    start: addHours(now, 4),
    end: addHours(now, 5),
    participants: [users[1], users[2]],
    resource: resources[3],
    status: "Confirmed",
    type: "Client",
    responsible: users[1],
  },
  {
    id: "appt-3",
    title: "Weekly Sync",
    description: "Team's weekly synchronization meeting.",
    start: addDays(now, 1),
    end: addHours(addDays(now, 1), 1),
    participants: users,
    resource: resources[1],
    status: "Confirmed",
    type: "Internal",
    responsible: users[2],
  },
  {
    id: "appt-4",
    title: "Projector Maintenance",
    description: "Scheduled maintenance for Projector X1.",
    start: addDays(now, 2),
    end: addHours(addDays(now, 2), 1),
    participants: [],
    resource: resources[2],
    status: "Confirmed",
    type: "Maintenance",
    responsible: users[3],
  },
  {
    id: "appt-5",
    title: "Q3 Planning Session",
    description: "Planning session for the third quarter.",
    start: subDays(now, 5),
    end: addHours(subDays(now, 5), 2),
    participants: [users[0], users[3]],
    resource: resources[0],
    status: "Confirmed",
    type: "Internal",
    responsible: users[0],
  },
    {
    id: "appt-6",
    title: "Hiring Committee Interview",
    description: "Interview for the senior developer position.",
    start: addDays(now, 3),
    end: addHours(addDays(now, 3), 1),
    participants: [users[0], users[2]],
    resource: resources[1],
    status: "Pending",
    type: "Internal",
    responsible: users[0],
  },
  {
    id: "appt-7",
    title: "Past Client Follow-up",
    description: "Follow-up call with a client from last week.",
    start: subDays(now, 7),
    end: addHours(subDays(now, 7), 0.5),
    participants: [users[1]],
    resource: resources[3],
    status: "Confirmed",
    type: "Client",
    responsible: users[1],
  },
  {
    id: "appt-8",
    title: "Cancelled Meeting",
    description: "This meeting was cancelled.",
    start: subDays(now, 2),
    end: addHours(subDays(now, 2), 1),
    participants: [users[2], users[3]],
    resource: resources[0],
    status: "Cancelled",
    type: "Internal",
    responsible: users[2],
  },
];
