import SwiftUI

struct ScanView: View {
    @State private var showCamera = false
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                
                Text("Scan Product")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Position the barcode within the frame to scan")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    showCamera = true
                } label: {
                    Text("Start Scanning")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                        .padding(.horizontal, 30)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Scan")
            .fullScreenCover(isPresented: $showCamera) {
                if navigationCoordinator.shouldUseNewScanCameraView {
                    ScanCameraViewV2()
                        .environmentObject(navigationCoordinator)
                } else {
                    ScanCameraView()
                        .environmentObject(navigationCoordinator)
                }
            }
        }
    }
}

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        ScanView()
            .environmentObject(NavigationCoordinator.shared)
    }
} 