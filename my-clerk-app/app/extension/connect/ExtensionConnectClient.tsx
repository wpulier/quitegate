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
  const [message, setMessage] = useState("Linking QuietGate for Chrome...");

  useEffect(() => {
    const sendMessage = window.chrome?.runtime?.sendMessage;
    if (!sendMessage) {
      queueMicrotask(() => {
        setStatus("failed");
        setMessage("Chrome extension messaging is unavailable. Open this page in Chrome with QuietGate installed.");
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
          setMessage(error.message || "QuietGate for Chrome did not respond.");
          return;
        }

        if (response?.ok) {
          setStatus("connected");
          setMessage("QuietGate for Chrome is connected. You can close this tab.");
          return;
        }

        setStatus("failed");
        setMessage(response?.error || "QuietGate for Chrome could not complete setup.");
      },
    );
  }, [payload]);

  return (
    <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
      <p className="text-sm font-medium text-zinc-500">Chrome extension</p>
      <p className="mt-2 text-2xl font-semibold text-zinc-950">
        {status === "connected"
          ? "Connected"
          : status === "failed"
            ? "Needs attention"
            : "Connecting"}
      </p>
      <p className="mt-3 text-sm leading-6 text-zinc-600">{message}</p>
      {status === "failed" ? (
        <button
          className="mt-5 rounded-md bg-zinc-950 px-4 py-2 text-sm font-medium text-white"
          type="button"
          onClick={() => window.location.reload()}
        >
          Try again
        </button>
      ) : null}
    </div>
  );
}
