import SwiftUI
import UIKit

struct AICameraView: UIViewControllerRepresentable {
    var onImageData: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        p.allowsEditing = false
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coord { Coord(self) }

    final class Coord: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: AICameraView
        init(_ p: AICameraView) { self.parent = p }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage,
               let data = img.jpegData(compressionQuality: 0.8) {
                picker.dismiss(animated: true) {
                    self.parent.onImageData(data)
                }
            } else {
                picker.dismiss(animated: true)
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
