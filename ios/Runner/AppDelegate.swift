import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import WidgetKit

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
      
      // Setup widget data method channel
      let widgetChannel = FlutterMethodChannel(
        name: "widget_channel",
        binaryMessenger: controller.binaryMessenger
      )
      widgetChannel.setMethodCallHandler { (call, result) in
        self.handleWidgetMethodCall(call: call, result: result)
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
  
  // Handle custom URL schemes (deep links)
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("📱 iOS Deep link received: \(url)")
    print("📱 URL Scheme: \(url.scheme ?? "none")")
    print("📱 URL Host: \(url.host ?? "none")")
    
    // Handle widget deep link directly via MethodChannel (same as Android)
    if url.scheme == "cue" && url.host == "create-reminder" {
      print("📱 Handling create-reminder via MethodChannel")
      
      // Get Flutter view controller and call the navigation channel
      if let controller = window?.rootViewController as? FlutterViewController {
        let navigationChannel = FlutterMethodChannel(
          name: "navigation_channel",
          binaryMessenger: controller.binaryMessenger
        )
        navigationChannel.invokeMethod("navigateToCreateReminder", arguments: nil)
      }
      
      return true
    }
    
    // Let the app_links plugin handle other links
    return super.application(app, open: url, options: options)
  }
  
  func registerNotificationCategories() {
    let doneAction = UNNotificationAction(
      identifier: "mark_done",
      title: "Done",
      options: [.foreground]
    )
    
    let snooze5Action = UNNotificationAction(
      identifier: "snooze_5",
      title: "Snooze 5 min",
      options: []
    )
    
    // Text input action for custom snooze duration
    let snoozeCustomInputAction = UNTextInputNotificationAction(
      identifier: "snooze_input",
      title: "Custom",
      options: [],
      textInputButtonTitle: "Snooze",
      textInputPlaceholder: "Enter minutes"
    )
    
    let reminderCategory = UNNotificationCategory(
      identifier: "reminder_category",
      actions: [doneAction, snooze5Action, snoozeCustomInputAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )
    
    UNUserNotificationCenter.current().setNotificationCategories([reminderCategory])
    print("✅ Notification categories registered with custom snooze input")
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
    
    // Handle text input for custom snooze
    if let textResponse = response as? UNTextInputNotificationResponse,
       actionIdentifier == "snooze_input" {
      let userInput = textResponse.userText
      print("📱 User entered custom snooze: \(userInput) minutes")
      
      if let reminderId = userInfo["reminderId"] as? String {
        // Send the custom minutes along with the action
        NotificationActionStreamHandler.sendActionWithInput(
          action: actionIdentifier,
          reminderId: reminderId,
          userInput: userInput
        )
        
        // Dismiss notification
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
      }
    }
    // Handle custom actions (mark_done, snooze presets)
    else if actionIdentifier == "mark_done" || actionIdentifier.starts(with: "snooze") {
      // Extract reminderId from userInfo
      if let reminderId = userInfo["reminderId"] as? String {
        print("📱 Processing action '\(actionIdentifier)' for reminder: \(reminderId)")
        
        // Send event to Flutter via EventChannel
        NotificationActionStreamHandler.sendAction(
          action: actionIdentifier,
          reminderId: reminderId
        )
        
        // Dismiss notification for quick snooze actions (not custom)
        if actionIdentifier != "snooze_custom" {
          UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
        }
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
  
  static func sendActionWithInput(action: String, reminderId: String, userInput: String) {
    guard let sink = eventSink else {
      print("❌ No event sink available")
      return
    }
    
    let event: [String: String] = [
      "action": action,
      "reminderId": reminderId,
      "userInput": userInput
    ]
    
    print("📱 Sending action with input to Flutter: \(event)")
    sink(event)
  }
}
// MARK: - Widget Support
extension AppDelegate {
  func handleWidgetMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "updateWidgetData":
      if let args = call.arguments as? [String: Any],
         let jsonString = args["data"] as? String {
        updateWidgetData(jsonString: jsonString)
        result(true)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      }
    case "reloadWidget":
      reloadWidget()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  func updateWidgetData(jsonString: String) {
    let userDefaults = UserDefaults(suiteName: "group.com.cue.app")
    
    // Convert JSON string to Data
    if let jsonData = jsonString.data(using: .utf8) {
      userDefaults?.set(jsonData, forKey: "todayReminders")
      userDefaults?.synchronize()
      print("✅ Widget data updated in App Group with \(jsonData.count) bytes")
      
      // Debug: Print what we're storing
      if let storedData = userDefaults?.data(forKey: "todayReminders"),
         let storedString = String(data: storedData, encoding: .utf8) {
        print("📊 Stored data: \(storedString)")
      }
    } else {
      print("❌ Failed to convert JSON string to data")
    }
  }
  
  func reloadWidget() {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
      print("📱 Widget timelines reloaded")
    }
  }
}