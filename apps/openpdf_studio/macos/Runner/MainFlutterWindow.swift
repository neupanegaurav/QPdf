import Cocoa
import FlutterMacOS
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
private struct QPdfMacSemanticSuggestion {
  @Guide(description: "Copy the fieldName exactly from the input.")
  var fieldName: String
  @Guide(description: "A short, clear question label. Never include or invent an answer.")
  var label: String
  @Guide(description: "One of: text, multiline, email, phone, date, number, checkBox, choice.")
  var kind: String
  @Guide(description: "A short section heading such as Personal details, Address, or Declarations.")
  var section: String
}

@available(macOS 26.0, *)
@Generable
private struct QPdfMacSemanticBatch {
  var suggestions: [QPdfMacSemanticSuggestion]
}
#endif

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let aiChannel = FlutterMethodChannel(
      name: "studio.gaurav.qpdf/smart_form_ai",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    aiChannel.setMethodCallHandler { call, result in
      guard call.method == "analyzeFormFields",
            let fields = call.arguments as? [[String: Any]] else {
        result(FlutterMethodNotImplemented)
        return
      }
      Self.analyzeFormFields(fields, result: result)
    }

    super.awakeFromNib()
  }

  private static func analyzeFormFields(
    _ fields: [[String: Any]],
    result: @escaping FlutterResult
  ) {
#if canImport(FoundationModels)
    guard #available(macOS 26.0, *) else {
      result(["status": "unavailable", "reason": "Apple on-device intelligence requires macOS 26 or later."])
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
    Task {
      do {
        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(
          to: "Organize these fields:\n\(metadata)",
          generating: QPdfMacSemanticBatch.self
        )
        let suggestions: [[String: Any]] = response.content.suggestions.map {
          ["fieldName": $0.fieldName, "label": $0.label, "kind": $0.kind, "section": $0.section]
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
  @available(macOS 26.0, *)
  private static func foundationModelUnavailableReason(
    _ availability: SystemLanguageModel.Availability
  ) -> String {
    switch availability {
    case .available:
      return ""
    case .unavailable(.deviceNotEligible):
      return "This Mac does not support Apple on-device intelligence."
    case .unavailable(.appleIntelligenceNotEnabled):
      return "Apple Intelligence is not enabled in System Settings."
    case .unavailable(.modelNotReady):
      return "The Apple on-device model is not ready yet."
    @unknown default:
      return "Apple on-device intelligence is unavailable."
    }
  }
#endif
}
