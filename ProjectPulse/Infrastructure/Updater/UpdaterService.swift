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
private final class AppcastParser: NSObject, XMLParserDelegate {
    private let xmlParser: XMLParser
    private(set) var latestBuildNumber: String? = nil
    private(set) var latestShortVersion: String? = nil
    private var bestBuild = 0

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
        guard
            elementName == "enclosure",
            let buildString = attributeDict["sparkle:version"],
            let build = Int(buildString),
            build > bestBuild
        else { return }
        bestBuild = build
        latestBuildNumber = buildString
        latestShortVersion = attributeDict["sparkle:shortVersionString"]
    }
}
