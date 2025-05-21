import UIKit

class AddMenuViewController: UIViewController {
    
    // Структура для опций меню
    struct MenuOption {
        let title: String
        let icon: String
    }
    
    // Массив с опциями меню
    private let menuOptions = [
        MenuOption(title: "Log exercise", icon: "figure.walk"),
        MenuOption(title: "Saved foods", icon: "bookmark.fill"),
        MenuOption(title: "Food Database", icon: "magnifyingglass"),
        MenuOption(title: "Scan food", icon: "camera.viewfinder")
    ]
    
    // Замыкание, которое будет вызвано при выборе опции
    var optionSelected: ((Int) -> Void)?
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 15
        layout.minimumInteritemSpacing = 15
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // Добавление жеста для закрытия при нажатии вне меню
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissMenu))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        // Добавление и настройка CollectionView
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            collectionView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 350)
        ])
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(MenuOptionCell.self, forCellWithReuseIdentifier: "MenuOptionCell")
        collectionView.isScrollEnabled = false
    }
    
    @objc private func dismissMenu() {
        dismiss(animated: true)
    }
    
    // Метод для закрытия с коллбэком
    func dismissWithCompletion(completion: @escaping () -> Void) {
        dismiss(animated: true) {
            completion()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension AddMenuViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Позволяет закрыть меню при нажатии вне collectionView
        return touch.view == self.view
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource
extension AddMenuViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return menuOptions.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MenuOptionCell", for: indexPath) as! MenuOptionCell
        let option = menuOptions[indexPath.item]
        cell.configure(with: option)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 15) / 2
        return CGSize(width: width, height: 160)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        optionSelected?(indexPath.item)
    }
}

// MARK: - MenuOptionCell
class MenuOptionCell: UICollectionViewCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .black
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = .white
        layer.cornerRadius = 12
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -20),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 10),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }
    
    func configure(with option: AddMenuViewController.MenuOption) {
        titleLabel.text = option.title
        iconImageView.image = UIImage(systemName: option.icon)
    }
}
