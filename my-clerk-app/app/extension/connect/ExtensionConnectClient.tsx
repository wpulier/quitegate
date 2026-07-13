"use client";

import { useEffect, useState } from "react";

type ConnectPayload = {
  extensionId: string;
  installationId: string;
  nonce: string;
  extensionVersion: string | null;
  code: string;
  expiresAt: string;
};

type RuntimeResponse = {
  ok?: boolean;
  error?: string;
};

declare global {
  interface Window {
    chrome?: {
      runtime?: {
        sendMessage?: (
          extensionId: string,
          message: Record<string, unknown>,
          callback?: (response?: RuntimeResponse) => void,
        ) => void;
        lastError?: {
          message?: string;
        };
      };
    };
  }
}

export function ExtensionConnectClient({ payload }: { payload: ConnectPayload }) {
  const [status, setStatus] = useState<"pending" | "connected" | "failed">("pending");
  const [message, setMessage] = useState("Securely linking this Chrome profile...");

  useEffect(() => {
    const sendMessage = window.chrome?.runtime?.sendMessage;
    if (!sendMessage) {
      queueMicrotask(() => {
        setStatus("failed");
        setMessage("Chrome extension messaging is unavailable. Open this page in Chrome with Tortoise installed.");
      });
      return;
    }

    sendMessage(
      payload.extensionId,
      {
        type: "quietgate.linkExtension",
        extensionId: payload.extensionId,
        installationId: payload.installationId,
        nonce: payload.nonce,
        extensionVersion: payload.extensionVersion,
        code: payload.code,
      },
      (response) => {
        const error = window.chrome?.runtime?.lastError;
        if (error) {
          setStatus("failed");
          setMessage(error.message || "Tortoise for Chrome did not respond.");
          return;
        }

        if (response?.ok) {
          setStatus("connected");
          setMessage("QuietGate is connected. Your protection policy is syncing now; you can close this tab.");
          return;
        }

        setStatus("failed");
        setMessage(response?.error || "Tortoise for Chrome could not complete setup.");
      },
    );
  }, [payload]);

  return (
    <section
      aria-live="polite"
      className="w-full rounded-2xl border border-zinc-200 bg-white p-6 shadow-[0_18px_54px_rgba(24,24,27,0.09)] sm:p-8"
    >
      <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[#3e63dd]">
        Step 2 of 2
      </p>
      <h2 className="mt-3 text-3xl font-semibold tracking-tight text-zinc-950">
        {status === "connected"
          ? "QuietGate is connected."
          : status === "failed"
            ? "Connection needs attention."
            : "Connecting QuietGate..."}
      </h2>
      <p className="mt-4 text-sm leading-6 text-zinc-600">{message}</p>
      {status === "failed" ? (
        <button
          className="mt-7 min-h-12 w-full rounded-lg bg-[#3e63dd] px-5 text-sm font-semibold text-white transition hover:bg-[#3456c7] focus:outline-none focus:ring-2 focus:ring-[#3e63dd] focus:ring-offset-2"
          type="button"
          onClick={() => window.location.reload()}
        >
          Try again
        </button>
      ) : null}
    </section>
  );
}
