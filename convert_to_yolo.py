#!/usr/bin/env python3

import os
import glob
from PIL import Image
from tqdm import tqdm
import argparse

def convert_to_yolo_format(image_path, label_path, output_path):
    """
    Конвертирует аннотации из формата Open Images в формат YOLO
    
    Open Images формат: class_name x_min y_min x_max y_max
    YOLO формат: class_id x_center y_center width height
    
    Все значения в YOLO формате должны быть нормализованы от 0 до 1
    """
    if not os.path.exists(output_path):
        os.makedirs(output_path)
    
    # Получаем список всех изображений
    image_files = glob.glob(os.path.join(image_path, "*.jpg"))
    
    # Словарь классов (в нашем случае только Fruit с id 0)
    class_dict = {"Fruit": 0}
    
    print(f"Найдено {len(image_files)} изображений")
    
    for img_file in tqdm(image_files, desc="Конвертация аннотаций"):
        # Получаем имя файла без расширения
        base_name = os.path.basename(img_file).split('.')[0]
        
        # Путь к файлу с аннотациями
        label_file = os.path.join(label_path, f"{base_name}.txt")
        
        # Проверяем существование файла с аннотациями
        if not os.path.exists(label_file):
            print(f"Файл аннотаций не найден: {label_file}")
            continue
        
        # Открываем изображение для получения размеров
        try:
            img = Image.open(img_file)
            img_width, img_height = img.size
        except Exception as e:
            print(f"Ошибка при открытии изображения {img_file}: {e}")
            continue
        
        # Создаем выходной файл
        output_file = os.path.join(output_path, f"{base_name}.txt")
        
        with open(label_file, 'r') as f_in, open(output_file, 'w') as f_out:
            lines = f_in.readlines()
            
            for line in lines:
                parts = line.strip().split()
                
                if len(parts) != 5:
                    print(f"Неверный формат строки: {line}")
                    continue
                
                class_name = parts[0]
                if class_name not in class_dict:
                    print(f"Неизвестный класс: {class_name}")
                    continue
                
                class_id = class_dict[class_name]
                
                # Извлекаем координаты
                try:
                    x_min = float(parts[1])
                    y_min = float(parts[2])
                    x_max = float(parts[3])
                    y_max = float(parts[4])
                except ValueError:
                    print(f"Ошибка при конвертации координат: {line}")
                    continue
                
                # Вычисляем центр и размеры объекта
                x_center = (x_min + x_max) / 2.0
                y_center = (y_min + y_max) / 2.0
                width = x_max - x_min
                height = y_max - y_min
                
                # Нормализуем значения от 0 до 1
                x_center /= img_width
                y_center /= img_height
                width /= img_width
                height /= img_height
                
                # Записываем результат в формате YOLO
                f_out.write(f"{class_id} {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}\n")
    
    print(f"Конвертация завершена. Результаты сохранены в {output_path}")

def process_dataset(dataset_type):
    """Обрабатывает указанный тип данных (train, test или validation)"""
    base_path = os.path.join("OID", "Dataset", dataset_type)
    image_path = os.path.join(base_path, "Fruit")
    label_path = os.path.join(base_path, "Label")
    output_path = os.path.join(base_path, "labels_yolo")
    
    print(f"Обрабатываем {dataset_type} данные...")
    convert_to_yolo_format(image_path, label_path, output_path)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Конвертер аннотаций из Open Images в формат YOLO")
    parser.add_argument('--type', choices=['train', 'test', 'validation', 'all'], default='all',
                        help="Тип данных для конвертации (train, test, validation или all)")
    
    args = parser.parse_args()
    
    if args.type == 'all':
        for dataset_type in ['train', 'test', 'validation']:
            if os.path.exists(os.path.join("OID", "Dataset", dataset_type)):
                process_dataset(dataset_type)
    else:
        process_dataset(args.type) 