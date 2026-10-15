import { createServer } from "node:http";
import { randomUUID, timingSafeEqual } from "node:crypto";
import { inflateSync } from "node:zlib";

const MAX_REQUEST_BYTES = 18 * 1024 * 1024;
const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
const MAX_OUTPUT_BYTES = 20 * 1024 * 1024;
// Base64 expansion plus a bounded allowance for the provider's JSON metadata.
const MAX_PROVIDER_RESPONSE_BYTES = Math.ceil(MAX_OUTPUT_BYTES / 3) * 4 + 1024 * 1024;
const UPSTREAM_TIMEOUT_MILLISECONDS = 130_000;
const OPENAI_IMAGE_EDIT_URL = "https://api.openai.com/v1/images/edits";
const DEFAULT_MODEL = "gpt-image-2";

export const TRANSPARENT_EXTRACTION_PROMPT = [
  "Remove only the background from this already-generated sticker source.",
  "Return exactly one complete subject on a truly transparent canvas.",
  "Preserve every visible person, garment, shoe, bag, accessory, hair strand, pose,",
  "facial feature, color, texture, logo, and object exactly as supplied.",
  "Do not redraw, restyle, beautify, repair, simplify, crop, erase, add, or replace anything.",
  "Keep detached accessories and gaps between limbs. Leave transparent padding on all sides.",
  "Do not add a white background, checkerboard pattern, shadow, border, text, or extra object."
].join(" ");

export function createAdonisStickerServer(options = {}) {
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  const logger = options.logger ?? console;
  const environment = options.environment ?? process.env;
  const openAIKey = environment.OPENAI_API_KEY;
  const clientToken = normalizedString(environment.ADONIS_PROXY_CLIENT_TOKEN);
  const model = normalizedString(environment.OPENAI_IMAGE_MODEL) ?? DEFAULT_MODEL;
  const upstreamURL = normalizedString(environment.OPENAI_IMAGE_EDIT_URL)
    ?? OPENAI_IMAGE_EDIT_URL;
  const upstreamTimeoutMilliseconds = options.upstreamTimeoutMilliseconds
    ?? UPSTREAM_TIMEOUT_MILLISECONDS;
  if (!Number.isInteger(upstreamTimeoutMilliseconds) || upstreamTimeoutMilliseconds < 1
    || upstreamTimeoutMilliseconds > UPSTREAM_TIMEOUT_MILLISECONDS) {
    throw new RangeError("invalid_upstream_timeout");
  }

  return createServer(async (request, response) => {
    const startedAt = performance.now();
    const requestID = safeRequestID(request.headers["x-adonis-request-id"]);
    const controller = new AbortController();
    const onResponseClose = () => {
      if (!response.writableEnded) {
        controller.abort(new HTTPError(499, "client_disconnected"));
      }
    };
    response.once("close", onResponseClose);
    try {
      if (request.method === "GET" && request.url === "/healthz") {
        sendJSON(response, 200, {
          ok: true,
          providerConfigured: Boolean(openAIKey)
        }, requestID);
        return;
      }
      if (request.method !== "POST" || request.url !== "/v1/sticker-extractions") {
        throw new HTTPError(404, "not_found");
      }
      requireClientAuthorization(request, clientToken);
      if (!openAIKey) {
        throw new HTTPError(503, "provider_not_configured");
      }

      const body = await readJSONBody(request);
      controller.signal.throwIfAborted();
      const input = decodeInputImage(body);
      const transparentPNG = await requestTransparentPNG({
        fetchImpl,
        openAIKey,
        model,
        upstreamURL,
        input,
        requestID,
        controller,
        timeoutMilliseconds: upstreamTimeoutMilliseconds
      });
      controller.signal.throwIfAborted();
      const inspection = inspectTransparentPNG(transparentPNG);
      if (!inspection.isUsableTransparentSubject) {
        if (inspection.largestVisibleComponentRatio > 0
          && inspection.largestVisibleComponentRatio < 0.80) {
          throw new HTTPError(502, "provider_output_fragmented");
        }
        throw new HTTPError(502, "provider_output_not_transparent");
      }

      response.writeHead(200, {
        "Cache-Control": "no-store",
        "Content-Length": transparentPNG.length,
        "Content-Type": "image/png",
        "X-Adonis-Provider": model,
        "X-Adonis-Request-ID": requestID,
        "X-Content-Type-Options": "nosniff"
      });
      response.end(transparentPNG);
      logger.info?.({
        event: "sticker_extraction_succeeded",
        requestID,
        durationMilliseconds: Math.round(performance.now() - startedAt)
      });
    } catch (caught) {
      const error = controller.signal.aborted && controller.signal.reason instanceof HTTPError
        ? controller.signal.reason : caught;
      const statusCode = error instanceof HTTPError ? error.statusCode : 500;
      const code = error instanceof HTTPError ? error.code : "internal_error";
      sendJSON(response, statusCode, { error: code, requestID }, requestID);
      logger.error?.({
        event: "sticker_extraction_failed",
        requestID,
        statusCode,
        code,
        durationMilliseconds: Math.round(performance.now() - startedAt)
      });
    } finally {
      response.off("close", onResponseClose);
    }
  });
}

async function requestTransparentPNG({
  fetchImpl,
  openAIKey,
  model,
  upstreamURL,
  input,
  requestID,
  controller,
  timeoutMilliseconds
}) {
  const form = new FormData();
  form.append("model", model);
  form.append("image", new Blob([input.bytes], { type: input.mimeType }), input.filename);
  form.append("prompt", TRANSPARENT_EXTRACTION_PROMPT);
  form.append("background", "transparent");
  form.append("output_format", "png");
  form.append("quality", "high");
  form.append("size", "auto");

  let upstreamResponse;
  const timeout = setTimeout(() => {
    controller.abort(new HTTPError(504, "provider_timeout"));
  }, timeoutMilliseconds);
  timeout.unref();
  try {
    controller.signal.throwIfAborted();
    try {
      upstreamResponse = await fetchImpl(upstreamURL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openAIKey}`,
          "X-Client-Request-Id": requestID
        },
        body: form,
        signal: controller.signal
      });
    } catch {
      controller.signal.throwIfAborted();
      throw new HTTPError(502, "provider_unreachable");
    }
    if (!upstreamResponse.ok) {
      throw new HTTPError(502, "provider_rejected_request");
    }

    let payload;
    try {
      payload = await readProviderJSON(upstreamResponse);
    } catch (error) {
      controller.signal.throwIfAborted();
      if (error instanceof HTTPError) throw error;
      throw new HTTPError(502, "provider_invalid_response");
    }
    const encoded = payload?.data?.[0]?.b64_json;
    if (typeof encoded !== "string" || encoded.length === 0) {
      throw new HTTPError(502, "provider_missing_image");
    }
    const bytes = Buffer.from(encoded, "base64");
    if (bytes.length === 0 || bytes.length > MAX_OUTPUT_BYTES) {
      throw new HTTPError(502, "provider_invalid_image_size");
    }
    return bytes;
  } catch (error) {
    controller.abort(error);
    // Rejected responses must not retain an unread connection or continue downloading.
    await upstreamResponse?.body?.cancel().catch(() => {});
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

async function readProviderJSON(response) {
  const declaredLength = Number(response.headers.get("content-length"));
  if (declaredLength > MAX_PROVIDER_RESPONSE_BYTES) {
    throw new HTTPError(502, "provider_response_too_large");
  }
  if (!response.body) throw new HTTPError(502, "provider_invalid_response");
  const reader = response.body.getReader();
  const chunks = [];
  let byteCount = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      byteCount += value.byteLength;
      if (byteCount > MAX_PROVIDER_RESPONSE_BYTES) {
        throw new HTTPError(502, "provider_response_too_large");
      }
      chunks.push(Buffer.from(value));
    }
  } finally {
    reader.releaseLock();
  }
  return JSON.parse(Buffer.concat(chunks, byteCount).toString("utf8"));
}

async function readJSONBody(request) {
  const contentType = request.headers["content-type"]?.toLowerCase() ?? "";
  if (!contentType.startsWith("application/json")) {
    throw new HTTPError(415, "content_type_must_be_json");
  }
  const chunks = [];
  let byteCount = 0;
  for await (const chunk of request) {
    byteCount += chunk.length;
    if (byteCount > MAX_REQUEST_BYTES) {
      throw new HTTPError(413, "request_too_large");
    }
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new HTTPError(400, "invalid_json");
  }
}

function decodeInputImage(body) {
  if (body?.schemaVersion !== 1) {
    throw new HTTPError(400, "unsupported_schema");
  }
  if (!["image/png", "image/jpeg"].includes(body.imageMimeType)) {
    throw new HTTPError(400, "unsupported_image_type");
  }
  if (typeof body.imageBase64 !== "string" || body.imageBase64.length === 0) {
    throw new HTTPError(400, "missing_image");
  }
  const bytes = Buffer.from(body.imageBase64, "base64");
  if (bytes.length === 0 || bytes.length > MAX_IMAGE_BYTES) {
    throw new HTTPError(413, "image_too_large");
  }
  const isPNG = bytes.subarray(0, 8).equals(PNG_SIGNATURE);
  const isJPEG = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[bytes.length - 2] === 0xff
    && bytes[bytes.length - 1] === 0xd9;
  if ((body.imageMimeType === "image/png" && !isPNG)
    || (body.imageMimeType === "image/jpeg" && !isJPEG)) {
    throw new HTTPError(400, "image_signature_mismatch");
  }
  return {
    bytes,
    mimeType: body.imageMimeType,
    filename: body.imageMimeType === "image/png" ? "sticker-source.png" : "sticker-source.jpg"
  };
}

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

export function inspectTransparentPNG(bytes) {
  try {
    if (!Buffer.isBuffer(bytes) || !bytes.subarray(0, 8).equals(PNG_SIGNATURE)) {
      return unusableInspection();
    }
    let offset = 8;
    let header;
    const imageData = [];
    while (offset + 12 <= bytes.length) {
      const length = bytes.readUInt32BE(offset);
      const type = bytes.toString("ascii", offset + 4, offset + 8);
      const dataStart = offset + 8;
      const dataEnd = dataStart + length;
      if (dataEnd + 4 > bytes.length) return unusableInspection();
      if (type === "IHDR") {
        header = {
          width: bytes.readUInt32BE(dataStart),
          height: bytes.readUInt32BE(dataStart + 4),
          bitDepth: bytes[dataStart + 8],
          colorType: bytes[dataStart + 9],
          interlace: bytes[dataStart + 12]
        };
      } else if (type === "IDAT") {
        imageData.push(bytes.subarray(dataStart, dataEnd));
      }
      offset = dataEnd + 4;
      if (type === "IEND") break;
    }
    if (!header || header.bitDepth !== 8 || header.interlace !== 0
      || ![4, 6].includes(header.colorType)
      || header.width < 1 || header.height < 1
      || header.width > 4096 || header.height > 4096
      || imageData.length === 0) {
      return unusableInspection();
    }
    const bytesPerPixel = header.colorType === 6 ? 4 : 2;
    const rowBytes = header.width * bytesPerPixel;
    const expectedLength = (rowBytes + 1) * header.height;
    const inflated = inflateSync(Buffer.concat(imageData), { maxOutputLength: expectedLength });
    if (inflated.length !== expectedLength) return unusableInspection();

    const decoded = Buffer.alloc(rowBytes * header.height);
    for (let row = 0; row < header.height; row += 1) {
      const sourceOffset = row * (rowBytes + 1);
      const destinationOffset = row * rowBytes;
      const filter = inflated[sourceOffset];
      for (let column = 0; column < rowBytes; column += 1) {
        const raw = inflated[sourceOffset + 1 + column];
        const left = column >= bytesPerPixel ? decoded[destinationOffset + column - bytesPerPixel] : 0;
        const up = row > 0 ? decoded[destinationOffset - rowBytes + column] : 0;
        const upperLeft = row > 0 && column >= bytesPerPixel
          ? decoded[destinationOffset - rowBytes + column - bytesPerPixel] : 0;
        decoded[destinationOffset + column] = unfilterByte(filter, raw, left, up, upperLeft);
      }
    }

    const alphaOffset = header.colorType === 6 ? 3 : 1;
    const pixelCount = header.width * header.height;
    let transparent = 0;
    let visible = 0;
    let cornerPixels = 0;
    let transparentCorners = 0;
    const cornerLength = Math.min(32, header.width, header.height);
    for (let y = 0; y < header.height; y += 1) {
      for (let x = 0; x < header.width; x += 1) {
        const alpha = decoded[(y * header.width + x) * bytesPerPixel + alphaOffset];
        if (alpha < 8) transparent += 1;
        if (alpha > 16) visible += 1;
        const isCorner = (x < cornerLength || x >= header.width - cornerLength)
          && (y < cornerLength || y >= header.height - cornerLength);
        if (isCorner) {
          cornerPixels += 1;
          if (alpha < 8) transparentCorners += 1;
        }
      }
    }
    const transparentRatio = transparent / pixelCount;
    const foregroundCoverage = visible / pixelCount;
    const cornerTransparentRatio = transparentCorners / Math.max(cornerPixels, 1);
    const hasTransparentSubject = transparentRatio >= 0.08
      && foregroundCoverage >= 0.025 && cornerTransparentRatio >= 0.75;
    const largestVisibleComponentRatio = hasTransparentSubject
      ? largestVisibleComponentSize(decoded, header.width, header.height,
        bytesPerPixel, alphaOffset, visible) / visible
      : 0;
    return {
      transparentRatio,
      foregroundCoverage,
      cornerTransparentRatio,
      largestVisibleComponentRatio,
      isUsableTransparentSubject: hasTransparentSubject && largestVisibleComponentRatio >= 0.80
    };
  } catch {
    return unusableInspection();
  }
}

function largestVisibleComponentSize(decoded, width, height, stride, alphaOffset, visibleCount) {
  // Mark only the private decoded inspection buffer. The PNG returned to the client is untouched.
  // A typed queue bounds extra storage to four bytes per visible pixel, at most 64 MiB (4096²).
  const queue = new Uint32Array(visibleCount);
  let largest = 0;
  let tail = 0;
  function enqueue(index) {
    const offset = index * stride + alphaOffset;
    if (decoded[offset] <= 16) return;
    decoded[offset] = 0;
    queue[tail++] = index;
  }
  for (let start = 0; start < width * height; start += 1) {
    if (decoded[start * stride + alphaOffset] <= 16) continue;
    tail = 0;
    enqueue(start);
    let head = 0;
    while (head < tail) {
      const index = queue[head++];
      const x = index % width;
      if (x > 0) enqueue(index - 1);
      if (x + 1 < width) enqueue(index + 1);
      if (index >= width) enqueue(index - width);
      if (index + width < width * height) enqueue(index + width);
    }
    largest = Math.max(largest, tail);
  }
  return largest;
}

function unfilterByte(filter, raw, left, up, upperLeft) {
  switch (filter) {
    case 0: return raw;
    case 1: return (raw + left) & 0xff;
    case 2: return (raw + up) & 0xff;
    case 3: return (raw + Math.floor((left + up) / 2)) & 0xff;
    case 4: return (raw + paeth(left, up, upperLeft)) & 0xff;
    default: throw new Error("unsupported_png_filter");
  }
}

function paeth(left, up, upperLeft) {
  const estimate = left + up - upperLeft;
  const leftDistance = Math.abs(estimate - left);
  const upDistance = Math.abs(estimate - up);
  const upperLeftDistance = Math.abs(estimate - upperLeft);
  if (leftDistance <= upDistance && leftDistance <= upperLeftDistance) return left;
  if (upDistance <= upperLeftDistance) return up;
  return upperLeft;
}

function unusableInspection() {
  return {
    transparentRatio: 0,
    foregroundCoverage: 0,
    cornerTransparentRatio: 0,
    largestVisibleComponentRatio: 0,
    isUsableTransparentSubject: false
  };
}

function requireClientAuthorization(request, expectedToken) {
  if (!expectedToken) return;
  const authorization = request.headers.authorization ?? "";
  const provided = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  const expectedBytes = Buffer.from(expectedToken);
  const providedBytes = Buffer.from(provided);
  if (expectedBytes.length !== providedBytes.length
    || !timingSafeEqual(expectedBytes, providedBytes)) {
    throw new HTTPError(401, "unauthorized");
  }
}

function sendJSON(response, statusCode, value, requestID) {
  if (response.headersSent || response.destroyed) return;
  const body = Buffer.from(JSON.stringify(value));
  response.writeHead(statusCode, {
    "Cache-Control": "no-store",
    "Content-Length": body.length,
    "Content-Type": "application/json; charset=utf-8",
    "X-Adonis-Request-ID": requestID,
    "X-Content-Type-Options": "nosniff"
  });
  response.end(body);
}

function safeRequestID(value) {
  const candidate = Array.isArray(value) ? value[0] : value;
  return typeof candidate === "string" && /^[A-Za-z0-9-]{1,64}$/.test(candidate)
    ? candidate : randomUUID();
}

function normalizedString(value) {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

class HTTPError extends Error {
  constructor(statusCode, code) {
    super(code);
    this.statusCode = statusCode;
    this.code = code;
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT ?? 8787);
  const host = normalizedString(process.env.HOST) ?? "127.0.0.1";
  const server = createAdonisStickerServer();
  server.listen(port, host, () => {
    console.info(`Adonis sticker proxy listening on http://${host}:${port}`);
  });
}
