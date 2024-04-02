import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let tmpPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first! + "/origin.mp4"
        let tmpURL = URL(filePath: tmpPath)
        try? FileManager.default.removeItem(at: tmpURL)
        try? FileManager.default.copyItem(at: Bundle.main.url(forResource: "origin", withExtension: "mp4")!, to: tmpURL)
        
        LivePhotoUtil.convertVideo(tmpPath) { success, msg in
            print(msg ?? "")
        }
    }


}

