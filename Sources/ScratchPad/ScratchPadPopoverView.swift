import AppKit
import SwiftUI

struct ScratchPadPopoverView: View {
    @ObservedObject var store: ScratchPadStore
    var onHeightChange: (CGFloat) -> Void = { _ in }
    @State private var draftText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            composer
            if !store.snippets.isEmpty {
                Divider()
                snippetList
            }
        }
        .padding(12)
        .frame(width: 320, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: PopoverContentHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(PopoverContentHeightKey.self, perform: onHeightChange)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScratchPadInputTextView(
                text: $draftText,
                placeholder: "Scratch something down...",
                onCommandReturn: saveDraft
            )
            .frame(minHeight: 70, maxHeight: 110)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            Button(action: saveDraft) {
                Text("Save")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var snippetList: some View {
        Group {
            if store.snippets.count <= 3 {
                VStack(spacing: 10) {
                    snippetCards
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        snippetCards
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: 330)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var snippetCards: some View {
        ForEach(Array(store.snippets.enumerated()), id: \.offset) { index, snippet in
            SnippetCardView(
                text: snippet,
                onCopy: { copy(snippet) },
                onDelete: { store.delete(at: index) }
            )
        }
    }

    private func saveDraft() {
        store.add(draftText)
        draftText = ""
    }

    private func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

private struct PopoverContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScratchPadInputTextView: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onCommandReturn: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.placeholder = placeholder
        textView.onCommandReturn = onCommandReturn
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PlaceholderTextView else { return }
        textView.placeholder = placeholder
        textView.onCommandReturn = onCommandReturn

        if textView.string != text {
            textView.string = text
        }
        textView.needsDisplay = true
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private final class PlaceholderTextView: NSTextView {
    var placeholder: String = "" {
        didSet { needsDisplay = true }
    }

    var onCommandReturn: (() -> Void)?

    init() {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        super.init(frame: .zero, textContainer: textContainer)

        isRichText = false
        importsGraphics = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        allowsUndo = true

        font = .systemFont(ofSize: 13)
        textColor = .labelColor
        insertionPointColor = .controlAccentColor
        backgroundColor = .clear
        drawsBackground = false

        isHorizontallyResizable = false
        isVerticallyResizable = true
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        minSize = .zero
        autoresizingMask = [.width]

        textContainerInset = NSSize(width: 6, height: 7)
        textContainer.lineFragmentPadding = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command), event.charactersIgnoringModifiers == "\r" {
            onCommandReturn?()
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty else { return }

        let placeholderFont = font ?? NSFont.systemFont(ofSize: 13)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: placeholderFont,
            .foregroundColor: NSColor.placeholderTextColor
        ]

        let x = textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0)
        let y = textContainerInset.height
        let width = max(0, bounds.width - x - textContainerInset.width)
        let lineHeight = placeholderFont.ascender - placeholderFont.descender + placeholderFont.leading
        let height = lineHeight + 2
        let rect = NSRect(x: x, y: y, width: width, height: height)

        (placeholder as NSString).draw(in: rect, withAttributes: attributes)
    }
}

private struct SnippetCardView: View {
    let text: String
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copy")

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Delete")

                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
