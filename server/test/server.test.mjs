import assert from "node:assert/strict";
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

const silentLogger = { info() {}, error() {} };

async function listen(server) {
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  return `http://127.0.0.1:${address.port}`;
}

async function close(server) {
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

function makeRGBAImage(width, height, pixel) {
  const scanlines = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y += 1) {
    const rowOffset = y * (width * 4 + 1);
    scanlines[rowOffset] = 0;
    for (let x = 0; x < width; x += 1) {
      const [red, green, blue, alpha] = pixel(x, y);
      const offset = rowOffset + 1 + x * 4;
      scanlines[offset] = red;
      scanlines[offset + 1] = green;
      scanlines[offset + 2] = blue;
      scanlines[offset + 3] = alpha;
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 6;
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
  return result;
}
