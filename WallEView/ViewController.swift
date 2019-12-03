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

class GridClipTableView: NSTableView {
    // workaround to hide separators for non populated rows
    // https://stackoverflow.com/questions/5606796/draw-grid-lines-in-nstableview-only-for-populated-rows
    override func drawGrid(inClipRect clipRect: NSRect) { }
}

class PullRequestCell: NSTableCellView {
    @IBOutlet weak var title: NSTextField!
    @IBOutlet weak var subtitle: NSTextField!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var branchSelector: NSPopUpButton!
    @IBOutlet weak var tableViewContainer: NSView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var backgroundImage: NSImageView!
    @IBOutlet weak var backgroundLabel: NSTextField!
    @IBOutlet weak var background: NSView! {
        didSet {
            background.isHidden = true
        }
    }
    
    private var state: State = .empty {
        didSet {
            tableView.reloadData()

            let hideContent = targetQueue?.isIdle == true || state.isFailing == true
            background.isHidden = !hideContent
            tableViewContainer.isHidden = hideContent

            if state.isFailing == true {
                backgroundImage.image = #imageLiteral(resourceName: "foot")
                backgroundLabel.stringValue = "Something failin':\n\n\(state.error.map(String.init(describing:)) ?? "")"
            } else {
                backgroundImage.image = #imageLiteral(resourceName: "green")
                backgroundLabel.stringValue = "Doin' nothin', just chillin'"
            }
        }
    }

    var targetQueue: Queue? {
        state.queues.first { $0.targetBranch == state.targetBranch }
    }

    struct State: Decodable {
        let queues: [Queue]
        let error: Error?
        var targetBranch: String?

        var isFailing: Bool { error != nil }

        static let empty = State(queues: [], error: nil, targetBranch: nil)
    }

    struct Queue {
        struct Current: Decodable {
            let reference: PullRequest
        }
        let targetBranch: String
        let current: Current?
        let queue: [PullRequest]

        var pullRequests: [PullRequest] {
            if let current = current {
                return [current.reference] + queue
            } else {
                return queue
            }
        }

        // TODO: actually parse status
        var isIdle: Bool { queue.count == 0 && current == nil }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return targetQueue?.pullRequests.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell: PullRequestCell? = tableView.makeCell()
        let pullRequest = targetQueue!.pullRequests[row]
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
            state = .empty
            return
        }

        var request = URLRequest(url: URL(string: host)!)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let data = data {
                    do {
                        let queues = try JSONDecoder().decode([Queue].self, from: data)
                        self.state = State(queues: queues, error: nil, targetBranch: queues.first?.targetBranch)
                        self.branchSelector.menu?.items = queues.map {
                            NSMenuItem(title: $0.targetBranch, action: #selector(self.switchBranch(_:)), keyEquivalent: "")
                        }
                    } catch {
                        self.state = State(queues: [], error: error, targetBranch: nil)
                    }
                } else {
                    self.state = State(queues: [], error: error, targetBranch: nil)
                }
            }
        }).resume()
    }

    @objc func switchBranch(_ sender: NSMenuItem) {
        state.targetBranch = sender.title
    }
}

extension String: Error, LocalizedError {
    public var localizedDescription: String { self }
}

extension ViewController.Queue: Decodable {
    enum CodingKeys: String, CodingKey {
        case status, queue, metadata, reference, targetBranch
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let status = try values.nestedContainer(keyedBy: CodingKeys.self, forKey: .status)
        current = try status.decodeIfPresent(Current.self, forKey: .metadata)
        queue = try values.decode([PullRequest].self, forKey: .queue)
        targetBranch = try values.decode(String.self, forKey: .targetBranch)
    }
}

extension ViewController.State {
    enum CodingKeys: String, CodingKey {
        case queues
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        queues = try values.decode([ViewController.Queue].self, forKey: .queues)
        error = nil
    }
}
