
"use client";

import * as React from "react";
import {
  addMonths,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isSameDay,
  isSameMonth,
  isToday,
  startOfMonth,
  startOfWeek,
  subMonths,
} from "date-fns";
import { ChevronLeft, ChevronRight, AlertTriangle, Check, Clock } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { useAuth } from "@/contexts/auth-context";
import { getDoctorCalendarData } from "@/lib/doctor-metrics";
import { CalendarEvent } from "@/lib/types";
import { Skeleton } from "../ui/skeleton";
import { Badge } from "../ui/badge";

const eventTypeColors: Record<string, string> = {
  confirmed: "bg-green-100 text-green-800 border-green-200 dark:bg-green-900/50 dark:text-green-300 dark:border-green-800/50",
  agendado: "bg-yellow-100 text-yellow-800 border-yellow-200 dark:bg-yellow-900/50 dark:text-yellow-300 dark:border-yellow-800/50",
  nao_agendado: "bg-red-100 text-red-800 border-red-200 dark:bg-red-900/50 dark:text-red-300 dark:border-red-800/50",
  default: "bg-gray-100 text-gray-800 border-gray-200 dark:bg-gray-900/50 dark:text-gray-300 dark:border-gray-800/50",
};

const EventIcon = ({ status }: { status: string }) => {
    switch(status) {
        case 'confirmed':
            return <Check className="h-3 w-3 mr-1.5" />;
        case 'agendado':
            return <Clock className="h-3 w-3 mr-1.5" />;
        case 'nao_agendado':
            return <AlertTriangle className="h-3 w-3 mr-1.5" />;
        default:
            return null;
    }
}


export function DoctorCalendar() {
  const { user } = useAuth();
  const [currentDate, setCurrentDate] = React.useState(new Date());
  const [events, setEvents] = React.useState<CalendarEvent[]>([]);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    const fetchEvents = async () => {
      if (user?.email) {
        setLoading(true);
        try {
          const fetchedEvents = await getDoctorCalendarData(user.email);
          setEvents(fetchedEvents);
        } catch (error) {
          console.error("Failed to fetch calendar events:", error);
          setEvents([]);
        } finally {
          setLoading(false);
        }
      }
    };
    fetchEvents();
  }, [user]);

  const start = startOfWeek(startOfMonth(currentDate));
  const end = endOfWeek(endOfMonth(currentDate));
  const days = eachDayOfInterval({ start, end });

  const nextMonth = () => setCurrentDate(addMonths(currentDate, 1));
  const prevMonth = () => setCurrentDate(subMonths(currentDate, 1));

  if (loading) {
      return (
          <div className="rounded-lg border bg-card text-card-foreground shadow-sm">
            <div className="p-4 flex justify-between items-center border-b">
                <Skeleton className="h-8 w-48" />
                <Skeleton className="h-8 w-24" />
            </div>
            <div className="grid grid-cols-7">
                {[...Array(7)].map((_, i) => <div key={i} className="p-2 border-r border-b"><Skeleton className="h-6 w-12"/></div>)}
                {[...Array(35)].map((_, i) => <div key={i} className="h-40 p-2 border-r border-b"><Skeleton className="h-full w-full"/></div>)}
            </div>
          </div>
      )
  }

  return (
    <TooltipProvider>
      <div className="rounded-lg border bg-card text-card-foreground shadow-sm">
        <div className="flex items-center justify-between p-4 border-b">
          <div className="flex items-center gap-2">
            <Button variant="outline" size="icon" onClick={prevMonth}>
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <h2 className="text-lg font-semibold font-headline w-32 text-center">
              {format(currentDate, "MMMM yyyy")}
            </h2>
            <Button variant="outline" size="icon" onClick={nextMonth}>
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
          <Button variant="outline" onClick={() => setCurrentDate(new Date())}>Today</Button>
        </div>
        <div className="grid grid-cols-7">
          {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map((day) => (
            <div key={day} className="p-2 text-center text-sm font-medium text-muted-foreground border-r border-b">
              {day}
            </div>
          ))}
          {days.map((day) => {
            const dayEvents = events.filter((event) =>
              isSameDay(day, event.start)
            );
            return (
              <div
                key={day.toString()}
                className={cn(
                  "h-40 p-2 border-r border-b flex flex-col gap-1 overflow-hidden",
                  !isSameMonth(day, currentDate) && "bg-muted/50 text-muted-foreground"
                )}
              >
                <time
                  dateTime={format(day, "yyyy-MM-dd")}
                  className={cn(
                    "h-8 w-8 flex items-center justify-center rounded-full text-sm",
                    isToday(day) && "bg-primary text-primary-foreground"
                  )}
                >
                  {format(day, "d")}
                </time>
                <div className="flex-1 overflow-y-auto -mx-1 px-1 space-y-1">
                  {dayEvents.map((event) => (
                    <Tooltip key={event.id}>
                      <TooltipTrigger asChild>
                        <div
                          className={cn(
                            "rounded-md p-1.5 text-xs border cursor-pointer flex items-center",
                            eventTypeColors[event.status.toLowerCase()] || eventTypeColors.default
                          )}
                        >
                          <EventIcon status={event.status.toLowerCase()} />
                          <div className="flex-1 overflow-hidden">
                             <p className="font-semibold truncate">{event.title}</p>
                             <p className="truncate">{format(event.start, "h:mm a")}</p>
                          </div>
                        </div>
                      </TooltipTrigger>
                      <TooltipContent>
                        <p className="font-bold">{event.title}</p>
                        <p>{format(event.start, "MMMM d, h:mm a")} - {format(event.end, "h:mm a")}</p>
                        <p>Paciente: {event.patientName}</p>
                        <Badge variant="secondary" className="capitalize">{event.status.replace(/_/g, ' ')}</Badge>
                      </TooltipContent>
                    </Tooltip>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </TooltipProvider>
  );
}
