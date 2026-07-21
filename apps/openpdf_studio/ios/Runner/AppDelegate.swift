import Flutter
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct QPdfSemanticSuggestion {
  @Guide(description: "Copy the fieldName exactly from the input.")
  var fieldName: String
  @Guide(description: "A short, clear question label. Never include or invent an answer.")
  var label: String
  @Guide(description: "One of: text, multiline, email, phone, date, number, checkBox, choice.")
  var kind: String
  @Guide(description: "A short section heading such as Personal details, Address, or Declarations.")
  var section: String
}

@available(iOS 26.0, *)
@Generable
private struct QPdfSemanticBatch {
  var suggestions: [QPdfSemanticSuggestion]
}
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let launchDocumentChannelName = "studio.gaurav.qpdf/launch_document"
  private static let smartFormAIChannelName = "studio.gaurav.qpdf/smart_form_ai"
  private static var pendingDocumentURL: URL?
  private var launchDocumentChannel: FlutterMethodChannel?
  private var smartFormAIChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: Self.launchDocumentChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getInitialDocument" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(Self.consumePendingDocument())
    }
    launchDocumentChannel = channel

    let aiChannel = FlutterMethodChannel(
      name: Self.smartFormAIChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    aiChannel.setMethodCallHandler { call, result in
      guard call.method == "analyzeFormFields",
            let fields = call.arguments as? [[String: Any]] else {
        result(FlutterMethodNotImplemented)
        return
      }
      Self.analyzeFormFields(fields, result: result)
    }
    smartFormAIChannel = aiChannel
  }

  private static func analyzeFormFields(
    _ fields: [[String: Any]],
    result: @escaping FlutterResult
  ) {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
      result(["status": "unavailable", "reason": "Apple on-device intelligence requires iOS 26 or later."])
      return
    }
    let model = SystemLanguageModel.default
    guard case .available = model.availability else {
      result(["status": "unavailable", "reason": foundationModelUnavailableReason(model.availability)])
      return
    }
    let metadata = fields.prefix(40).compactMap { field -> String? in
      guard let name = field["fieldName"] as? String,
            let label = field["label"] as? String,
            let kind = field["kind"] as? String else { return nil }
      let required = (field["required"] as? Bool) == true ? "required" : "optional"
      return "fieldName=\(name) | label=\(label) | kind=\(kind) | \(required)"
    }.joined(separator: "\n")
    let instructions = """
      Organize PDF form-field metadata into clear questions. Return exactly one suggestion for each input field and copy every fieldName exactly. You may improve only label, kind, and section. Never create fields, answers, personal data, signatures, coordinates, or instructions to submit or save a document.
      """
    let prompt = "Organize these fields:\n\(metadata)"
    Task {
      do {
        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(
          to: prompt,
          generating: QPdfSemanticBatch.self
        )
        let suggestions: [[String: Any]] = response.content.suggestions.map {
          [
            "fieldName": $0.fieldName,
            "label": $0.label,
            "kind": $0.kind,
            "section": $0.section,
          ]
        }
        await MainActor.run {
          result(["status": "available", "suggestions": suggestions])
        }
      } catch {
        await MainActor.run {
          result(["status": "unavailable", "reason": "Apple on-device intelligence could not analyze this form."])
        }
      }
    }
#else
    result(["status": "unavailable", "reason": "No compatible system model is installed."])
#endif
  }

#if canImport(FoundationModels)
  @available(iOS 26.0, *)
  private static func foundationModelUnavailableReason(
    _ availability: SystemLanguageModel.Availability
  ) -> String {
    switch availability {
    case .available:
      return ""
    case .unavailable(.deviceNotEligible):
      return "This device does not support Apple on-device intelligence."
    case .unavailable(.appleIntelligenceNotEnabled):
      return "Apple Intelligence is not enabled in Settings."
    case .unavailable(.modelNotReady):
      return "The Apple on-device model is not ready yet."
    @unknown default:
      return "Apple on-device intelligence is unavailable."
    }
  }
#endif

  static func acceptDocumentURL(_ url: URL) {
    pendingDocumentURL = url
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let channel = appDelegate.launchDocumentChannel,
          let document = consumePendingDocument() else { return }
    channel.invokeMethod("documentOpened", arguments: document)
  }

  private static func consumePendingDocument() -> [String: Any]? {
    guard let url = pendingDocumentURL else { return nil }
    pendingDocumentURL = nil
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
    }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return [
      "id": url.absoluteString,
      "name": url.lastPathComponent.isEmpty ? "Document.pdf" : url.lastPathComponent,
      "bytes": FlutterStandardTypedData(bytes: data),
    ]
  }
}
