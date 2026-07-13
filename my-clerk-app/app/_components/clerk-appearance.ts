export const clerkAppearance = {
  variables: {
    colorPrimary: "#3e63dd",
    colorText: "#18181b",
    colorTextSecondary: "#64646f",
    colorBackground: "#ffffff",
    colorInputBackground: "#ffffff",
    colorInputText: "#18181b",
    borderRadius: "0.75rem",
    fontFamily: "var(--font-geist-sans)",
  },
  elements: {
    rootBox: "w-full",
    cardBox: "w-full shadow-none",
    card: "w-full rounded-2xl border border-zinc-200 shadow-[0_18px_54px_rgba(24,24,27,0.10)]",
    headerTitle: "text-2xl font-semibold tracking-tight text-zinc-950",
    headerSubtitle: "text-sm leading-6 text-zinc-600",
    socialButtonsBlockButton:
      "min-h-11 rounded-lg border-zinc-300 font-semibold transition hover:bg-zinc-50",
    formFieldInput:
      "min-h-11 rounded-lg border-zinc-300 focus:border-[#3e63dd] focus:ring-[#3e63dd]",
    formButtonPrimary:
      "min-h-11 rounded-lg bg-[#3e63dd] font-semibold shadow-none transition hover:bg-[#3456c7]",
    footerActionLink: "font-semibold text-[#3e63dd] hover:text-[#3456c7]",
  },
};
