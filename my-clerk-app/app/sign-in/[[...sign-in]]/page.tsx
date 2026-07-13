import { SignIn } from "@clerk/nextjs";
import { AuthPageShell } from "@/app/_components/auth-page-shell";

export default function SignInPage() {
  return (
    <AuthPageShell
      alternateHref="/sign-up"
      alternateLabel="Create an account"
      description="Reconnect your devices, browser tuning, blocking rules, and usage status with one secure account."
      eyebrow="Welcome back"
      title="Your quieter internet is waiting."
    >
      <SignIn
        fallbackRedirectUrl="/setup"
        forceRedirectUrl="/setup"
        path="/sign-in"
        routing="path"
        signUpUrl="/sign-up"
      />
    </AuthPageShell>
  );
}
