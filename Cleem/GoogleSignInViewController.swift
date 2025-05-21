import Foundation
import UIKit
import SwiftUI
import Combine

// Import the Models module to access UserData
import Cleem

// MARK: - UIKit представление для интеграции с SwiftUI

class GoogleSignInViewController: UIViewController {
    private var googleSignInHandler: GoogleSignInHandler
    private var completion: ((Result<UserData, Error>) -> Void)?
    
    init(googleSignInHandler: GoogleSignInHandler, completion: @escaping (Result<UserData, Error>) -> Void) {
        self.googleSignInHandler = googleSignInHandler
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        // Центрированное представление для экрана входа
        let loginView = createLoginView()
        view.addSubview(loginView)
        
        // Ограничения для центрирования
        loginView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loginView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loginView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            loginView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
        
        // Кнопка закрытия
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Закрыть", for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    private func createLoginView() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowRadius = 10
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        // Заголовок
        let titleLabel = UILabel()
        titleLabel.text = "Войти в Cleem"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        
        // Описание
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Для сохранения данных и синхронизации между устройствами необходимо войти в аккаунт"
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .gray
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        
        // Кнопка входа через Google
        let googleSignInButton = createGoogleSignInButton()
        
        // Добавление элементов в контейнер
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(googleSignInButton)
        
        // Настройка ограничений
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        googleSignInButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            googleSignInButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
            googleSignInButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            googleSignInButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            googleSignInButton.heightAnchor.constraint(equalToConstant: 50),
            googleSignInButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -30)
        ])
        
        return containerView
    }
    
    private func createGoogleSignInButton() -> UIButton {
        let button = UIButton(type: .system)
        
        // Настройка внешнего вида
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.5).cgColor
        
        // Добавление иконки Google
        let googleIcon = UIImageView(image: UIImage(systemName: "g.circle.fill"))
        googleIcon.tintColor = .red
        button.addSubview(googleIcon)
        
        // Добавление текста
        let label = UILabel()
        label.text = "Войти через Google"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .darkGray
        button.addSubview(label)
        
        // Настройка ограничений
        googleIcon.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            googleIcon.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            googleIcon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            googleIcon.widthAnchor.constraint(equalToConstant: 24),
            googleIcon.heightAnchor.constraint(equalToConstant: 24),
            
            label.leadingAnchor.constraint(equalTo: googleIcon.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            label.centerXAnchor.constraint(equalTo: button.centerXAnchor, constant: 10)
        ])
        
        // Добавление обработчика нажатия
        button.addTarget(self, action: #selector(googleSignInButtonTapped), for: .touchUpInside)
        
        return button
    }
    
    @objc private func googleSignInButtonTapped() {
        googleSignInHandler.signIn(from: self) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let completion = self.completion {
                    completion(result)
                }
                
                // Закрываем экран после успешного входа
                if case .success = result {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
} 