
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  SidebarMenu,
  SidebarMenuItem,
  SidebarMenuButton,
} from "@/components/ui/sidebar";
import {
  BarChart2,
  CalendarDays,
  LayoutDashboard,
  ListTodo,
  HeartPulse,
  Settings,
  Bot,
  Tablet,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/contexts/auth-context";

const allLinks = [
  { href: "/", label: "Painel", icon: LayoutDashboard, roles: ['admin'] },
  { href: "/calendar", label: "Calendário", icon: CalendarDays, roles: ['admin'] },
  { href: "/appointments", label: "Monitor", icon: ListTodo, roles: ['admin'] },
  { href: "/totem", label: "Totem", icon: Tablet, roles: ['admin'] },
  { href: "/doctor/dashboard", label: "Minhas Consultas", icon: HeartPulse, roles: ['med'] },
  { href: "/doctor/calendar", label: "Meu Calendário", icon: CalendarDays, roles: ['med'] },
  { href: "/settings", label: "Configurações", icon: Settings, roles: ['admin', 'med'] },
];

export function MainNav() {
  const pathname = usePathname();
  const { userProfile, isDoctor } = useAuth();
  
  const userRoles = userProfile?.roles || [];
  const isAdmin = userRoles.includes('admin');

  const links = allLinks.filter(link => {
    if (!link.roles) {
        // If a link has no roles defined, don't show it to any user by default.
        return false;
    }
    if (isDoctor) {
      return link.roles.includes('med');
    }
    if(isAdmin) {
      return link.roles.includes('admin');
    }
    // Default user might not exist, but as a fallback, show admin links.
    // A better approach would be to define a 'user' role.
    return link.roles.includes('admin');
  });

  return (
    <SidebarMenu>
      {links.map((link) => (
        <SidebarMenuItem key={link.href}>
          <SidebarMenuButton
            asChild
            isActive={pathname === link.href}
            className={cn(
              "text-sidebar-foreground/80 hover:text-sidebar-foreground",
              "data-[active=true]:text-sidebar-primary-foreground data-[active=true]:bg-sidebar-primary/80"
            )}
            tooltip={link.label}
          >
            <Link href={link.href}>
              <link.icon className={cn("h-5 w-5", 
                  pathname === link.href 
                  ? "text-sidebar-primary-foreground" 
                  : "text-muted-foreground group-hover:text-accent-foreground"
              )} />
              <span className={cn(
                 "bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent",
                 pathname === link.href && "text-sidebar-primary-foreground"
              )}>{link.label}</span>
            </Link>
          </SidebarMenuButton>
        </SidebarMenuItem>
      ))}
    </SidebarMenu>
  );
}
