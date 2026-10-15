import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { deflateSync } from "node:zlib";
import test from "node:test";

import {
  TRANSPARENT_EXTRACTION_PROMPT,
  createAdonisStickerServer,
  inspectTransparentPNG
} from "../src/server.mjs";

test("proxy sends the generated source to GPT Image with a real transparent PNG contract", async () => {
  const inputPNG = makeRGBAImage(16, 16, () => [80, 30, 20, 255]);
  const outputPNG = makeRGBAImage(128, 128, (x, y) => {
    const visible = x >= 42 && x < 86 && y >= 8 && y < 120;
    return visible ? [100, 40, 20, 255] : [0, 0, 0, 0];
  });
  let upstreamRequest;
  const server = createAdonisStickerServer({
    environment: {
      OPENAI_API_KEY: "provider-test-key",
      ADONIS_PROXY_CLIENT_TOKEN: "client-test-token"
    },
    logger: silentLogger,
    fetchImpl: async (url, options) => {
      upstreamRequest = { url, options };
      return new Response(JSON.stringify({
        data: [{ b64_json: outputPNG.toString("base64") }]
      }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      });
    }
  });

  const baseURL = await listen(server);
  try {
    const response = await fetch(`${baseURL}/v1/sticker-extractions`, {
      method: "POST",
      headers: {
        Authorization: "Bearer client-test-token",
        "Content-Type": "application/json",
        "X-Adonis-Request-ID": "request-123"
      },
      body: JSON.stringify({
        schemaVersion: 1,
        imageMimeType: "image/png",
        imageBase64: inputPNG.toString("base64")
      })
    });

    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-type"), "image/png");
    assert.deepEqual(Buffer.from(await response.arrayBuffer()), outputPNG);
    assert.equal(upstreamRequest.url, "https://api.openai.com/v1/images/edits");
    assert.equal(upstreamRequest.options.headers.Authorization, "Bearer provider-test-key");
    const form = upstreamRequest.options.body;
    assert.equal(form.get("model"), "gpt-image-2");
    assert.equal(form.get("background"), "transparent");
    assert.equal(form.get("output_format"), "png");
    assert.equal(form.get("quality"), "high");
    assert.equal(form.get("prompt"), TRANSPARENT_EXTRACTION_PROMPT);
    assert.equal((await form.get("image").arrayBuffer()).byteLength, inputPNG.length);
  } finally {
    await close(server);
  }
});

test("proxy rejects an opaque checkerboard even when the provider calls it PNG", async () => {
  const opaquePNG = makeRGBAImage(64, 64, (x, y) => {
    const value = (Math.floor(x / 8) + Math.floor(y / 8)) % 2 === 0 ? 255 : 190;
    return [value, value, value, 255];
  });
  const server = createAdonisStickerServer({
    environment: { OPENAI_API_KEY: "provider-test-key" },
    logger: silentLogger,
    fetchImpl: async () => new Response(JSON.stringify({
      data: [{ b64_json: opaquePNG.toString("base64") }]
    }), { status: 200 })
  });

  const baseURL = await listen(server);
  try {
    const response = await fetch(`${baseURL}/v1/sticker-extractions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        schemaVersion: 1,
        imageMimeType: "image/png",
        imageBase64: opaquePNG.toString("base64")
      })
    });
    assert.equal(response.status, 502);
    assert.equal((await response.json()).error, "provider_output_not_transparent");
  } finally {
    await close(server);
  }
});

test("PNG inspection requires transparent corners and a visible subject", () => {
  const valid = makeRGBAImage(128, 128, (x, y) => {
    const visible = x >= 38 && x < 90 && y >= 10 && y < 118;
    return visible ? [30, 60, 90, 255] : [0, 0, 0, 0];
  });
  const empty = makeRGBAImage(128, 128, () => [0, 0, 0, 0]);

  assert.equal(inspectTransparentPNG(valid).isUsableTransparentSubject, true);
  assert.equal(inspectTransparentPNG(empty).isUsableTransparentSubject, false);
});

test("PNG inspection rejects a transparent image split into many independent pieces", () => {
  const inspection = inspectTransparentPNG(fragmentedPNG());
  assert.equal(inspection.isUsableTransparentSubject, false);
  assert.equal(inspection.largestVisibleComponentRatio, 1 / 32);
});

test("dominant subject boundary allows detached accessories through twenty percent", () => {
  const image = (mainWidth) => makeRGBAImage(128, 128, (x, y) => {
    const main = x >= 40 && x < 40 + mainWidth && y >= 20 && y < 60;
    const accessory = x >= 80 && x < 96 && y >= 80 && y < 100;
    return main || accessory ? [70, 90, 30, 255] : [0, 0, 0, 0];
  });
  const boundary = inspectTransparentPNG(image(32));
  assert.equal(boundary.largestVisibleComponentRatio, 0.80);
  assert.equal(boundary.isUsableTransparentSubject, true);
  assert.equal(inspectTransparentPNG(image(31)).isUsableTransparentSubject, false);
});

test("diagonal contact does not join otherwise separated subject blocks", () => {
  const png = makeRGBAImage(128, 128, (x, y) => {
    const visible = [0, 1, 2].some((n) => x >= 36 + 20 * n && x < 56 + 20 * n
      && y >= 20 + 20 * n && y < 40 + 20 * n);
    return visible ? [50, 60, 70, 255] : [0, 0, 0, 0];
  });
  const inspection = inspectTransparentPNG(png);
  assert.equal(inspection.largestVisibleComponentRatio, 1 / 3);
  assert.equal(inspection.isUsableTransparentSubject, false);
});

test("end of one image row is not connected to the beginning of the next", () => {
  const png = makeRGBAImage(128, 128, (x, y) => {
    const right = x >= 116 && y >= 47 && y < 65;
    const left = x < 12 && y >= 65 && y < 83;
    return right || left ? [50, 60, 70, 255] : [0, 0, 0, 0];
  });
  const inspection = inspectTransparentPNG(png);
  assert.equal(inspection.largestVisibleComponentRatio, 0.5);
  assert.equal(inspection.isUsableTransparentSubject, false);
});

test("only alpha above sixteen connects the visible subject", () => {
  const image = (bridgeAlpha) => makeRGBAImage(128, 128, (x, y) => {
    const block = y >= 40 && y < 80 && ((x >= 36 && x < 56) || (x >= 72 && x < 92));
    const bridge = y === 60 && x >= 56 && x < 72;
    return block ? [50, 60, 70, 255] : bridge ? [50, 60, 70, bridgeAlpha] : [0, 0, 0, 0];
  });
  assert.equal(inspectTransparentPNG(image(16)).isUsableTransparentSubject, false);
  assert.equal(inspectTransparentPNG(image(17)).largestVisibleComponentRatio, 1);
  assert.equal(inspectTransparentPNG(image(17)).isUsableTransparentSubject, true);
});

test("grayscale plus alpha PNG uses the same connected subject rule", () => {
  const fragmented = makeRGBAImage(128, 128, (x, y) => {
    const visible = x >= 40 && x < 88 && y >= 16 && y < 112
      && (x - 40) % 12 < 6 && (y - 16) % 12 < 6;
    return [90, visible ? 255 : 0];
  }, 4);
  const whole = makeRGBAImage(128, 128, (x, y) => [90,
    x >= 40 && x < 88 && y >= 16 && y < 112 ? 255 : 0
  ], 4);
  assert.equal(inspectTransparentPNG(fragmented).isUsableTransparentSubject, false);
  assert.equal(inspectTransparentPNG(whole).isUsableTransparentSubject, true);
});

test("proxy rejects fragmented output before delivering image bytes", async () => {
  await withProviderImage(fragmentedPNG(), async (response) => {
    assert.equal(response.status, 502);
    assert.equal((await response.json()).error, "provider_output_fragmented");
  });
});

test("proxy preserves all bytes including a detached accessory after inspection", async () => {
  const png = makeRGBAImage(128, 128, (x, y) => {
    const main = x >= 40 && x < 80 && y >= 10 && y < 118;
    const accessory = x >= 90 && x < 100 && y >= 70 && y < 90;
    return main ? [50, 60, 70, 255] : accessory ? [10, 200, 100, 255] : [0, 0, 0, 0];
  });
  const original = Buffer.from(png);
  assert.equal(inspectTransparentPNG(png).isUsableTransparentSubject, true);
  assert.deepEqual(png, original);
  await withProviderImage(png, async (response) => {
    assert.equal(response.status, 200);
    assert.deepEqual(Buffer.from(await response.arrayBuffer()), original);
  });
});

test("existing sticker assets keep their structural eligibility without changing their bytes", () => {
  for (let number = 1; number <= 4; number += 1) {
    const id = `sample-0${number}`;
    const paths = [
      `../../ReBloom/Resources/Samples/${id}-sticker.png`,
      `../../assets/prototypes/digital-figurine-sticker/ai-source-${id}-sticker-v1.png`
    ];
    if (number <= 3) paths.push(`../../ReBloom/Resources/Samples/${id}-ai-sticker.png`);
    for (const path of paths) {
      const png = readFileSync(new URL(path, import.meta.url));
      const original = Buffer.from(png);
      assert.equal(inspectTransparentPNG(png).isUsableTransparentSubject, true, path);
      assert.deepEqual(png, original, path);
    }
  }
  // This is only the structural gate. sample-04's C-grade product routing stays separate.
});

function fragmentedPNG() {
  return makeRGBAImage(128, 128, (x, y) => {
    const visible = x >= 40 && x < 88 && y >= 16 && y < 112
      && (x - 40) % 12 < 6 && (y - 16) % 12 < 6;
    return visible ? [50, 80, 110, 255] : [0, 0, 0, 0];
  });
}

async function withProviderImage(png, inspectResponse) {
  const server = createAdonisStickerServer({
    environment: { OPENAI_API_KEY: "provider-test-key" },
    logger: silentLogger,
    fetchImpl: async () => new Response(JSON.stringify({
      data: [{ b64_json: png.toString("base64") }]
    }), { status: 200 })
  });
  const baseURL = await listen(server);
  try {
    const response = await fetch(`${baseURL}/v1/sticker-extractions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ schemaVersion: 1, imageMimeType: "image/png",
        imageBase64: makeRGBAImage(16, 16, () => [50, 60, 70, 255]).toString("base64") })
    });
    await inspectResponse(response);
  } finally {
    await close(server);
  }
}

const silentLogger = { info() {}, error() {} };

async function listen(server) {
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  return `http://127.0.0.1:${address.port}`;
}

async function close(server) {
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

function makeRGBAImage(width, height, pixel, colorType = 6) {
  const stride = colorType === 6 ? 4 : 2;
  const scanlines = Buffer.alloc((width * stride + 1) * height);
  for (let y = 0; y < height; y += 1) {
    const rowOffset = y * (width * stride + 1);
    scanlines[rowOffset] = 0;
    for (let x = 0; x < width; x += 1) {
      const channels = pixel(x, y);
      const offset = rowOffset + 1 + x * stride;
      for (let channel = 0; channel < stride; channel += 1) {
        scanlines[offset + channel] = channels[channel];
      }
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = colorType;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(scanlines)),
    chunk("IEND", Buffer.alloc(0))
  ]);
}

function chunk(type, data) {
  const result = Buffer.alloc(12 + data.length);
  result.writeUInt32BE(data.length, 0);
  result.write(type, 4, 4, "ascii");
  data.copy(result, 8);
  let crc = 0xffffffff;
  for (const byte of result.subarray(4, 8 + data.length)) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
    }
  }
  result.writeUInt32BE((crc ^ 0xffffffff) >>> 0, 8 + data.length);
  return result;
}
