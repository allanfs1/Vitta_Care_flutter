
"use client";

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarInset,
  SidebarProvider,
} from "@/components/ui/sidebar";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { MainNav } from "@/components/main-nav";
import { AppHeader } from "@/components/app-header";
import { Icons } from "@/components/icons";
import Link from "next/link";
import { LogOut } from "lucide-react";
import * as React from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { useAuth } from '@/contexts/auth-context';
import { LoadingScreen } from './loading-screen';
import { signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { useTheme } from "@/contexts/theme-context";
import Image from 'next/image';
import { useFullScreen } from "@/contexts/fullscreen-context";


function AppLayoutContent({ children }: { children: React.ReactNode }) {
  const { user, isDoctor, loading } = useAuth();
  const { sidebarStyle } = useTheme();
  const { isFullScreen } = useFullScreen();
  const router = useRouter();
  const pathname = usePathname();
  
  const publicPages = ['/login', '/totem', '/totem/schedule', '/totem/reschedule', '/totem/confirm', '/totem/success'];
  const isPublicPage = publicPages.some(page => pathname.startsWith(page));

  
  const allowedDoctorPages = ['/doctor/dashboard', '/doctor/calendar', '/profile', '/settings', '/chatbot'];
  const isAllowedDoctorPage = allowedDoctorPages.includes(pathname);


  React.useEffect(() => {
    if (loading) return;
    
    // Redirect non-users away from non-public pages.
    if (!user && !isPublicPage) {
      router.push('/login');
    } else if (user) {
      if(isDoctor && !isAllowedDoctorPage) {
        router.push('/doctor/dashboard');
      }
    }
  }, [user, isDoctor, loading, router, pathname, isAllowedDoctorPage, isPublicPage]);

  // Show loading screen while auth state is resolving, unless it's a public page that can be shown immediately.
  if (loading && !isPublicPage) {
    return <LoadingScreen />;
  }
  
  // If we are on the login page and the user is already logged in, show loading until redirect happens.
  if (user && pathname === '/login') {
      return <LoadingScreen />
  }

  // Handle full-screen pages like Totem and Appointments
  if (isPublicPage || (pathname === '/appointments' && isFullScreen)) {
    return <main className="min-h-screen">{children}</main>;
  }
  
  // Full Layout with Sidebar for standard users
  const getInitials = (name: string | null | undefined) => {
    if (!name) return 'U';
    return name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
  }
  
  const handleLogout = async () => {
    await signOut(auth);
    router.push('/login');
  };
  
  const collapsible = sidebarStyle === 'default' ? 'none' : sidebarStyle;
  const mainContentClass = (pathname === '/chatbot') ? "" : "p-4 pt-6 sm:p-6 sm:pt-8 lg:p-8";


  return (
    <>
      <Sidebar collapsible={collapsible === 'none' ? 'icon' : collapsible}>
        <SidebarHeader>
          <Link href="/" className="flex items-center gap-2">
            <Image 
                src="https://agendaclinicas.com.br/wp-content/uploads/2025/03/agenda-Clinica-222.png" 
                alt="Agenda Clínica Logo"
                width={80}
                height={40}
                className="object-contain"
            />
          </Link>
        </SidebarHeader>
        <SidebarContent>
          <MainNav />
        </SidebarContent>
        <SidebarFooter>
          <div className="flex items-center gap-3 p-2">
            <Link href="/profile" className="flex flex-1 items-center gap-3 overflow-hidden rounded-md p-1 -m-1 transition-colors hover:bg-sidebar-accent">
                <Avatar className="h-10 w-10">
                  {user?.photoURL && <AvatarImage src={user.photoURL} alt={user.displayName || 'User'} />}
                  <AvatarFallback>{getInitials(user?.displayName)}</AvatarFallback>
                </Avatar>
                <div className="flex flex-col overflow-hidden">
                  <span className="truncate text-sm font-medium">{user?.displayName || 'User'}</span>
                  <span className="truncate text-xs text-muted-foreground">
                    {user?.email}
                  </span>
                </div>
            </Link>
            <Button variant="ghost" size="icon" className="ml-auto" onClick={handleLogout}>
              <LogOut />
            </Button>
          </div>
        </SidebarFooter>
      </Sidebar>
      <SidebarInset>
        <AppHeader />
        <main className={`min-h-[calc(100vh-4rem)] ${mainContentClass}`}>
          {children}
        </main>
      </SidebarInset>
    </>
  );
}


export function AppLayout({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();
    const publicPages = ['/login', '/totem', '/totem/schedule', '/totem/reschedule', '/totem/confirm', '/totem/success'];
    const isPublicPage = publicPages.some(page => pathname.startsWith(page));

    if (isPublicPage) {
        return <>{children}</>;
    }
    
    return (
        <SidebarProvider>
            <AppLayoutContent>{children}</AppLayoutContent>
        </SidebarProvider>
    )
}
