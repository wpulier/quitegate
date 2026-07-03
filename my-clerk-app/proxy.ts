import { clerkMiddleware } from "@clerk/nextjs/server";

export default clerkMiddleware();

export const config = {
  matcher: [
    "/__clerk/:path*",
    "/api/:path*",
    "/dashboard/:path*",
    "/extension/:path*",
    "/setup/:path*",
    "/sign-in/:path*",
    "/sign-up/:path*",
  ],
};
