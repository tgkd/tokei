import CoreGraphics
import Foundation
import ImageIO
import Metal

struct GlobeTextures {
    let day: MTLTexture
    let lights: MTLTexture
    let water: MTLTexture
    let clouds: MTLTexture
    let relief: MTLTexture

    static func load(device: MTLDevice, queue: MTLCommandQueue, resources: GlobeResources) -> GlobeTextures? {
        guard
            let day = makeTexture(url: resources.url("earth-day", "jpg"), format: .rgba8Unorm_srgb, device: device),
            let lights = makeTexture(url: resources.url("earth-lights", "jpg"), format: .r8Unorm, device: device),
            let water = makeTexture(url: resources.url("earth-water", "png"), format: .r8Unorm, device: device),
            let clouds = makeCloudTexture(url: resources.url("earth-clouds", "jpg"), device: device),
            let relief = makeReliefTexture(url: resources.url("earth-elevation", "png"), device: device),
            let commandBuffer = queue.makeCommandBuffer(),
            let blit = commandBuffer.makeBlitCommandEncoder()
        else { return nil }
        for texture in [day, lights, water, clouds, relief] {
            blit.generateMipmaps(for: texture)
        }
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return GlobeTextures(day: day, lights: lights, water: water, clouds: clouds, relief: relief)
    }

    private static func makeTexture(url: URL?, format: MTLPixelFormat, device: MTLDevice) -> MTLTexture? {
        let isColor = format == .rgba8Unorm_srgb
        guard let image = decode(url: url, isColor: isColor) else { return nil }
        return upload(image.pixels, width: image.width, height: image.height, bytesPerPixel: isColor ? 4 : 1, format: format, device: device)
    }

    private static func makeCloudTexture(url: URL?, device: MTLDevice) -> MTLTexture? {
        guard let image = decode(url: url, isColor: false) else { return nil }
        let smoothed = polarSmoothed(image.pixels, width: image.width, height: image.height)
        return upload(smoothed, width: image.width, height: image.height, bytesPerPixel: 1, format: .r8Unorm, device: device)
    }

    private static func polarSmoothed(_ pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = pixels
        for row in 0..<height {
            let latitude = (0.5 - (Double(row) + 0.5) / Double(height)) * .pi
            let radius = min(Int(1.2 / cos(latitude) - 1.5), width / 2 - 1)
            guard radius > 0 else { continue }
            let base = row * width
            let span = 2 * radius + 1
            var sum = (-radius...radius).reduce(0) { $0 + Int(pixels[base + ($1 + width) % width]) }
            for column in 0..<width {
                result[base + column] = UInt8((sum + span / 2) / span)
                sum += Int(pixels[base + (column + radius + 1) % width]) - Int(pixels[base + (column - radius + width) % width])
            }
        }
        return result
    }

    private static func makeReliefTexture(url: URL?, device: MTLDevice) -> MTLTexture? {
        guard let elevation = decode(url: url, isColor: false) else { return nil }
        let relief = ReliefMap(elevation: elevation.pixels, width: elevation.width, height: elevation.height)
        return upload(relief.texels, width: elevation.width, height: elevation.height, bytesPerPixel: 2, format: .rg8Snorm, device: device)
    }

    private static func decode(url: URL?, isColor: Bool) -> (pixels: [UInt8], width: Int, height: Int)? {
        guard
            let url,
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let width = image.width
        let height = image.height
        let bytesPerRow = width * (isColor ? 4 : 1)
        let grayColorSpace = image.colorSpace?.model == .monochrome ? image.colorSpace : CGColorSpaceCreateDeviceGray()
        let colorSpace = isColor ? CGColorSpace(name: CGColorSpace.sRGB) : grayColorSpace
        let bitmapInfo = isColor ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.none.rawValue
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let colorSpace,
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                )
            else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        return (pixels, width, height)
    }

    private static func upload<Pixel: BitwiseCopyable>(_ pixels: [Pixel], width: Int, height: Int, bytesPerPixel: Int, format: MTLPixelFormat, device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: true)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width * bytesPerPixel)
        return texture
    }
}
