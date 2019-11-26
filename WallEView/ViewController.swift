import Cocoa

extension NSStoryboard {
    static var main: NSStoryboard {
        NSStoryboard(name: "Main", bundle: nil)
    }
    func viewController<T: NSViewController>() -> T? {
        return instantiateController(withIdentifier: String(describing: T.self)) as? T
    }
}

extension NSTableView {
    func makeCell<T: NSTableCellView>() -> T? {
        return makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: String(describing: T.self)), owner: nil) as? T
    }
}

class PullRequestCell: NSTableCellView {
    @IBOutlet weak var title: NSTextField!
    @IBOutlet weak var subtitle: NSTextField!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var tableViewContainer: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var backgroundImage: NSImageView!
    @IBOutlet weak var backgroundLabel: NSTextField!
    @IBOutlet weak var background: NSView! {
        didSet {
            background.isHidden = true
        }
    }
    
    private var state: State? {
        didSet {
            tableView.reloadData()

            let hideContent = state?.isIdle == true || state?.isFailing == true
            background.isHidden = !hideContent
            tableViewContainer.isHidden = hideContent

            if state?.isFailing == true {
                backgroundImage.image = #imageLiteral(resourceName: "foot")
                backgroundLabel.stringValue = "Something failin':\n\n\(state?.error.map(String.init(describing:)) ?? "")"
            } else {
                backgroundImage.image = #imageLiteral(resourceName: "green")
                backgroundLabel.stringValue = "Doin' nothin', just chillin'"
            }
        }
    }

    struct State {
        struct Current: Decodable {
            let reference: PullRequest
        }
        let current: Current?
        let queue: [PullRequest]
        let error: Error?

        var pullRequests: [PullRequest] {
            if let current = current {
                return [current.reference] + queue
            } else {
                return queue
            }
        }

        // TODO: actually parse status
        var isIdle: Bool { queue.count == 0 && current == nil }
        var isFailing: Bool { error != nil }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return state?.pullRequests.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell: PullRequestCell? = tableView.makeCell()
        let pullRequest = state!.pullRequests[row]
        cell?.title.stringValue = pullRequest.title
        cell?.subtitle.stringValue = "#\(pullRequest.number) by \(pullRequest.author.login)"
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateState()
    }

    func updateState() {
        guard let host = UserDefaults.standard.string(forKey: "Host") else {
            state = State(current: nil, queue: [], error: "No host set")
            return
        }

        var request = URLRequest(url: URL(string: host)!)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
            DispatchQueue.main.async {
                if let data = data {
                    do {
                        let state = try JSONDecoder().decode(State.self, from: data)
                        self?.state = state
                    } catch {
                        self?.state = State(current: nil, queue: [], error: error)
                    }
                } else {
                    self?.state = State(current: nil, queue: [], error: error)
                }
            }
        }).resume()
    }
}

extension String: Error, LocalizedError {
    public var localizedDescription: String { self }
}

extension ViewController.State: Decodable {
    enum CodingKeys: String, CodingKey {
        case status, queue, metadata, reference
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let status = try values.nestedContainer(keyedBy: CodingKeys.self, forKey: .status)
        current = try status.decodeIfPresent(Current.self, forKey: .metadata)
        queue = try values.decode([PullRequest].self, forKey: .queue)
        error = nil
    }
}

