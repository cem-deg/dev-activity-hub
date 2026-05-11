import Foundation
import Sparkle

final class UpdaterService: ObservableObject {
    private let controller: SPUStandardUpdaterController

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var isUpdateAvailable = false
    @Published private(set) var latestVersion: String? = nil

    private var observation: NSKeyValueObservation?
    private var notifiedBuildNumber: String? = nil

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckForUpdates = controller.updater.canCheckForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] updater, _ in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.fetchAppcastSilently()
        }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    func checkForUpdatesInBackground() {
        fetchAppcastSilently()
    }

    private func fetchAppcastSilently() {
        guard
            let feedURLString = Bundle.main.infoDictionary?["SUFeedURL"] as? String,
            let feedURL = URL(string: feedURLString),
            let currentBuildString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
            let currentBuild = Int(currentBuildString)
        else { return }

        URLSession.shared.dataTask(with: feedURL) { [weak self] data, _, _ in
            guard let data else { return }
            let parser = AppcastParser(data: data)
            guard
                let remoteBuildString = parser.latestBuildNumber,
                let remoteBuild = Int(remoteBuildString)
            else { return }
            DispatchQueue.main.async {
                let updateFound = remoteBuild > currentBuild
                self?.isUpdateAvailable = updateFound
                self?.latestVersion = parser.latestShortVersion
                if updateFound, self?.notifiedBuildNumber != remoteBuildString {
                    self?.notifiedBuildNumber = remoteBuildString
                    ActivityNotifier.notifyUpdateAvailable(version: parser.latestShortVersion)
                }
            }
        }.resume()
    }
}

// Parses a Sparkle appcast and finds the entry with the highest sparkle:version (build number).
// Mirrors how Sparkle itself selects the best update candidate.
//
// Version metadata may appear as item-level sibling elements (current appcast format):
//   <sparkle:version>7</sparkle:version>
//   <sparkle:shortVersionString>1.4.1</sparkle:shortVersionString>
// or as enclosure attributes (alternative Sparkle format):
//   <enclosure sparkle:version="7" sparkle:shortVersionString="1.4.1" .../>
// Both are handled; item-level elements take priority over enclosure attributes.
private final class AppcastParser: NSObject, XMLParserDelegate {
    private let xmlParser: XMLParser
    private(set) var latestBuildNumber: String? = nil
    private(set) var latestShortVersion: String? = nil
    private var bestBuild = 0

    // Per-item accumulation state, reset on each <item> open.
    private var itemBuild: String? = nil
    private var itemShortVersion: String? = nil
    private var currentElement = ""
    private var capturedText = ""

    init(data: Data) {
        xmlParser = XMLParser(data: data)
        super.init()
        xmlParser.delegate = self
        xmlParser.parse()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        capturedText = ""

        switch elementName {
        case "item":
            itemBuild = nil
            itemShortVersion = nil
        case "enclosure":
            // Item-level elements take priority; fall back to enclosure attributes.
            let buildString = itemBuild ?? attributeDict["sparkle:version"]
            let shortVersion = itemShortVersion ?? attributeDict["sparkle:shortVersionString"]
            guard
                let buildString,
                let build = Int(buildString),
                build > bestBuild
            else { return }
            bestBuild = build
            latestBuildNumber = buildString
            latestShortVersion = shortVersion
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        capturedText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = capturedText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "sparkle:version":
            itemBuild = text.isEmpty ? nil : text
        case "sparkle:shortVersionString":
            itemShortVersion = text.isEmpty ? nil : text
        default:
            break
        }
        capturedText = ""
    }
}
