import type { SVGProps } from "react";

export const Icons = {
  Logo: (props: SVGProps<SVGSVGElement>) => (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      {...props}
    >
      <path d="M8 2v4" />
      <path d="M16 2v4" />
      <rect width="18" height="18" x="3" y="4" rx="2" />
      <path d="M3 10h18" />
      <path d="m14 14-4 4" />
      <path d="m14 18-4-4" />
    </svg>
  ),
};

export const ClinicLogo = (props: SVGProps<SVGSVGElement>) => (
    <svg
        viewBox="0 0 100 100"
        xmlns="http://www.w3.org/2000/svg"
        {...props}
    >
        <defs>
            <linearGradient id="face-gradient" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" style={{stopColor: 'hsl(var(--primary))', stopOpacity: 1}} />
                <stop offset="100%" style={{stopColor: 'hsl(var(--accent))', stopOpacity: 1}} />
            </linearGradient>
            <linearGradient id="heart-gradient" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" style={{stopColor: 'hsl(var(--accent))', stopOpacity: 1}} />
                <stop offset="100%" style={{stopColor: 'hsl(var(--primary))', stopOpacity: 1}} />
            </linearGradient>
        </defs>
        
        {/* Face Outline */}
        <path
            d="M 90,75 C 90,90 70,95 55,95 C 40,95 20,90 20,75 C 20,60 30,50 40,40 C 55,25 70,20 80,30 C 90,40 90,60 90,75 Z"
            fill="none"
            stroke="url(#face-gradient)"
            strokeWidth="5"
            strokeLinecap="round"
            strokeLinejoin="round"
        />
        
        {/* Heart shape */}
        <path
            d="M 60,35 C 50,20 30,25 30,45 C 30,65 50,75 60,85 C 70,75 90,65 90,45 C 90,25 70,20 60,35 Z"
            fill="none"
            stroke="url(#heart-gradient)"
            strokeWidth="5"
            strokeLinecap="round"
            strokeLinejoin="round"
        />
    </svg>
);
