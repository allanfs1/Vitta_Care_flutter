
'use client';

import * as React from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { useTheme } from '@/contexts/theme-context';
import { Sun, Moon, Palette, Sidebar as SidebarIcon, PanelLeft, PanelLeftClose } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { PageHeader } from '@/components/page-header';

export default function SettingsPage() {
  const { theme, setTheme, primaryColor, setPrimaryColor, sidebarStyle, setSidebarStyle } = useTheme();

  const colorPalette = [
    { name: 'Magenta', hsl: '312 95% 58%' },
    { name: 'Blue', hsl: '218 92% 62%' },
    { name: 'Green', hsl: '142 71% 45%' },
    { name: 'Orange', hsl: '25 95% 53%' },
    { name: 'Red', hsl: '0 84% 60%' },
  ];

  const handlePrimaryColorChange = (hsl: string) => {
    setPrimaryColor(hsl);
  };
  
  const handleSidebarStyleChange = (style: 'icon' | 'offcanvas' | 'default') => {
    setSidebarStyle(style);
  }

  return (
    <div className="flex flex-col gap-8">
      <PageHeader 
        title="Configurações"
        description="Personalize a aparência e o comportamento do sistema."
      />

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Palette className="h-5 w-5" />
            Aparência
          </CardTitle>
          <CardDescription>
            Escolha o tema e a cor de destaque do seu ambiente.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-8">
          <div className="space-y-4">
            <Label>Tema</Label>
            <RadioGroup
              value={theme}
              onValueChange={(value) => setTheme(value as 'light' | 'dark')}
              className="flex flex-col sm:flex-row gap-4"
            >
              <div className="flex-1">
                <RadioGroupItem value="light" id="light" className="peer sr-only" />
                <Label
                  htmlFor="light"
                  className="flex flex-col items-center justify-between rounded-md border-2 border-muted bg-popover p-4 hover:bg-accent hover:text-accent-foreground peer-data-[state=checked]:border-primary [&:has([data-state=checked])]:border-primary"
                >
                  <Sun className="mb-3 h-6 w-6" />
                  Claro
                </Label>
              </div>
              <div className="flex-1">
                <RadioGroupItem value="dark" id="dark" className="peer sr-only" />
                <Label
                  htmlFor="dark"
                  className="flex flex-col items-center justify-between rounded-md border-2 border-muted bg-popover p-4 hover:bg-accent hover:text-accent-foreground peer-data-[state=checked]:border-primary [&:has([data-state=checked])]:border-primary"
                >
                  <Moon className="mb-3 h-6 w-6" />
                  Escuro
                </Label>
              </div>
            </RadioGroup>
          </div>
          <div className="space-y-4">
            <Label>Cor de Destaque</Label>
            <div className="flex flex-wrap gap-3">
              {colorPalette.map(({ name, hsl }) => (
                <Button
                  key={name}
                  variant="outline"
                  size="icon"
                  className={cn(
                    'h-10 w-10 rounded-full',
                    primaryColor === hsl && 'border-4 border-primary'
                  )}
                  style={{ backgroundColor: `hsl(${hsl})` }}
                  onClick={() => handlePrimaryColorChange(hsl)}
                  aria-label={`Select ${name} color`}
                >
                    <span className="sr-only">{name}</span>
                </Button>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>
      
       <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <SidebarIcon className="h-5 w-5" />
            Barra Lateral (Desktop)
          </CardTitle>
          <CardDescription>
            Defina como a barra de navegação lateral se comporta em telas maiores.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
           <RadioGroup
              value={sidebarStyle}
              onValueChange={(value) => handleSidebarStyleChange(value as 'icon' | 'offcanvas' | 'default')}
              className="grid grid-cols-1 md:grid-cols-3 gap-4"
            >
              <div>
                <RadioGroupItem value="default" id="sidebar-default" className="peer sr-only" />
                <Label
                  htmlFor="sidebar-default"
                  className="flex flex-col items-center justify-center rounded-md border-2 border-muted bg-popover p-4 h-32 text-center hover:bg-accent hover:text-accent-foreground peer-data-[state=checked]:border-primary"
                >
                  <PanelLeft className="mb-3 h-8 w-8" />
                  <span className='font-semibold'>Visível</span>
                  <span className='text-xs text-muted-foreground'>A barra lateral fica sempre aberta.</span>
                </Label>
              </div>
              <div>
                <RadioGroupItem value="icon" id="sidebar-icon" className="peer sr-only" />
                <Label
                  htmlFor="sidebar-icon"
                  className="flex flex-col items-center justify-center rounded-md border-2 border-muted bg-popover p-4 h-32 text-center hover:bg-accent hover:text-accent-foreground peer-data-[state=checked]:border-primary"
                >
                   <SidebarIcon className="mb-3 h-8 w-8" />
                   <span className='font-semibold'>Recolhida</span>
                   <span className='text-xs text-muted-foreground'>Apenas os ícones são mostrados.</span>
                </Label>
              </div>
              <div>
                <RadioGroupItem value="offcanvas" id="sidebar-offcanvas" className="peer sr-only" />
                <Label
                  htmlFor="sidebar-offcanvas"
                  className="flex flex-col items-center justify-center rounded-md border-2 border-muted bg-popover p-4 h-32 text-center hover:bg-accent hover:text-accent-foreground peer-data-[state=checked]:border-primary"
                >
                  <PanelLeftClose className="mb-3 h-8 w-8" />
                  <span className='font-semibold'>Oculta</span>
                   <span className='text-xs text-muted-foreground'>A barra fica fora da tela.</span>
                </Label>
              </div>
            </RadioGroup>
        </CardContent>
      </Card>
    </div>
  );
}
