# Датасет Fruit - Open Images Dataset

## Содержимое датасета
- **Класс:** Fruit (фрукты)
- **Количество изображений:** 
  - Train: ~1000 изображений
  - Test: ~1351 изображений
- **Формат разметки:** YOLO (в папках labels_yolo)
- **Формат изображений:** JPEG (.jpg)

## Структура архива
```
fruit_dataset.zip
├── train/
│   ├── Fruit/          # Изображения для обучения
│   └── labels_yolo/    # Разметка в формате YOLO
└── test/
    ├── Fruit/          # Тестовые изображения
    └── labels_yolo/    # Разметка в формате YOLO
```

## Использование в Google Colab

### 1. Загрузите архив в Google Drive

### 2. Подключите Google Drive к Colab
```python
from google.colab import drive
drive.mount('/content/drive')
```

### 3. Распакуйте архив
```python
!mkdir -p /content/dataset
!unzip /content/drive/MyDrive/fruit_dataset.zip -d /content/dataset/
```

### 4. Подготовка данных для YOLOv5/YOLOv8
```python
# Создаем yaml-файл с конфигурацией датасета
%%writefile /content/dataset/fruit.yaml
train: /content/dataset/train/
val: /content/dataset/test/
test: /content/dataset/test/

# Classes
nc: 1  # количество классов
names: ['Fruit']  # названия классов
```

### 5. Пример обучения модели YOLOv8
```python
!pip install ultralytics

from ultralytics import YOLO

# Загрузить модель
model = YOLO('yolov8n.pt')  # предварительно обученная модель

# Обучить модель
results = model.train(
    data='/content/dataset/fruit.yaml',
    epochs=100,
    imgsz=640,
    device=0,
    batch=16,
)
```

### 6. Проверка модели на тестовых данных
```python
# Проверка точности
results = model.val()

# Визуализация предсказаний
results = model('/content/dataset/test/Fruit/image.jpg')
results.show()  # визуализировать результаты
```

## Дополнительная информация
Этот датасет создан из Open Images Dataset v6 с использованием OIDv4_ToolKit. Аннотации конвертированы из формата Open Images в формат YOLO.

Формат аннотаций YOLO: `<class_id> <x_center> <y_center> <width> <height>`
- Все значения нормализованы от 0 до 1
- class_id = 0 для класса "Fruit" 