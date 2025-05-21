import SwiftUI
import Combine

struct APIKeysSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var foodRecognitionManager = FoodRecognitionManager()
    
    @State private var geminiApiKey: String = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
    @State private var edamamAppId: String = UserDefaults.standard.string(forKey: "edamam_app_id") ?? ""
    @State private var edamamAppKey: String = UserDefaults.standard.string(forKey: "edamam_app_key") ?? ""
    @State private var edamamFoodDbId: String = UserDefaults.standard.string(forKey: "edamam_food_db_id") ?? ""
    @State private var edamamFoodDbKey: String = UserDefaults.standard.string(forKey: "edamam_food_db_key") ?? ""
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gemini API")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                        
                        SecureField("Enter Gemini API Key", text: $geminiApiKey)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Link("Get Gemini API Key", destination: URL(string: "https://makersuite.google.com/app/apikey")!)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Edamam Nutrition Analysis API")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Application ID")
                            .font(.headline)
                        
                        SecureField("Enter Edamam Nutrition App ID", text: $edamamAppId)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text("Application Key")
                            .font(.headline)
                            .padding(.top, 12)
                        
                        SecureField("Enter Edamam Nutrition App Key", text: $edamamAppKey)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Link("Get Edamam Nutrition API Keys", destination: URL(string: "https://developer.edamam.com/edamam-nutrition-api")!)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Edamam Food Database API")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Food Database App ID")
                            .font(.headline)
                        
                        SecureField("Enter Edamam Food DB App ID", text: $edamamFoodDbId)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text("Food Database App Key")
                            .font(.headline)
                            .padding(.top, 12)
                        
                        SecureField("Enter Edamam Food DB App Key", text: $edamamFoodDbKey)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Link("Get Edamam Food Database API Keys", destination: URL(string: "https://developer.edamam.com/food-database-api")!)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(action: saveKeys) {
                        Text("Save API Keys")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.89, green: 0.19, blue: 0.18))
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Section(header: Text("Info")) {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(title: "About Gemini API", description: "Gemini Pro Vision API используется для распознавания еды на фотографиях.")
                        
                        InfoRow(title: "About Edamam Nutrition API", description: "Edamam Nutrition Analysis API предоставляет подробную информацию о питательной ценности продуктов.")
                        
                        InfoRow(title: "About Edamam Food DB API", description: "Edamam Food Database API используется для поиска и рекомендаций продуктов.")
                        
                        InfoRow(title: "Security", description: "Все API ключи хранятся только на вашем устройстве и не передаются третьим лицам.")
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("API Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(isSuccess ? "Success" : "Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func saveKeys() {
        if geminiApiKey.isEmpty || edamamAppId.isEmpty || edamamAppKey.isEmpty || edamamFoodDbId.isEmpty || edamamFoodDbKey.isEmpty {
            alertMessage = "Please enter all API keys"
            isSuccess = false
            showAlert = true
            return
        }
        
        // Сохраняем ключи
        UserDefaults.standard.set(geminiApiKey, forKey: "gemini_api_key")
        UserDefaults.standard.set(edamamAppId, forKey: "edamam_app_id")
        UserDefaults.standard.set(edamamAppKey, forKey: "edamam_app_key")
        UserDefaults.standard.set(edamamFoodDbId, forKey: "edamam_food_db_id")
        UserDefaults.standard.set(edamamFoodDbKey, forKey: "edamam_food_db_key")
        UserDefaults.standard.synchronize()
        
        alertMessage = "API keys saved successfully"
        isSuccess = true
        showAlert = true
    }
}

struct InfoRow: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.body)
                .foregroundColor(.gray)
        }
    }
}

struct APIKeysSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        APIKeysSettingsView()
    }
}

