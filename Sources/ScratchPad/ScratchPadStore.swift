import Foundation
import Combine

@MainActor
final class ScratchPadStore: ObservableObject {
    @Published private(set) var snippets: [String] = []

    private let defaults: UserDefaults
    private let storageKey = "scratchpad.snippets.json"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ rawText: String) {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        snippets.insert(rawText, at: 0)
        persist()
    }

    func delete(at index: Int) {
        guard snippets.indices.contains(index) else { return }
        snippets.remove(at: index)
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            snippets = []
            return
        }

        do {
            snippets = try JSONDecoder().decode([String].self, from: data)
        } catch {
            snippets = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(snippets)
            defaults.set(data, forKey: storageKey)
        } catch {
            // Intentionally ignore persistence failures to keep the UI responsive.
        }
    }
}
