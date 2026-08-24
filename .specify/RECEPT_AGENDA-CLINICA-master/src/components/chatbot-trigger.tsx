
'use client';

import { Button } from '@/components/ui/button';
import { Bot } from 'lucide-react';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import Link from 'next/link';

export function ChatbotTrigger() {
  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <Button
            asChild
            className="fixed bottom-6 right-6 h-16 w-16 rounded-full shadow-lg z-50"
            size="icon"
          >
            <Link href="/chatbot">
              <Bot className="h-8 w-8" />
              <span className="sr-only">Abrir assistente</span>
            </Link>
          </Button>
        </TooltipTrigger>
        <TooltipContent side="left">
          <p>Assistente IA</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}
