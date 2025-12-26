import SwiftUI
import PhotosUI
import UIKit

struct PhotoPickerBridge: View {
    @Binding var isPresented: Bool
    let onPicked: (UIImage) -> Void
    
    @State private var item: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
            EmptyView()
        }
        .photosPickerStyle(.inline)
        .onChange(of: item) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    onPicked(img)
                }
                item = nil
                isPresented = false
            }
        }
        .opacity(0.01)
        .frame(width: 1, height: 1)
    }
}
