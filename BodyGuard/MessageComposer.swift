// MessageComposer.swift
import SwiftUI
import MessageUI

struct MessageComposer: UIViewControllerRepresentable {
    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposer
        init(parent: MessageComposer) { self.parent = parent }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.parent.onFinish?(result)
            }
        }
    }

    var recipients: [String]
    var bodyText: String
    var onFinish: ((MessageComposeResult) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = bodyText
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
}
