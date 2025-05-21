import SwiftUI
import Combine

// Импортируем наш класс миграции
import Foundation

struct APIKeysSettingsViewV2: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var foodRecognitionManager = FoodRecognitionManagerV2()
    
    @State private var geminiApiKey: String = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
    @State private var edamamAppId: String = UserDefaults.standard.string(forKey: "edamam_app_id") ?? ""
    @State private var edamamAppKey: String = UserDefaults.standard.string(forKey: "edamam_app_key") ?? ""
    @State private var openaiApiKey: String = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    @State private var isMigrating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gemini API")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                        
                        SecureField("Введите Gemini API Key", text: $geminiApiKey)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Link("Получить Gemini API Key", destination: URL(string: "https://makersuite.google.com/app/apikey")!)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Edamam API")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App ID")
                            .font(.headline)
                        
                        SecureField("Введите Edamam App ID", text: $edamamAppId)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text("API Key")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        SecureField("Введите Edamam API Key", text: $edamamAppKey)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Link("Получить Edamam API Key и App ID", destination: URL(string: "https://developer.edamam.com/edamam-nutrition-api")!)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("OpenAI API")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                        
                        SecureField("Введите OpenAI API Key", text: $openaiApiKey)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Link("Получить OpenAI API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                // Действия
                Section {
                    Button(action: {
                        saveApiKeys()
                    }) {
                        Text("Сохранить")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(.headline)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        restoreDefaultKeys()
                    }) {
                        Text("Восстановить стандартные ключи")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(.headline)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        startMigration()
                    }) {
                        HStack {
                            Text("Миграция с Spoonacular на Edamam")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.headline)
                                .padding()
                                .foregroundColor(.white)
                            
                            if isMigrating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 16)
                            }
                        }
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                    .disabled(isMigrating)
                }
                
                Section(header: Text("О миграции")) {
                    Text("Миграция с Spoonacular на Edamam API необходима из-за ограничений бесплатного уровня Spoonacular. Edamam предоставляет более надежный API с большими лимитами.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            .navigationBarTitle("API Ключи (Новая система)", displayMode: .inline)
            .navigationBarItems(trailing: Button("Готово") {
                self.presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(isSuccess ? "Успех" : "Ошибка"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    func saveApiKeys() {
        // Сохраняем все ключи в UserDefaults
        UserDefaults.standard.set(geminiApiKey, forKey: "gemini_api_key")
        UserDefaults.standard.set(edamamAppId, forKey: "edamam_app_id")
        UserDefaults.standard.set(edamamAppKey, forKey: "edamam_app_key")
        UserDefaults.standard.set(openaiApiKey, forKey: "openai_api_key")
        UserDefaults.standard.synchronize()
        
        // Обновляем ключи в соответствующих сервисах
        OpenAIService.shared.updateApiKey(openaiApiKey)
        
        // Показываем уведомление об успехе
        isSuccess = true
        alertMessage = "API ключи успешно сохранены!"
        showAlert = true
    }
    
    func restoreDefaultKeys() {
        // Устанавливаем дефолтные ключи
        foodRecognitionManager.setDefaultApiKeys()
        
        // Обновляем UI
        geminiApiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        edamamAppId = UserDefaults.standard.string(forKey: "edamam_app_id") ?? ""
        edamamAppKey = UserDefaults.standard.string(forKey: "edamam_app_key") ?? ""
        openaiApiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        
        // Показываем уведомление
        isSuccess = true
        alertMessage = "Стандартные API ключи восстановлены!"
        showAlert = true
    }
    
    func startMigration() {
        isMigrating = true
        
        // Запускаем процесс миграции
        SpoonacularToEdamamMigration.shared.migrateToEdamam { success, message in
            DispatchQueue.main.async {
                self.isMigrating = false
                self.isSuccess = success
                self.alertMessage = message
                self.showAlert = true
            }
        }
    }
}

struct APIKeysSettingsViewV2_Previews: PreviewProvider {
    static var previews: some View {
        APIKeysSettingsViewV2()
    }
} 