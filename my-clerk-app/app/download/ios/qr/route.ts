import QRCode from "qrcode";
import { type NextRequest } from "next/server";

export async function GET(request: NextRequest) {
  const installURL = new URL("/download/ios", request.nextUrl.origin).toString();
  const png = await QRCode.toBuffer(installURL, {
    type: "png",
    margin: 1,
    width: 440,
    color: {
      dark: "#09090b",
      light: "#ffffff",
    },
  });

  return new Response(new Uint8Array(png), {
    headers: {
      "cache-control": "no-store",
      "content-type": "image/png",
    },
  });
}
