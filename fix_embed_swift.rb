#!/usr/bin/env ruby
require 'xcodeproj'

# Путь к проекту
project_path = 'Cleem.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Находим основной таргет
target = project.targets.find { |t| t.name == 'Cleem' }

# Исправляем ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES
target.build_configurations.each do |config|
  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = "$(inherited)"
  
  # Проверяем и исправляем другие настройки, которые могут вызывать проблемы
  # Добавляем $(inherited) к настройкам поиска
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['LIBRARY_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['OTHER_LDFLAGS'] ||= ['$(inherited)']
  
  # Убеждаемся, что включена поддержка модулей
  config.build_settings['DEFINES_MODULE'] = 'YES'
  
  # Добавляем Other Linker Flags для поддержки Objective-C
  if !config.build_settings['OTHER_LDFLAGS'].include?('-ObjC')
    config.build_settings['OTHER_LDFLAGS'] << '-ObjC'
  end
end

# Сохраняем изменения
project.save 