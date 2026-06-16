import "server-only";

import { auth } from "@clerk/nextjs/server";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

export function hasSupabasePublicConfig() {
  return Boolean(supabaseUrl?.trim() && supabaseKey?.trim());
}

export async function createClerkSupabaseClient() {
  const { getToken } = await auth();

  if (!supabaseUrl || !supabaseKey) {
    throw new Error("Supabase public configuration is not set.");
  }

  return createClient(supabaseUrl, supabaseKey, {
    accessToken: async () => getToken(),
    auth: {
      persistSession: false,
    },
  });
}
