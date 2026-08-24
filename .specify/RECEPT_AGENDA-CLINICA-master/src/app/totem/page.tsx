
'use client';

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import Link from "next/link";
import React from "react";

const HeartIcon = (props: React.SVGProps<SVGSVGElement>) => (
    <svg
      width="100"
      height="100"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <defs>
        <linearGradient id="heart-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="hsl(var(--accent))" />
          <stop offset="100%" stopColor="hsl(var(--primary))" />
        </linearGradient>
      </defs>
      <path
        d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
        stroke="url(#heart-gradient)"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
  

export default function TotemPage() {
  return (
    <div className="flex flex-col items-center justify-center h-screen w-screen bg-background">
      <div className="flex flex-col items-center justify-center gap-8">
        <HeartIcon className="h-24 w-24" />

        <h1 className="text-5xl font-bold text-foreground">
          Bem-Vindo
        </h1>

        <div className="flex flex-col gap-6 mt-8 w-80">
          <Button
            asChild
            className={cn(
                "h-20 text-xl font-semibold text-primary-foreground rounded-xl shadow-lg",
                "bg-gradient-to-r from-accent to-primary hover:from-accent/90 hover:to-primary/90 transition-all transform hover:scale-105"
            )}
          >
            <Link href="/totem/schedule">Agendar uma consulta</Link>
          </Button>
          <Button
            asChild
            className={cn(
                "h-20 text-xl font-semibold text-primary-foreground rounded-xl shadow-lg",
                "bg-gradient-to-r from-accent to-primary hover:from-accent/90 hover:to-primary/90 transition-all transform hover:scale-105"
            )}
          >
            <Link href="/totem/reschedule">Remarcar uma consulta</Link>
          </Button>
        </div>
      </div>
      <div className="absolute bottom-4">
        <Button asChild variant="link">
          <Link href="/totem/success?test=true">Testar Impressão</Link>
        </Button>
      </div>
    </div>
  );
}
