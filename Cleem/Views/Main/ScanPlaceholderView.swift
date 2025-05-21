import SwiftUI

struct ScanPlaceholderView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        ZStack {
            // Background structure: blue at top and bottom, white in middle
            VStack(spacing: 0) {
                // Top blue part
                Color.appBackground
                    .frame(height: 210) // Increased height to match photo
                
                // Middle white part
                Color.white
                    .frame(maxHeight: .infinity)
                
                // Bottom spacer for tab bar (transparent)
                Color.clear
                    .frame(height: 10)
            }
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Header
                VStack {
                    Spacer()
                        .frame(height: 55) // Add space at top
                    
                    HStack {
                        Text("Cleem")
                            .font(.custom("Pacifico-Regular", size: 42)) // Larger font
                            .foregroundColor(.black)
                            .padding(.leading, 15) // Left align with padding
                        
                        Spacer()
                    }
                    
                    Spacer()
                        .frame(height: 15)
                }
                .frame(height: 120) // Fixed height for header area
                
                Spacer()
                
                // Cleem icon - cloud with face
                ZStack {
                    Circle()
                        .fill(Color.carbsColor.opacity(0.15))
                        .frame(width: 160, height: 160)
                    
                    VStack(spacing: 15) {
                        Image(systemName: "cloud.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .foregroundColor(Color.carbsColor)
                        
                        Text("Cleem AI")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                }
                
                Spacer()
                
                // Camera actions
                VStack(spacing: 16) {
                    Button(action: {
                        navigationCoordinator.showScanCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.carbsColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            Text("Take Photo")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.gray)
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    
                    Button(action: {
                        navigationCoordinator.showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.fatColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            Text("Upload from Gallery")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.gray)
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 150) // Increased padding for taller tab bar
            }
        }
    }
} 