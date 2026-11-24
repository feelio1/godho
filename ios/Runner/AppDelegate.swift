import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
  }
}
