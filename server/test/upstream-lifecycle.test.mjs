import assert from "node:assert/strict";
import { createServer } from "node:http";
import { gzipSync } from "node:zlib";
import test from "node:test";

import { createAdonisStickerServer } from "../src/server.mjs";

// Synthetic input only. No user photos, provider credentials, or external requests.
const inputPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1eEAAAAASUVORK5CYII=";
const requestBody = JSON.stringify({
  schemaVersion: 1,
  imageMimeType: "image/png",
  imageBase64: inputPNG
});
const testOptions = { timeout: 5_000 };

for (const phase of ["before headers", "during response body"]) {
  test(`client disconnect aborts the real upstream connection ${phase}`, testOptions, async (t) => {
    const ready = deferred();
    const closed = deferred();
    const { baseURL, logs } = await harness(t, (request, response) => {
      response.once("close", closed.resolve);
      if (phase === "during response body") {
        response.writeHead(200, { "Content-Type": "application/json" });
        response.write('{"data":[');
      }
      if (phase === "before headers") ready.resolve();
    }, {
      onUpstreamChunk: phase === "during response body" ? ready.resolve : undefined
    });
    const controller = new AbortController();
    const rejected = assert.rejects(post(baseURL, controller.signal), { name: "AbortError" });
    await ready.promise;
    controller.abort();
    await rejected;
    await closed.promise;
    assert.equal(logs.some((entry) => entry.event === "sticker_extraction_succeeded"), false);
    assert.equal((await fetch(`${baseURL}/healthz`)).status, 200);
  });

  test(`upstream deadline aborts a stalled request ${phase}`, testOptions, async (t) => {
    const closed = deferred();
    let receivedBody = false;
    const { baseURL, logs } = await harness(t, (request, response) => {
      response.once("close", closed.resolve);
      if (phase === "during response body") {
        response.writeHead(200, { "Content-Type": "application/json" });
        response.write('{"data":[');
      }
    }, {
      upstreamTimeoutMilliseconds: 200,
      onUpstreamChunk: () => { receivedBody = true; }
    });
    const response = await post(baseURL);
    assert.equal(response.status, 504);
    assert.equal((await response.json()).error, "provider_timeout");
    await closed.promise;
    assert.equal(receivedBody, phase === "during response body");
    assert.equal(logs.at(-1).code, "provider_timeout");
    assert.equal((await fetch(`${baseURL}/healthz`)).status, 200);
  });
}

test("oversized declared response is rejected without waiting for its body", testOptions, async (t) => {
  const closed = deferred();
  const { baseURL } = await harness(t, (request, response) => {
    response.once("close", closed.resolve);
    response.writeHead(200, {
      "Content-Type": "application/json",
      "Content-Length": 64 * 1024 * 1024
    });
    response.flushHeaders();
  });
  const response = await post(baseURL);
  assert.equal(response.status, 502);
  assert.equal((await response.json()).error, "provider_response_too_large");
  await closed.promise;
});

test("chunked provider response is bounded before JSON parsing", testOptions, async (t) => {
  const closed = deferred();
  const { baseURL } = await harness(t, (request, response) => {
    response.once("close", closed.resolve);
    response.writeHead(200, { "Content-Type": "application/json" });
    response.flushHeaders();
    // Leave the response open: the proxy must reject on bytes, not EOF or timeout.
    response.write(Buffer.alloc(30 * 1024 * 1024, 32));
  });
  const response = await post(baseURL);
  assert.equal(response.status, 502);
  assert.equal((await response.json()).error, "provider_response_too_large");
  await closed.promise;
});

test("response limit also applies after HTTP content decompression", testOptions, async (t) => {
  const compressed = gzipSync(Buffer.alloc(30 * 1024 * 1024, 32));
  const { baseURL } = await harness(t, (request, response) => {
    response.writeHead(200, {
      "Content-Type": "application/json",
      "Content-Encoding": "gzip",
      "Content-Length": compressed.length
    });
    response.end(compressed);
  });
  const response = await post(baseURL);
  assert.equal(response.status, 502);
  assert.equal((await response.json()).error, "provider_response_too_large");
});

test("provider rejection closes the unread body and never forwards private error details", testOptions, async (t) => {
  const closed = deferred();
  const { baseURL, logs } = await harness(t, (request, response) => {
    response.once("close", closed.resolve);
    response.writeHead(429, { "Content-Type": "application/json" });
    response.write('{"error":"private-provider-detail-must-not-leak"');
  });
  const response = await post(baseURL);
  assert.equal(response.status, 502);
  const body = await response.text();
  assert.equal(JSON.parse(body).error, "provider_rejected_request");
  assert.equal(body.includes("private-provider-detail"), false);
  assert.equal(JSON.stringify(logs).includes("private-provider-detail"), false);
  assert.equal(response.headers.get("cache-control"), "no-store");
  await closed.promise;
});

test("cancelling one extraction leaves a simultaneous extraction connected", testOptions, async (t) => {
  const firstReady = deferred();
  const firstClosed = deferred();
  const secondReady = deferred();
  let secondResponse;
  const { baseURL } = await harness(t, (request, response) => {
    if (request.headers["x-client-request-id"] === "first-request") {
      response.once("close", firstClosed.resolve);
      firstReady.resolve();
    } else {
      secondResponse = response;
      secondReady.resolve();
    }
  });
  const controller = new AbortController();
  const rejected = assert.rejects(post(baseURL, controller.signal, "first-request"), {
    name: "AbortError"
  });
  await firstReady.promise;
  const second = post(baseURL, undefined, "second-request");
  await secondReady.promise;
  controller.abort();
  await rejected;
  await firstClosed.promise;
  assert.equal(secondResponse.destroyed, false);
  secondResponse.end(JSON.stringify({ data: [] }));
  // The other request reaches normal payload validation instead of being cancelled.
  const response = await second;
  assert.equal(response.status, 502);
  assert.equal((await response.json()).error, "provider_missing_image");
});

function deferred() {
  let resolve;
  const promise = new Promise((done) => { resolve = done; });
  return { promise, resolve };
}

async function post(baseURL, signal, requestID = "lifecycle-test") {
  return fetch(`${baseURL}/v1/sticker-extractions`, {
    method: "POST",
    signal,
    headers: {
      "Content-Type": "application/json",
      "X-Adonis-Request-ID": requestID
    },
    body: requestBody
  });
}

async function harness(t, handler, options = {}) {
  const { onUpstreamChunk, ...serverOptions } = options;
  const upstream = createServer((request, response) => {
    request.resume();
    handler(request, response);
  });
  await listen(upstream);
  const logs = [];
  const proxy = createAdonisStickerServer({
    ...serverOptions,
    fetchImpl: onUpstreamChunk ? async (...args) => {
      const response = await fetch(...args);
      const observed = response.body.pipeThrough(new TransformStream({
        transform(chunk, controller) {
          onUpstreamChunk();
          controller.enqueue(chunk);
        }
      }));
      return new Response(observed, { status: response.status, headers: response.headers });
    } : undefined,
    environment: {
      OPENAI_API_KEY: "local-test-key",
      OPENAI_IMAGE_EDIT_URL: `http://127.0.0.1:${upstream.address().port}/edits`
    },
    logger: {
      info: (entry) => logs.push(entry),
      error: (entry) => logs.push(entry)
    }
  });
  t.after(async () => {
    await Promise.all([close(proxy), close(upstream)]);
  });
  await listen(proxy);
  return { baseURL: `http://127.0.0.1:${proxy.address().port}`, logs };
}

function listen(server) {
  return new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
}

function close(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
    server.closeAllConnections();
  });
}
