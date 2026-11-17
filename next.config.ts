import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  experimental: {
    agentUpgrade: "security",
    optimizePackageImports: ["lucide-react"],
  },
};

export default nextConfig;
