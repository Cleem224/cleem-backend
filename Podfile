platform :ios, '14.0'

# Отключаем use_frameworks, это важно!
# use_frameworks!
use_frameworks! :linkage => :static

target 'Cleem' do
  # Основные поды для приложения
  pod 'GoogleSignIn', '7.0.0', :modular_headers => true
  # Используем GTMAppAuth и GTMSessionFetcher без конфликтов
  pod 'GTMAppAuth', '1.3.1'
  pod 'GTMSessionFetcher/Core', '2.3.0'
  
  # Если нужны другие библиотеки, добавляйте их сюда
  
  target 'CleemTests' do
    inherit! :search_paths
    # Поды для тестирования, если нужны
  end
end

# Упрощенный post_install без конфликтующих настроек
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      
      # Базовые настройки
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
      config.build_settings['LIBRARY_SEARCH_PATHS'] ||= ['$(inherited)']
      config.build_settings['OTHER_LDFLAGS'] ||= ['$(inherited)']
      
      # Отключаем модульные карты, которые могут вызывать проблемы
      config.build_settings['DEFINES_MODULE'] = 'NO'
      
      # Разрешаем устанавливать папки сборки во временную директорию
      config.build_settings['CONFIGURATION_TEMP_DIR'] = '$(PROJECT_TEMP_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)'
      config.build_settings['CONFIGURATION_BUILD_DIR'] = '$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)'
      
      # Отключаем битовый код и другие потенциальные источники проблем
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
      
      # Разрешаем рекурсивное копирование
      config.build_settings['COPY_RESOURCES_FROM_STATIC_FRAMEWORKS'] = 'YES'
    end
  end
end 