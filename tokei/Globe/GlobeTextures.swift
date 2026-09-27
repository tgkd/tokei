import CoreGraphics
import Foundation
import ImageIO
import Metal

struct GlobeTextures {
    let day: MTLTexture
    let lights: MTLTexture
    let water: MTLTexture

    static func load(device: MTLDevice, queue: MTLCommandQueue) -> GlobeTextures? {
        guard
            let day = makeTexture(resource: "earth-day", extension: "jpg", format: .rgba8Unorm_srgb, device: device),
            let lights = makeTexture(resource: "earth-lights", extension: "jpg", format: .r8Unorm, device: device),
            let water = makeTexture(resource: "earth-water", extension: "png", format: .r8Unorm, device: device),
            let commandBuffer = queue.makeCommandBuffer(),
            let blit = commandBuffer.makeBlitCommandEncoder()
        else { return nil }
        blit.generateMipmaps(for: day)
        blit.generateMipmaps(for: lights)
        blit.generateMipmaps(for: water)
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return GlobeTextures(day: day, lights: lights, water: water)
    }

    private static func makeTexture(resource: String, extension fileExtension: String, format: MTLPixelFormat, device: MTLDevice) -> MTLTexture? {
        guard
            let url = Bundle.main.url(forResource: resource, withExtension: fileExtension),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let isColor = format == .rgba8Unorm_srgb
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

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: true)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: bytesPerRow)
        return texture
    }
}
