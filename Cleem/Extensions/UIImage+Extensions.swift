import UIKit

extension UIImage {
    // Метод для нормализации ориентации изображения
    func normalizedImage() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
    
    // Метод для получения доминирующего цвета изображения
    func getDominantColor() -> UIColor {
        let resizedImage = self.resize(to: CGSize(width: 50, height: 50))
        guard let cgImage = resizedImage.cgImage else { return .gray }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return .gray }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var pixelCount: CGFloat = 0
        
        for x in 0..<width {
            for y in 0..<height {
                let byteIndex = (bytesPerRow * y) + x * bytesPerPixel
                red += CGFloat(rawData[byteIndex])
                green += CGFloat(rawData[byteIndex + 1])
                blue += CGFloat(rawData[byteIndex + 2])
                pixelCount += 1
            }
        }
        
        return UIColor(
            red: red / (pixelCount * 255.0),
            green: green / (pixelCount * 255.0),
            blue: blue / (pixelCount * 255.0),
            alpha: 1.0
        )
    }
    
    // Метод для изменения размера изображения
    func resize(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? self
    }
}

// Расширение для UIColor для определения доминирующего цвета
extension UIColor {
    var isGreenish: Bool {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return g > 0.5 && g > r && g > b
    }
    
    var isRedish: Bool {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > 0.5 && r > g && r > b
    }
    
    var isYellowish: Bool {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > 0.5 && g > 0.5 && b < 0.3
    }
    
    var isBrownish: Bool {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > 0.4 && g > 0.2 && g < 0.4 && b < 0.2
    }
}

