#!/usr/bin/env ruby

require "digest"
require "json"
require "zlib"

ROOT = File.expand_path("..", __dir__)
MANIFEST_PATH = File.join(
  ROOT,
  "assets/prototypes/digital-figurine-sticker/ai-two-stage-experiment.json"
)

def paeth_predictor(left, up, upper_left)
  estimate = left + up - upper_left
  left_distance = (estimate - left).abs
  up_distance = (estimate - up).abs
  upper_left_distance = (estimate - upper_left).abs

  return left if left_distance <= up_distance && left_distance <= upper_left_distance
  return up if up_distance <= upper_left_distance

  upper_left
end

def alpha_statistics(
  compressed_pixels:,
  width:,
  height:,
  bit_depth:,
  color_type:,
  interlace:,
  contract:
)
  raise "alpha statistics require 8-bit non-interlaced PNG" unless bit_depth == 8 && interlace.zero?

  channels = {4 => 2, 6 => 4}.fetch(color_type) do
    raise "alpha statistics require grayscale-alpha or RGBA PNG"
  end
  scanline_length = width * channels
  inflated = Zlib::Inflate.inflate(compressed_pixels)
  expected_length = height * (scanline_length + 1)
  raise "unexpected inflated PNG length" unless inflated.bytesize == expected_length

  transparent = 0
  opaque = 0
  minimum_alpha = 255
  maximum_alpha = 0
  previous = Array.new(scanline_length, 0)
  offset = 0

  height.times do
    filter = inflated.getbyte(offset)
    offset += 1
    encoded = inflated.byteslice(offset, scanline_length).bytes
    offset += scanline_length
    decoded = Array.new(scanline_length, 0)

    scanline_length.times do |index|
      left = index >= channels ? decoded[index - channels] : 0
      up = previous[index]
      upper_left = index >= channels ? previous[index - channels] : 0
      predictor =
        case filter
        when 0 then 0
        when 1 then left
        when 2 then up
        when 3 then (left + up) / 2
        when 4 then paeth_predictor(left, up, upper_left)
        else raise "unsupported PNG filter #{filter}"
        end
      decoded[index] = (encoded[index] + predictor) & 0xff
    end

    (channels - 1).step(scanline_length - 1, channels) do |index|
      alpha = decoded[index]
      transparent += 1 if alpha <= contract.fetch("transparentAlphaMaximum")
      opaque += 1 if alpha >= contract.fetch("opaqueAlphaMinimum")
      minimum_alpha = [minimum_alpha, alpha].min
      maximum_alpha = [maximum_alpha, alpha].max
    end
    previous = decoded
  end

  pixel_count = width * height
  {
    "transparentRatio" => transparent.fdiv(pixel_count),
    "opaqueRatio" => opaque.fdiv(pixel_count),
    "minimumAlpha" => minimum_alpha,
    "maximumAlpha" => maximum_alpha,
  }
end

def png_metadata(path, alpha_contract: nil)
  bytes = File.binread(path)
  raise "not a PNG" unless bytes.start_with?("\x89PNG\r\n\x1A\n".b)

  offset = 8
  width = nil
  height = nil
  bit_depth = nil
  color_type = nil
  interlace = nil
  has_transparency_chunk = false
  compressed_pixels = +"".b

  while offset + 12 <= bytes.bytesize
    length = bytes.byteslice(offset, 4).unpack1("N")
    type = bytes.byteslice(offset + 4, 4)
    payload = bytes.byteslice(offset + 8, length)
    raise "truncated PNG chunk" unless payload&.bytesize == length

    if type == "IHDR"
      width, height, bit_depth, color_type, _compression, _filter, interlace =
        payload.unpack("NNC5")
    elsif type == "IDAT"
      compressed_pixels << payload
    elsif type == "tRNS"
      has_transparency_chunk = true
    elsif type == "IEND"
      break
    end

    offset += length + 12
  end

  raise "missing PNG header" unless width && height && color_type

  metadata = {
    "width" => width,
    "height" => height,
    "hasAlpha" => [4, 6].include?(color_type) || has_transparency_chunk,
  }
  if alpha_contract
    metadata["alphaStatistics"] = alpha_statistics(
      compressed_pixels: compressed_pixels,
      width: width,
      height: height,
      bit_depth: bit_depth,
      color_type: color_type,
      interlace: interlace,
      contract: alpha_contract
    )
  end
  metadata
end

def verify_asset(asset, role, sample_id, errors, alpha_contract: nil)
  path = File.join(ROOT, asset.fetch("path"))
  unless File.file?(path)
    errors << "#{sample_id} #{role}: missing #{asset.fetch('path')}"
    return nil
  end

  actual_hash = Digest::SHA256.file(path).hexdigest
  if actual_hash != asset.fetch("sha256")
    errors << "#{sample_id} #{role}: SHA-256 #{actual_hash}"
  end

  metadata = png_metadata(path, alpha_contract: alpha_contract)
  %w[width height hasAlpha].each do |field|
    next if metadata.fetch(field) == asset.fetch(field)

    errors <<
      "#{sample_id} #{role}: #{field}=#{metadata.fetch(field).inspect}, " \
      "expected #{asset.fetch(field).inspect}"
  end
  metadata
end

manifest = JSON.parse(File.read(MANIFEST_PATH))
errors = []

unless manifest.fetch("schemaVersion") == 1
  errors << "unsupported schemaVersion"
end

samples = manifest.fetch("samples")
alpha_contract = manifest.fetch("matting").fetch("alphaContract")
unless samples.map { |sample| sample.fetch("id") }.uniq.length == samples.length
  errors << "sample ids must be unique"
end

samples.each do |sample|
  sample_id = sample.fetch("id")
  verify_asset(sample.fetch("original"), "original", sample_id, errors)
  verify_asset(sample.fetch("aiSource"), "aiSource", sample_id, errors)
  sticker_metadata = verify_asset(
    sample.fetch("sticker"),
    "sticker",
    sample_id,
    errors,
    alpha_contract: alpha_contract
  )

  if sample.fetch("aiSource").fetch("hasAlpha")
    errors << "#{sample_id}: AI source must be opaque"
  end
  unless sample.fetch("sticker").fetch("hasAlpha")
    errors << "#{sample_id}: sticker must have alpha"
  end

  if sticker_metadata
    alpha = sticker_metadata.fetch("alphaStatistics")
    if alpha.fetch("transparentRatio") < alpha_contract.fetch("minimumTransparentPixelRatio")
      errors << "#{sample_id}: transparent pixel ratio is too low"
    end
    if alpha.fetch("opaqueRatio") < alpha_contract.fetch("minimumOpaquePixelRatio")
      errors << "#{sample_id}: opaque pixel ratio is too low"
    end
    puts format(
      "%s: transparent=%.6f opaque=%.6f alpha=%d...%d",
      sample_id,
      alpha.fetch("transparentRatio"),
      alpha.fetch("opaqueRatio"),
      alpha.fetch("minimumAlpha"),
      alpha.fetch("maximumAlpha")
    )
  end

  sticker = sample.fetch("sticker")
  if [sticker.fetch("width"), sticker.fetch("height")].max <
      manifest.fetch("matting").fetch("minimumLongEdgePixels")
    errors << "#{sample_id}: sticker long edge is below the delivery minimum"
  end

  unless sample.fetch("productEligibility") == "experiment_only"
    errors << "#{sample_id}: unreviewed experiment must not enter product delivery"
  end
end

if errors.any?
  warn errors.join("\n")
  exit 1
end

puts "Verified #{samples.length} AI source/sticker pairs: opaque source, genuinely transparent Alpha sticker, hashes and dimensions match."
