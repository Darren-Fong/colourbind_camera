import SwiftUI

struct ColorSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Color Vision Type")) {
                    Picker("Color Vision", selection: $settings.colorBlindnessType) {
                        Text("Normal").tag(ColorBlindnessType.normal)
                        Text("Protanopia").tag(ColorBlindnessType.protanopia)
                        Text("Deuteranopia").tag(ColorBlindnessType.deuteranopia)
                        Text("Tritanopia").tag(ColorBlindnessType.tritanopia)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Protanopia")
                            .font(.headline)
                        Text("Difficulty distinguishing between red and green colors")
                            .foregroundColor(.secondary)
                        
                        Text("Deuteranopia")
                            .font(.headline)
                        Text("Another form of red-green color blindness")
                            .foregroundColor(.secondary)
                        
                        Text("Tritanopia")
                            .font(.headline)
                        Text("Difficulty distinguishing between blue and yellow colors")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Color Vision Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}