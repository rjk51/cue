import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var eventSink: FlutterEventSink?
  private var notificationChannel: FlutterMethodChannel?
  
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
      
      // Setup method channel for notification removal
      notificationChannel = FlutterMethodChannel(
        name: "com.example.cue/notifications",
        binaryMessenger: controller.binaryMessenger
      )
      
      notificationChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "removeNotification" {
          guard let args = call.arguments as? [String: Any],
                let reminderId = args["reminderId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "reminderId is required", details: nil))
            return
          }
          
          print("[iOS Native] Method channel called: removeNotification")
          print("[iOS Native] Reminder ID: \(reminderId)")
          self?.removeNotificationFromCenter(reminderId: reminderId)
          result(nil) // Success
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
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
  
  // Handle background/silent push notifications
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("═══════════════════════════════════════════════════════════")
    print("🔔 [iOS Native] Remote notification received")
    print("═══════════════════════════════════════════════════════════")
    print("📦 Full UserInfo: \(userInfo)")
    print("📱 App State: \(application.applicationState.rawValue) (0=active, 1=inactive, 2=background)")
    
    // Try to get type from multiple possible locations
    var notificationType: String? = nil
    var reminderId: String? = nil
    
    // Check direct userInfo (Android-style)
    if let type = userInfo["type"] as? String {
      notificationType = type
      print("📍 Found type in direct userInfo: \(type)")
    }
    
    // Check aps payload (iOS-style) 
    if let aps = userInfo["aps"] as? [String: Any] {
      print("📍 APS payload: \(aps)")
      if let type = aps["type"] as? String {
        notificationType = type
        print("📍 Found type in aps: \(type)")
      }
    }
    
    // Get reminderId from multiple locations
    if let rid = userInfo["reminderId"] as? String {
      reminderId = rid
      print("📍 Found reminderId in direct userInfo: \(rid)")
    } else if let aps = userInfo["aps"] as? [String: Any], let rid = aps["reminderId"] as? String {
      reminderId = rid
      print("📍 Found reminderId in aps: \(rid)")
    }
    
    print("───────────────────────────────────────────────────────────")
    print("🔍 Parsed values:")
    print("   - type: \(notificationType ?? "nil")")
    print("   - reminderId: \(reminderId ?? "nil")")
    print("───────────────────────────────────────────────────────────")
    
    // Check if this is a dismiss notification
    if notificationType == "dismiss_notification", let reminderIdToRemove = reminderId {
      print("🗑️ [iOS Native] DISMISS notification received for reminder: \(reminderIdToRemove)")
      removeNotificationFromCenter(reminderId: reminderIdToRemove)
      completionHandler(.newData)
    } else {
      print("ℹ️ [iOS Native] Non-dismiss notification or missing data")
      print("   - type check: \(notificationType ?? "nil") == dismiss_notification ? \(notificationType == "dismiss_notification")")
      print("   - reminderId check: \(reminderId ?? "nil")")
      completionHandler(.noData)
    }
  }
  
  // Helper method to remove notifications from notification center
  // Can be called from both native remote notification handler and Flutter method channel
  private func removeNotificationFromCenter(reminderId: String) {
    print("🗑️ [iOS Native] removeNotificationFromCenter called")
    print("   - Reminder ID: \(reminderId)")
    
    // First, try to remove directly using reminderId as identifier
    print("🔄 [iOS Native] Attempting direct removal with reminderId: \(reminderId)")
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderId])
    
    // Also remove from pending notifications
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderId])
    
    // Then search through all delivered notifications as fallback
    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
      print("📊 [iOS Native] Total delivered notifications: \(notifications.count)")
      
      var identifiersToRemove: [String] = []
      
      for notification in notifications {
        let content = notification.request.content
        let identifier = notification.request.identifier
        let notificationUserInfo = content.userInfo
        
        print("📌 Checking notification: \(identifier)")
        print("   - Title: \(content.title)")
        print("   - ThreadId: \(content.threadIdentifier)")
        
        // Check if this notification belongs to the reminder we want to dismiss
        if let notifReminderId = notificationUserInfo["reminderId"] as? String,
           notifReminderId == reminderId {
          identifiersToRemove.append(identifier)
          print("   ✅ MATCH by reminderId in userInfo! Will remove: \(identifier)")
        } else if identifier == reminderId {
          identifiersToRemove.append(identifier)
          print("   ✅ MATCH by identifier! Will remove: \(identifier)")
        } else if content.threadIdentifier == reminderId {
          identifiersToRemove.append(identifier)
          print("   ✅ MATCH by threadId! Will remove: \(identifier)")
        }
      }
      
      if !identifiersToRemove.isEmpty {
        print("🗑️ [iOS Native] Removing \(identifiersToRemove.count) additional notification(s): \(identifiersToRemove)")
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        print("✅ [iOS Native] Additional notifications removed!")
      }
      
      // Log remaining notifications after a short delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        UNUserNotificationCenter.current().getDeliveredNotifications { remaining in
          print("📊 [iOS Native] Remaining delivered notifications: \(remaining.count)")
          for n in remaining {
            print("   - ID: \(n.request.identifier), Title: \(n.request.content.title)")
          }
        }
      }
    }
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
    
    // Check if this is a dismiss notification - don't show it
    if let type = userInfo["type"] as? String, type == "dismiss_notification" {
      print("🔕 [iOS Native] Suppressing dismiss notification from display")
      completionHandler([]) // Don't show anything
      return
    }
    
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