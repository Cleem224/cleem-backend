import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showAPISettings = false
    @State private var showAPISettingsV2 = false
    @State private var useNewRecognition: Bool = UserDefaults.standard.bool(forKey: "use_new_recognition")
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Основные настройки")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Режим распознавания еды")
                            .font(.headline)
                        
                        Picker(selection: $useNewRecognition, label: Text("Метод распознавания")) {
                            Text("Классический (Gemini + Edamam)").tag(false)
                            Text("Новый (Gemini + GPT + Spoonacular)").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: useNewRecognition) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "use_new_recognition")
                            UserDefaults.standard.synchronize()
                        }
                        
                        Text("Выберите метод распознавания еды при сканировании фотографий")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("API Ключи")) {
                    if useNewRecognition {
                        Button(action: { showAPISettingsV2 = true }) {
                            HStack {
                                Image(systemName: "key")
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.white)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Настройки API ключей (Новая система)")
                                        .font(.headline)
                                    
                                    Text("Gemini, Spoonacular, OpenAI")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        Button(action: { showAPISettings = true }) {
                            HStack {
                                Image(systemName: "key")
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.white)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Настройки API ключей (Классический)")
                                        .font(.headline)
                                    
                                    Text("Gemini, Edamam")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Section(header: Text("О приложении")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cleem - Приложение для отслеживания питания")
                            .font(.headline)
                        
                        Text("Версия: 1.1.0")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("© 2023-2024")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationBarTitle("Настройки", displayMode: .inline)
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showAPISettings) {
                APIKeysSettingsView()
            }
            .sheet(isPresented: $showAPISettingsV2) {
                APIKeysSettingsViewV2()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

