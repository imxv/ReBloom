#!/usr/bin/env swift

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision

enum GeneratorError: Error {
    case badArguments
    case unreadableImage
    case personNotFound
    case renderFailed
}

guard CommandLine.arguments.count == 3 else {
    throw GeneratorError.badArguments
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let sourceImage = NSImage(contentsOf: inputURL),
      let sourceCGImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    throw GeneratorError.unreadableImage
}

let source = CIImage(cgImage: sourceCGImage)
let sourceExtent = source.extent.integral
let request = VNGeneratePersonSegmentationRequest()
request.qualityLevel = .accurate
request.outputPixelFormat = kCVPixelFormatType_OneComponent8

try VNImageRequestHandler(ciImage: source).perform([request])
guard let observation = request.results?.first else {
    throw GeneratorError.personNotFound
}

var mask = CIImage(cvPixelBuffer: observation.pixelBuffer)
mask = mask
    .transformed(by: CGAffineTransform(
        scaleX: sourceExtent.width / mask.extent.width,
        y: sourceExtent.height / mask.extent.height
    ))
    .cropped(to: sourceExtent)

let outlineRadius = max(12, min(sourceExtent.width, sourceExtent.height) * 0.014)
let padding = ceil(outlineRadius * 2.25)
let translation = CGAffineTransform(
    translationX: padding - sourceExtent.minX,
    y: padding - sourceExtent.minY
)
let translatedSource = source.transformed(by: translation)
let translatedMask = mask.transformed(by: translation)
let canvas = CGRect(
    x: 0,
    y: 0,
    width: sourceExtent.width + padding * 2,
    height: sourceExtent.height + padding * 2
).integral

let clear = CIImage(color: .clear).cropped(to: canvas)
let white = CIImage(color: .white).cropped(to: canvas)
let expandedMask = translatedMask
    .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: outlineRadius])
    .cropped(to: canvas)
let outline = white.applyingFilter(
    "CIBlendWithMask",
    parameters: [
        kCIInputBackgroundImageKey: clear,
        kCIInputMaskImageKey: expandedMask,
    ]
)
let subject = translatedSource.applyingFilter(
    "CIBlendWithMask",
    parameters: [
        kCIInputBackgroundImageKey: clear,
        kCIInputMaskImageKey: translatedMask,
    ]
)
let composited = subject.composited(over: outline).cropped(to: canvas)
let context = CIContext(options: [.cacheIntermediates: false])

guard let fullCGImage = context.createCGImage(
    composited,
    from: canvas,
    format: .RGBA8,
    colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
) else {
    throw GeneratorError.renderFailed
}

func cropToLargestVisibleComponent(_ image: CGImage, margin: Int) -> CGImage? {
    let width = image.width
    let height = image.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

    guard let bitmap = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        return nil
    }
    bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var visited = [UInt8](repeating: 0, count: width * height)
    var queue: [Int] = []
    queue.reserveCapacity(width * height / 4)
    var bestCount = 0
    var bestBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)?

    for start in 0..<(width * height) {
        guard visited[start] == 0,
              pixels[start * bytesPerPixel + 3] > 16 else {
            continue
        }

        visited[start] = 1
        queue.removeAll(keepingCapacity: true)
        queue.append(start)
        var head = 0
        var minX = start % width
        var maxX = minX
        var minY = start / width
        var maxY = minY

        while head < queue.count {
            let index = queue[head]
            head += 1
            let x = index % width
            let y = index / width
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)

            func enqueue(_ neighbor: Int) {
                guard visited[neighbor] == 0,
                      pixels[neighbor * bytesPerPixel + 3] > 16 else {
                    return
                }
                visited[neighbor] = 1
                queue.append(neighbor)
            }

            if x > 0 { enqueue(index - 1) }
            if x + 1 < width { enqueue(index + 1) }
            if y > 0 { enqueue(index - width) }
            if y + 1 < height { enqueue(index + width) }
        }

        if queue.count > bestCount {
            bestCount = queue.count
            bestBounds = (minX, minY, maxX, maxY)
        }
    }

    guard var bounds = bestBounds else { return nil }
    bounds.minX = max(0, bounds.minX - margin)
    bounds.minY = max(0, bounds.minY - margin)
    bounds.maxX = min(width - 1, bounds.maxX + margin)
    bounds.maxY = min(height - 1, bounds.maxY + margin)

    return image.cropping(to: CGRect(
        x: bounds.minX,
        y: bounds.minY,
        width: bounds.maxX - bounds.minX + 1,
        height: bounds.maxY - bounds.minY + 1
    ))
}

let cropped = cropToLargestVisibleComponent(
    fullCGImage,
    margin: Int(padding * 0.35)
) ?? fullCGImage

func ensureMinimumLongEdge(_ image: CGImage, minimum: CGFloat) -> CGImage? {
    let longEdge = CGFloat(max(image.width, image.height))
    guard longEdge > 0, longEdge < minimum else { return image }

    let filter = CIFilter.lanczosScaleTransform()
    filter.inputImage = CIImage(cgImage: image)
    filter.scale = Float(minimum / longEdge)
    filter.aspectRatio = 1
    guard let output = filter.outputImage else { return nil }

    return context.createCGImage(
        output,
        from: output.extent.integral,
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
    )
}

let deliveryImage = ensureMinimumLongEdge(cropped, minimum: 1_536) ?? cropped
let representation = NSBitmapImageRep(cgImage: deliveryImage)
guard let png = representation.representation(using: .png, properties: [:]) else {
    throw GeneratorError.renderFailed
}
try png.write(to: outputURL, options: .atomic)

print("Generated \(outputURL.path) (\(deliveryImage.width)x\(deliveryImage.height))")
