import { SignUp } from "@clerk/nextjs";
import { AuthPageShell } from "@/app/_components/auth-page-shell";

export default function SignUpPage() {
  return (
    <AuthPageShell
      alternateHref="/sign-in"
      alternateLabel="I already have an account"
      description="Set up one account for QuietGate in Chrome and Tortoise on Mac and iPhone—then choose what gets quieted."
      eyebrow="Start here"
      title="One account. Every protected surface."
    >
      <SignUp
        fallbackRedirectUrl="/setup"
        forceRedirectUrl="/setup"
        path="/sign-up"
        routing="path"
        signInUrl="/sign-in"
      />
    </AuthPageShell>
  );
}
