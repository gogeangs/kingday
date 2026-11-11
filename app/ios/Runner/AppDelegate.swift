import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let r = engineBridge.pluginRegistry.registrar(forPlugin: "KdAppleSignIn") {
      KdAppleSignIn.register(r)
    }
  }
}

/// 애플 로그인 (lib/game/login.dart 의 kd/apple_sign_in).
/// 아이패드에서 로그인 창이 뜨지 않던 문제(2026-11-02 애플 심사 2.1(a)) 때문에
/// 창을 띄울 화면(지금 켜져 있는 장면의 window)을 직접 정해 준다.
final class KdAppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  private static var current: KdAppleSignIn?
  private let result: FlutterResult
  private var controller: ASAuthorizationController?

  private init(result: @escaping FlutterResult) {
    self.result = result
  }

  static func register(_ registrar: FlutterPluginRegistrar) {
    let ch = FlutterMethodChannel(name: "kd/apple_sign_in", binaryMessenger: registrar.messenger())
    ch.setMethodCallHandler { call, result in
      guard call.method == "signIn" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let old = current {
        old.finish(FlutterError(code: "canceled", message: "새 로그인 시작", details: nil))
      }
      let nonce = (call.arguments as? [String: Any])?["nonce"] as? String
      let s = KdAppleSignIn(result: result)
      current = s
      s.start(nonce: nonce)
    }
  }

  private func start(nonce: String?) {
    let req = ASAuthorizationAppleIDProvider().createRequest()
    req.requestedScopes = [.email]
    req.nonce = nonce
    let c = ASAuthorizationController(authorizationRequests: [req])
    c.delegate = self
    c.presentationContextProvider = self
    controller = c
    c.performRequests()
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    if let w = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first {
      return w
    }
    if let scene = scene {
      return UIWindow(windowScene: scene)
    }
    return ASPresentationAnchor()
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    if let c = authorization.credential as? ASAuthorizationAppleIDCredential,
       let t = c.identityToken,
       let s = String(data: t, encoding: .utf8) {
      finish(s)
    } else {
      finish(FlutterError(code: "no_token", message: "애플 토큰 없음", details: nil))
    }
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    let code = (error as? ASAuthorizationError)?.code
    if code == .canceled {
      finish(FlutterError(code: "canceled", message: error.localizedDescription, details: nil))
    } else {
      finish(FlutterError(code: "error_\(code?.rawValue ?? -1)", message: error.localizedDescription, details: nil))
    }
  }

  private func finish(_ value: Any?) {
    if controller == nil && KdAppleSignIn.current !== self { return }
    result(value)
    controller = nil
    if KdAppleSignIn.current === self { KdAppleSignIn.current = nil }
  }
}
