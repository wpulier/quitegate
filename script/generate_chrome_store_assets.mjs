import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";

const rootDir = process.argv[2];
if (!rootDir) {
  throw new Error("Usage: generate_chrome_store_assets.mjs <repo-root>");
}

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const typeBuffer = Buffer.from(type);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])));
  return Buffer.concat([length, typeBuffer, data, crc]);
}

function writePNG(filePath, width, height, draw) {
  const pixels = Buffer.alloc(width * height * 4);
  const setPixel = (x, y, color) => {
    if (x < 0 || y < 0 || x >= width || y >= height) {
      return;
    }
    const index = (y * width + x) * 4;
    pixels[index] = color[0];
    pixels[index + 1] = color[1];
    pixels[index + 2] = color[2];
    pixels[index + 3] = color[3] ?? 255;
  };
  const fillRect = (x, y, w, h, color) => {
    for (let row = Math.max(0, y); row < Math.min(height, y + h); row += 1) {
      for (let col = Math.max(0, x); col < Math.min(width, x + w); col += 1) {
        setPixel(col, row, color);
      }
    }
  };
  const fillCircle = (cx, cy, radius, color) => {
    const radiusSquared = radius * radius;
    for (let y = Math.floor(cy - radius); y <= Math.ceil(cy + radius); y += 1) {
      for (let x = Math.floor(cx - radius); x <= Math.ceil(cx + radius); x += 1) {
        const dx = x - cx;
        const dy = y - cy;
        if (dx * dx + dy * dy <= radiusSquared) {
          setPixel(x, y, color);
        }
      }
    }
  };
  draw({ width, height, setPixel, fillRect, fillCircle });

  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y += 1) {
    const rawOffset = y * (width * 4 + 1);
    raw[rawOffset] = 0;
    pixels.copy(raw, rawOffset + 1, y * width * 4, (y + 1) * width * 4);
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw)),
    chunk("IEND", Buffer.alloc(0)),
  ]));
}

function drawIcon({ width, height, fillRect, fillCircle }) {
  const dark = [38, 38, 38, 255];
  const green = [34, 197, 94, 255];
  const white = [255, 255, 255, 255];
  const size = Math.min(width, height);
  fillRect(0, 0, width, height, [255, 255, 255, 0]);
  fillCircle(width / 2, height / 2, size * 0.46, dark);
  fillCircle(width / 2, height / 2, size * 0.32, white);
  fillCircle(width / 2, height / 2, size * 0.22, dark);
  const stroke = Math.max(2, Math.round(size * 0.11));
  fillRect(Math.round(width * 0.58), Math.round(height * 0.58), stroke, Math.round(size * 0.26), white);
  fillCircle(width * 0.72, height * 0.72, size * 0.16, green);
}

function drawScreenshot(index) {
  return ({ width, height, fillRect, fillCircle }) => {
    fillRect(0, 0, width, height, [247, 250, 252, 255]);
    fillRect(0, 0, width, 92, [255, 255, 255, 255]);
    fillRect(64, 32, 240, 28, [24, 24, 27, 255]);
    fillCircle(1180, 46, 20, [34, 197, 94, 255]);
    fillRect(80, 150, 500, 54, [24, 24, 27, 255]);
    fillRect(80, 230, 860, 24, [82, 82, 91, 255]);
    fillRect(80, 272, 740, 24, [113, 113, 122, 255]);
    for (let i = 0; i < 4; i += 1) {
      const x = 80 + i * 300;
      fillRect(x, 360, 250, 220, [255, 255, 255, 255]);
      fillRect(x + 24, 390, 150, 22, [39, 39, 42, 255]);
      fillRect(x + 24, 432, 190, 16, [113, 113, 122, 255]);
      fillRect(x + 24, 470, 120 + index * 12, 12, [34, 197, 94, 255]);
    }
    fillRect(80, 650, 1120, 58, [24, 24, 27, 255]);
    fillRect(110, 672, 400 + index * 70, 16, [255, 255, 255, 255]);
  };
}

const extensionAssetDir = path.join(rootDir, "dist/chrome-store/assets");
for (const size of [16, 32, 48, 128]) {
  writePNG(path.join(extensionAssetDir, `icon${size}.png`), size, size, drawIcon);
}

const listingDir = path.join(rootDir, "dist/chrome-store-listing");
for (let index = 1; index <= 5; index += 1) {
  writePNG(path.join(listingDir, `screenshot-${index}.png`), 1280, 800, drawScreenshot(index));
}

console.log(`Generated Chrome Store assets in ${extensionAssetDir} and ${listingDir}`);
