import Flutter
import UIKit

/// Shows the app's one engine on the screen.
///
/// The engine is made in AppDelegate, so a widget button can start it with no
/// scene. This delegate puts a Flutter view on that same engine when the
/// listener opens the app. It builds the window itself, because a storyboard
/// would make a second engine.
///
/// It stays a FlutterSceneDelegate, so the plugins that listen for the scene
/// (links the widget opens, quick actions) hear it as before.
@objc(SceneDelegate)
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // The window comes first. Flutter ties an engine to the scene when its
    // view is in a window, and the plugins hear the launch link after that.
    if let windowScene = scene as? UIWindowScene,
      let engine = (UIApplication.shared.delegate as? AppDelegate)?.sharedEngine
    {
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = FlutterViewController(
        engine: engine,
        nibName: nil,
        bundle: nil
      )
      self.window = window
      window.makeKeyAndVisible()
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
