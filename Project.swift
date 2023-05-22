import UIKit
import Alamofire
import SwiftyJSON
import SVProgressHUD
import QRCodeReader

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, QRCodeReaderViewControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    var tasks: [Task] = []
    var filteredTasks: [Task] = []
    var isSearching: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        authenticateAndLoadData()
    }
    
    func authenticateAndLoadData() {
        SVProgressHUD.show()
        
        let headers: HTTPHeaders = [
            "Authorization": "Basic QVBJX0V4cGxvcmVyOjEyMzQ1NmlzQUxhbWVQYXNz",
            "Content-Type": "application/json"
        ]
        
        let parameters: [String: Any] = [
            "username": "365",
            "password": "1"
        ]
        
        guard let loginURL = URL(string: "https://api.baubuddy.de/index.php/login") else {
            SVProgressHUD.dismiss()
            return
        }
        
        AF.request(loginURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    
                    if let token = json["token"].string {
                        self.loadData(withToken: token)
                    } else {
                        print("Token not found in response")
                        SVProgressHUD.dismiss()
                    }
                case .failure(let error):
                    print("Error: \(error)")
                    SVProgressHUD.dismiss()
                }
            }
    }
    
    func loadData(withToken token: String) {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)"
        ]
        
        guard let url = URL(string: "https://api.baubuddy.de/dev/index.php/v1/tasks/select") else {
            SVProgressHUD.dismiss()
            return
        }
        
        AF.request(url, headers: headers).responseJSON { response in
            SVProgressHUD.dismiss()
            
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                self.parseData(json: json)
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }
    func parseData(json: JSON) {
        tasks.removeAll()
        
        for (_, taskJson) in json {
            let task = Task(json: taskJson)
            tasks.append(task)
        }
        
        filteredTasks = tasks
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func filterContentForSearchText(_ searchText: String) {
        filteredTasks = tasks.filter { (task: Task) -> Bool in
            return task.title.lowercased().contains(searchText.lowercased()) ||
                task.description.lowercased().contains(searchText.lowercased()) ||
                task.task.lowercased().contains(searchText.lowercased()) ||
                task.colorCode.lowercased().contains(searchText.lowercased())
        }
        
        tableView.reloadData()
    }
    
    func readerDidCancel(_ reader: QRCodeReaderViewController) {
        reader.dismiss(animated: true, completion: nil)
    }
    
    func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        reader.dismiss(animated: true, completion: nil)
        
        searchBar.text = result.value
        filterContentForSearchText(result.value)
    }
    
    @IBAction func scanQRCode(_ sender: UIBarButtonItem) {
        guard let reader = QRCodeReaderViewController(metadataObjectTypes: [.qr], captureDevicePosition: .back) else { return }
        
        reader.modalPresentationStyle = .formSheet
        reader.delegate = self
        
        present(reader, animated: true, completion: nil)
    }
    
    // MARK: - UITableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredTasks.count : tasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let task = isSearching ? filteredTasks[indexPath.row] : tasks[indexPath.row]
        
        cell.textLabel?.text = task.title
        cell.detailTextLabel?.text = task.description
        cell.backgroundColor = UIColor(hexString: task.colorCode)
        
        return cell
    }
}

extension ViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            tableView.reloadData()
        } else {
            isSearching = true
            filterContentForSearchText(searchText)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

struct Task {
    let task: String
    let title: String
    let description: String
    let colorCode: String
    
    init(json: JSON) {
        task = json["task"].stringValue
        title = json["title"].stringValue
        description = json["description"].stringValue
        colorCode = json["colorCode"].stringValue
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
