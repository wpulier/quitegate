# Tortoise Web

This is the public setup site and account dashboard for Tortoise.

## Required Launch Environment

The dad-test install flow depends on these public URLs being real before launch:

```env
NEXT_PUBLIC_MAC_DOWNLOAD_URL=https://github.com/wpulier/quitegate/releases/latest/download/Tortoise.dmg
NEXT_PUBLIC_IOS_TESTFLIGHT_URL=https://testflight.apple.com/join/762eByyC
NEXT_PUBLIC_CHROME_EXTENSION_URL=https://chromewebstore.google.com/detail/quietgate-focus-adult-blo/gdonnnhgjfmdejnhbhbfhinhmkgjalee
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
CLERK_JWT_AUDIENCE=tortoise-api
CLERK_AUTHORIZED_PARTIES=https://yourtortoise.com
```

Do not use `https://testflight.apple.com/` as the iOS URL. The download route treats that generic URL as missing.

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser.

Primary routes:

- `/` public landing page
- `/setup` guided install checklist
- `/dashboard` technical account/device dashboard
- `/download/mac`, `/download/ios`, `/download/chrome` env-backed redirects

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
