import Flutter
import UIKit
import VisionKit

@main
@objc class AppDelegate: FlutterAppDelegate, VNDocumentCameraViewControllerDelegate {
  private let scannerChannelName = "semkosnap/document_scanner"
  private var pendingScanResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let scannerChannel = FlutterMethodChannel(
        name: scannerChannelName,
        binaryMessenger: controller.binaryMessenger
      )

      scannerChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "startScan" else {
          result(FlutterMethodNotImplemented)
          return
        }

        self?.startScan(result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startScan(result: @escaping FlutterResult) {
    guard pendingScanResult == nil else {
      result(FlutterError(code: "busy", message: "Der Scanner ist bereits geöffnet.", details: nil))
      return
    }

    guard #available(iOS 13.0, *) else {
      result(FlutterError(code: "unavailable", message: "Der Dokumentenscanner benötigt mindestens iOS 13.", details: nil))
      return
    }

    guard VNDocumentCameraViewController.isSupported else {
      result(FlutterError(code: "unavailable", message: "Der Dokumentenscanner wird auf diesem Gerät nicht unterstützt.", details: nil))
      return
    }

    guard let presenter = topViewController(from: window?.rootViewController) else {
      result(FlutterError(code: "unavailable", message: "Der Scanner konnte nicht gestartet werden.", details: nil))
      return
    }

    let scanner = VNDocumentCameraViewController()
    scanner.delegate = self
    pendingScanResult = result
    presenter.present(scanner, animated: true)
  }

  private func topViewController(from root: UIViewController?) -> UIViewController? {
    if let navigationController = root as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }

    if let tabBarController = root as? UITabBarController {
      return topViewController(from: tabBarController.selectedViewController)
    }

    if let presentedViewController = root?.presentedViewController {
      return topViewController(from: presentedViewController)
    }

    return root
  }

  private func completeScan(withPath path: String) {
    pendingScanResult?(path)
    pendingScanResult = nil
  }

  private func completeScanWithError(code: String, message: String) {
    pendingScanResult?(FlutterError(code: code, message: message, details: nil))
    pendingScanResult = nil
  }

  private func persistScannedImage(_ image: UIImage) throws -> String {
    guard let imageData = image.jpegData(compressionQuality: 0.95) else {
      throw NSError(domain: "semkosnap.document_scanner", code: 1001, userInfo: [
        NSLocalizedDescriptionKey: "Das gescannte Bild konnte nicht gespeichert werden."
      ])
    }

    let fileName = "semkosnap_scan_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
    let fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    try imageData.write(to: fileUrl, options: .atomic)
    return fileUrl.path
  }

  @available(iOS 13.0, *)
  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true) { [weak self] in
      self?.completeScanWithError(code: "cancelled", message: "Der Dokumentenscan wurde abgebrochen.")
    }
  }

  @available(iOS 13.0, *)
  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFailWithError error: Error
  ) {
    controller.dismiss(animated: true) { [weak self] in
      self?.completeScanWithError(code: "scan_failed", message: error.localizedDescription)
    }
  }

  @available(iOS 13.0, *)
  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFinishWith scan: VNDocumentCameraScan
  ) {
    controller.dismiss(animated: true) { [weak self] in
      guard let self else { return }

      guard scan.pageCount > 0 else {
        self.completeScanWithError(code: "scan_failed", message: "Der Scanner hat kein Bild zurückgegeben.")
        return
      }

      do {
        let image = scan.imageOfPage(at: 0)
        let outputPath = try self.persistScannedImage(image)
        self.completeScan(withPath: outputPath)
      } catch {
        self.completeScanWithError(code: "scan_failed", message: error.localizedDescription)
      }
    }
  }
}
