import SwiftUI
import GoogleMobileAds

@main
struct CatchTheKnifeApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  var body: some Scene {
    WindowGroup {
      MainView()
    }
  }
}
