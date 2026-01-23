import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var eventSink: FlutterEventSink?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup event channel for notification actions
    if let controller = window?.rootViewController as? FlutterViewController {
      let eventChannel = FlutterEventChannel(
        name: "notification_action_channel",
        binaryMessenger: controller.binaryMessenger
      )
      eventChannel.setStreamHandler(NotificationActionStreamHandler())
    }
    
    registerNotificationCategories()
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    Messaging.messaging().delegate = self
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func registerNotificationCategories() {
    let doneAction = UNNotificationAction(
      identifier: "mark_done",
      title: "Done",
      options: [.foreground]
    )
    
    let snoozeAction = UNNotificationAction(
      identifier: "snooze",
      title: "Snooze",
      options: [.foreground]
    )
    
    let reminderCategory = UNNotificationCategory(
      identifier: "reminder_category",
      actions: [doneAction, snoozeAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )
    
    UNUserNotificationCenter.current().setNotificationCategories([reminderCategory])
    print("✅ Notification categories registered")
  }
  
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    print("APNs token retrieved")
  }
  
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register: \(error)")
  }
}

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("FCM token: \(String(describing: fcmToken))")
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}

extension AppDelegate {
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("📱 Foreground notification: \(userInfo)")
    
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    let actionIdentifier = response.actionIdentifier
    
    print("📱 Notification Action Received")
    print("📱 Action: \(actionIdentifier)")
    print("📱 UserInfo: \(userInfo)")
    
    // Handle custom actions (mark_done, snooze)
    if actionIdentifier == "mark_done" || actionIdentifier == "snooze" {
      // Extract reminderId from userInfo
      if let reminderId = userInfo["reminderId"] as? String {
        print("📱 Processing action '\(actionIdentifier)' for reminder: \(reminderId)")
        
        // Send event to Flutter via EventChannel
        NotificationActionStreamHandler.sendAction(
          action: actionIdentifier,
          reminderId: reminderId
        )
      }
    }
    
    completionHandler()
  }
}

// StreamHandler for notification actions
class NotificationActionStreamHandler: NSObject, FlutterStreamHandler {
  private static var eventSink: FlutterEventSink?
  
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    NotificationActionStreamHandler.eventSink = events
    print("📱 Event channel listener attached")
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationActionStreamHandler.eventSink = nil
    print("📱 Event channel listener detached")
    return nil
  }
  
  static func sendAction(action: String, reminderId: String) {
    guard let sink = eventSink else {
      print("❌ No event sink available")
      return
    }
    
    let event: [String: String] = [
      "action": action,
      "reminderId": reminderId
    ]
    
    print("📱 Sending action to Flutter: \(event)")
    sink(event)
  }
}