
import type { Metadata } from "next";
import { AppLayout } from "@/components/app-layout";
import { Toaster } from "@/components/ui/toaster";
import { AuthProvider } from "@/contexts/auth-context";
import { ThemeProvider } from "@/contexts/theme-context";
import { FavoritesProvider } from "@/contexts/favorites-context";
import { ChatbotTrigger } from "@/components/chatbot-trigger";
import "./globals.css";
import { FullScreenProvider } from "@/contexts/fullscreen-context";
import { TotemSessionProvider } from "@/contexts/totem-session-context";

export const metadata: Metadata = {
  title: "Agenda Clínica",
  description: "Internal dashboard for managing appointments and resources.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Space+Grotesk:wght@400;500;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="font-body antialiased">
        <ThemeProvider>
          <AuthProvider>
            <TotemSessionProvider>
               <FavoritesProvider>
                  <FullScreenProvider>
                      <AppLayout>
                        {children}
                      </AppLayout>
                  </FullScreenProvider>
              </FavoritesProvider>
              <Toaster />
              <ChatbotTrigger />
            </TotemSessionProvider>
          </AuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
