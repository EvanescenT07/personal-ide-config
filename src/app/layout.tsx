import type { Metadata, Viewport } from "next";

import { ToastProvider } from "@/components/ui/ToastProvider";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "IDE Config & AI Agent Hub",
    template: "%s | IDE Config Hub",
  },
  description:
    "Workbench hub for global IDE configurations, AI agent rules, skills, and repository history.",
  applicationName: "IDE Config & AI Agent Hub",
  authors: [{ name: "EvanescenT07" }],
  keywords: [
    "IDE config",
    "settings.json",
    "editorconfig",
    "AI agent rules",
    "AGENTS.md",
    "MCP",
    "developer tooling",
  ],
  openGraph: {
    title: "IDE Config & AI Agent Hub",
    description:
      "Browse cross-IDE configs, compose AI agent rule bundles, and inspect repository history in one unified workbench.",
    type: "website",
  },
};

export const viewport: Viewport = {
  themeColor: "#070a0f",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen antialiased">
        <ToastProvider>{children}</ToastProvider>
      </body>
    </html>
  );
}
