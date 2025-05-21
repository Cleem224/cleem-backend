import AVFoundation

extension AVCaptureDevice.Format {
    var supportedVideoZoomFactorRange: ClosedRange<CGFloat> {
        // Рассчитываем диапазон доступных значений зума
        // Минимальное значение всегда 1.0
        let minZoom: CGFloat = 1.0
        
        // Максимальное значение зависит от возможностей устройства
        // На реальных устройствах часто ограничено 2x или 4x, в зависимости от камеры
        let maxZoom: CGFloat = videoMaxZoomFactor > 4.0 ? 4.0 : videoMaxZoomFactor
        
        return minZoom...maxZoom
    }
} 