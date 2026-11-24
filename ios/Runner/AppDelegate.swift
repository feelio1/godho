import AppTrackingTransparency
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 앱 추적 투명성(ATT) 통로 — 새 패키지 없이 이 통로 하나로 상태 확인·요청만 한다
  /// (iOS 출시 준비 L-5). 언제 물을지는 Dart(lib/ads/tracking_consent.dart)가 정한다.
  private var trackingChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 로컬 알림(flutter_local_notifications): 앱이 앞에 떠 있을 때 알림을 보여 주고
    // 탭을 앱으로 전달하려면 알림 센터 대리자가 앱이어야 한다. 권한은 여기서 묻지
    // 않는다 — 예약 알림·일기 알림을 처음 켤 때만 묻는다(iOS 출시 준비 L-4).
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "petcli/tracking",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "status":
        result(AppDelegate.trackingStatusName(ATTrackingManager.trackingAuthorizationStatus))
      case "request":
        ATTrackingManager.requestTrackingAuthorization { status in
          DispatchQueue.main.async {
            result(AppDelegate.trackingStatusName(status))
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    trackingChannel = channel
  }

  private static func trackingStatusName(_ status: ATTrackingManager.AuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .restricted:
      return "restricted"
    case .denied:
      return "denied"
    case .authorized:
      return "authorized"
    @unknown default:
      return "unknown"
    }
  }
}
