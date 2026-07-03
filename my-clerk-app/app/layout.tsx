import type { Metadata } from "next";
import Link from "next/link";
import { Geist, Geist_Mono } from "next/font/google";
import { ClerkProvider } from "@clerk/nextjs";
import { SiteAuthNav } from "./_components/site-auth-nav";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const clerkLocalization = {
  signIn: {
    start: {
      title: "Sign in to Tortoise",
      subtitle: "Welcome back. Sign in to continue setup.",
    },
  },
  signUp: {
    start: {
      title: "Create your Tortoise account",
      subtitle: "One account for Mac, iPhone, browser tuning, and usage status.",
    },
  },
};

export const metadata: Metadata = {
  title: "Tortoise",
  description: "Tortoise keeps the useful parts of your digital life and quiets the rest.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full overflow-x-hidden bg-[#fbfbef] text-zinc-950">
        <ClerkProvider localization={clerkLocalization}>
          <header className="bg-[#fbfbef] px-4 pt-4">
            <div className="mx-auto flex h-16 w-full max-w-6xl items-center justify-between rounded-xl border border-zinc-200/80 bg-white/75 px-5 shadow-sm backdrop-blur">
              <Link href="/" className="text-lg font-semibold">
                Tortoise
              </Link>
              <SiteAuthNav />
            </div>
          </header>
          {children}
        </ClerkProvider>
      </body>
    </html>
  );
}
