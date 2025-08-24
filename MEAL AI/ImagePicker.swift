import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    enum Source {
        case camera
        case photoLibrary
    }
    

    let sourceType: UIImagePickerController.SourceType
    let completion: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    init(sourceType: UIImagePickerController.SourceType, completion: @escaping (UIImage) -> Void) {
        self.sourceType = sourceType
        self.completion = completion
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        if sourceType == .camera {
            picker.modalPresentationStyle = .fullScreen
        }

        return picker
        
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completion(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
