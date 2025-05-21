#!/usr/bin/env ruby
require 'xcodeproj'

# Открываем проект
project_path = 'Cleem.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Находим основной таргет
target = project.targets.find { |t| t.name == 'Cleem' }

# Устанавливаем Bridging Header для всех конфигураций
target.build_configurations.each do |config|
  config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = 'Cleem/Cleem-Bridging-Header.h'
  config.build_settings['SWIFT_OBJC_INTERFACE_HEADER_NAME'] = 'Cleem-Swift.h'
  
  # Добавляем другие важные настройки
  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
  config.build_settings['OTHER_LDFLAGS'] = '$(inherited) -ObjC'
  
  # Специфичные для GoogleSignIn настройки
  config.build_settings['OTHER_SWIFT_FLAGS'] = '$(inherited) -D IMPORT_GOOGLE_SIGNIN'
end

# Сохраняем изменения
project.save 