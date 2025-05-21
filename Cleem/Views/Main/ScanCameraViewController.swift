import UIKit
import AVFoundation

class ScanCameraViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Свойства
    private var cameraPicker: UIImagePickerController?
    
    // UI элементы
    private var previewView: UIView!
    private var captureButton: UIButton!
    private var closeButton: UIButton!
    private var modeButton: UIButton!
    private var currentMode: CaptureMode = .photo
    
    // Обратный вызов для передачи захваченного изображения
    var onImageCaptured: ((UIImage) -> Void)?
    
    // Типы режимов
    enum CaptureMode {
        case photo, barcode
    }
    
    // MARK: - Жизненный цикл
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        launchCamera()
    }
    
    // MARK: - Настройка интерфейса
    private func setupUI() {
        view.backgroundColor = .black
        
        // Создаем предварительный просмотр камеры (не используется с UIImagePickerController)
        previewView = UIView()
        previewView.backgroundColor = .black
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        
        // Создаем кнопку захвата
        captureButton = UIButton(type: .custom)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.layer.borderWidth = 3
        captureButton.backgroundColor = .white
        captureButton.addTarget(self, action: #selector(launchCamera), for: .touchUpInside)
        view.addSubview(captureButton)
        
        // Создаем кнопку закрытия
        closeButton = UIButton(type: .custom)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 20
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // Создаем кнопку режима
        modeButton = createModeButton()
        view.addSubview(modeButton)
        
        // Ограничения для предварительного просмотра
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Ограничения для кнопки захвата
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            // Ограничения для кнопки закрытия
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Ограничения для кнопки режима
            modeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            modeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            modeButton.widthAnchor.constraint(equalToConstant: 110),
            modeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func createModeButton() -> UIButton {
        if #available(iOS 15.0, *) {
            var configuration = UIButton.Configuration.filled()
            configuration.baseBackgroundColor = UIColor.black.withAlphaComponent(0.6)
            configuration.title = "Режим: Фото"
            configuration.titleAlignment = .center
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 12)
                return outgoing
            }
            
            let button = UIButton(configuration: configuration)
            button.addTarget(self, action: #selector(toggleMode), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        } else {
            // Для iOS версий ниже 15.0
            let button = UIButton(type: .system)
            button.setTitle("Режим: Фото", for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            button.addTarget(self, action: #selector(toggleMode), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        }
    }
    
    // MARK: - Действия
    @objc private func launchCamera() {
        // Проверяем доступность камеры
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            showAlert(title: "Ошибка", message: "Камера недоступна")
            return
        }
        
        // Создаем и настраиваем UIImagePickerController
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = self
        
        // Сохраняем ссылку на picker
        cameraPicker = picker
        
        // Показываем контроллер камеры
        present(picker, animated: true)
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func toggleMode() {
        currentMode = currentMode == .photo ? .barcode : .photo
        
        if #available(iOS 15.0, *) {
            var config = modeButton.configuration
            config?.title = currentMode == .photo ? "Режим: Фото" : "Режим: Штрихкод"
            modeButton.configuration = config
        } else {
            modeButton.setTitle(currentMode == .photo ? "Режим: Фото" : "Режим: Штрихкод", for: .normal)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            if let image = info[.originalImage] as? UIImage {
                // Передаем изображение через обратный вызов
                self?.onImageCaptured?(image)
                // Закрываем контроллер
                self?.dismiss(animated: true)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

