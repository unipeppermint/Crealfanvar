import UIKit

final class ViewController: UIViewController {
    private var coordinator: CFVAppCoordinator?

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = CFVTheme.paper
        let navigation = UINavigationController()
        addChild(navigation)
        navigation.view.frame = view.bounds
        navigation.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigation.view)
        navigation.didMove(toParent: self)
        do {
            let app = try CFVAppCoordinator(navigation: navigation)
            coordinator = app
            app.home()
        } catch {
            let label = CFVTheme.label(CFVText("无法读取关卡资源。请重新安装应用，或联系支持。", "Level resources could not be loaded. Reinstall the app or contact support."))
            label.frame = view.bounds.insetBy(dx: 32, dy: 100)
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(label)
        }
    }
}
