import AppKit
import MacWorkTimerCore
import SwiftUI

struct WorkPetView: View {
    @EnvironmentObject private var model: AppModel
    @State private var dragState: PetDragState = .idle
    @State private var temporaryMessage: String?

    private var mood: PetMood {
        PetMood.mood(remaining: model.remaining)
    }

    private var visualState: PetVisualState {
        PetVisualState.make(
            remaining: model.remaining,
            elapsed: model.elapsed,
            now: model.now,
            dragState: dragState,
            temporaryMessage: temporaryMessage
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Text(visualState.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(visualState.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .liquidGlass(
                    in: Capsule(style: .continuous),
                    tint: visualState.glassTint,
                    interactive: true
                )
                .frame(maxWidth: 104)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .offset(y: 2)
                .animation(.smooth(duration: 0.18), value: visualState.label)

            spritePetBody
        }
        .frame(width: 108, height: 124)
        .contentShape(Rectangle())
        .overlay {
            PetDragSurface(
                onDragStateChanged: { newState in
                    withAnimation(.smooth(duration: 0.12)) {
                        dragState = newState
                    }
                },
                onClick: {
                    showCurrentMessage()
                }
            )
        }
        .task(id: temporaryMessage) {
            guard temporaryMessage != nil else {
                return
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.smooth(duration: 0.22)) {
                temporaryMessage = nil
            }
        }
    }

    private var spritePetBody: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let frame = PetAsset.frame(
                setName: visualState.frameSetName,
                at: time,
                duration: visualState.frameDuration
            )

            petBody(image: frame, blink: fallbackBlink(at: time))
                .offset(y: 31)
        }
    }

    private func petBody(image: NSImage?, blink: Bool) -> some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 76, height: 82)
            } else {
                fallbackPetBody(blink: blink)

                statusDot
                    .offset(x: 25, y: -23)
            }
        }
    }

    private func fallbackBlink(at time: TimeInterval) -> Bool {
        mood == .done && sin(time * .pi) > 0.82
    }

    private func fallbackPetBody(blink: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [mood.primaryColor.opacity(0.92), mood.secondaryColor.opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.46), lineWidth: 1.2)
                }

            HStack(spacing: 15) {
                PetEye(blink: blink)
                PetEye(blink: blink)
            }
            .offset(y: -7)

            PetMouth(mood: mood, blink: blink)
                .stroke(.white.opacity(0.86), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                .frame(width: 18, height: 10)
                .offset(y: 10)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(mood.accentColor)
            .frame(width: mood == .under5m ? 11 : 8, height: mood == .under5m ? 11 : 8)
            .overlay {
                Circle().stroke(.white.opacity(0.75), lineWidth: 1)
            }
    }

    private func showCurrentMessage() {
        withAnimation(.smooth(duration: 0.22)) {
            temporaryMessage = PetVisualState.clickMessage(remaining: model.remaining, elapsed: model.elapsed)
        }
    }
}

private extension PetVisualState {
    var textColor: Color {
        switch labelTone {
        case .neutral:
            return .black.opacity(0.72)
        case .warm:
            return Color(red: 0.82, green: 0.34, blue: 0.12).opacity(0.86)
        case .done:
            return Color(red: 0.10, green: 0.52, blue: 0.29).opacity(0.86)
        }
    }

    var glassTint: Color {
        switch labelTone {
        case .neutral:
            return .white.opacity(0.18)
        case .warm:
            return Color(red: 1.00, green: 0.78, blue: 0.46).opacity(0.26)
        case .done:
            return Color(red: 0.62, green: 0.95, blue: 0.72).opacity(0.26)
        }
    }
}

private enum PetAsset {
    static func frame(setName: String, at time: TimeInterval, duration: TimeInterval) -> NSImage? {
        let requestedFrames = frames(named: setName)
        let resolvedFrames = requestedFrames.isEmpty ? frames(named: "idle") : requestedFrames

        guard !resolvedFrames.isEmpty else {
            return fallbackImage
        }

        let frameDuration = max(0.05, duration)
        let frameIndex = Int((time / frameDuration).rounded(.down)) % resolvedFrames.count
        return resolvedFrames[frameIndex]
    }

    private static func frames(named setName: String) -> [NSImage] {
        cachedFrames[setName] ?? []
    }

    private static let cachedFrames: [String: [NSImage]] = {
        let names = [
            "idle",
            "working",
            "working-afternoon",
            "working-late",
            "under1h",
            "under30m",
            "under5m",
            "done",
            "drag",
            "drag-left",
            "drag-right"
        ]

        return Dictionary(uniqueKeysWithValues: names.map { name in
            (name, loadFrames(named: name))
        })
    }()

    private static func loadFrames(named setName: String) -> [NSImage] {
        (0..<6).compactMap { index in
            Bundle.main.url(
                forResource: "work-pet-\(setName)-\(index)",
                withExtension: "png",
                subdirectory: "Images/PetFrames"
            ).flatMap(NSImage.init(contentsOf:))
        }
    }

    private static let fallbackImage: NSImage? = Bundle.main.url(
        forResource: "work-pet",
        withExtension: "png",
        subdirectory: "Images"
    ).flatMap(NSImage.init(contentsOf:))
}

private struct PetDragSurface: NSViewRepresentable {
    let onDragStateChanged: (PetDragState) -> Void
    let onClick: () -> Void

    func makeNSView(context: Context) -> PetDragNSView {
        let view = PetDragNSView()
        view.onDragStateChanged = onDragStateChanged
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: PetDragNSView, context: Context) {
        nsView.onDragStateChanged = onDragStateChanged
        nsView.onClick = onClick
    }
}

private final class PetDragNSView: NSView {
    var onDragStateChanged: ((PetDragState) -> Void)?
    var onClick: (() -> Void)?
    private var dragStartScreenLocation: NSPoint?
    private var dragStartFrameOrigin: NSPoint?
    private var didMove = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            onClick?()
            return
        }

        dragStartScreenLocation = NSEvent.mouseLocation
        dragStartFrameOrigin = window.frame.origin
        didMove = false
        onDragStateChanged?(.pressed)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let dragStartScreenLocation,
              let dragStartFrameOrigin else {
            return
        }

        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - dragStartScreenLocation.x
        let deltaY = currentLocation.y - dragStartScreenLocation.y
        if abs(deltaX) > 2 || abs(deltaY) > 2 {
            didMove = true
        }

        window.setFrameOrigin(NSPoint(
            x: dragStartFrameOrigin.x + deltaX,
            y: dragStartFrameOrigin.y + deltaY
        ))

        if deltaX < -3 {
            onDragStateChanged?(.left)
        } else if deltaX > 3 {
            onDragStateChanged?(.right)
        } else {
            onDragStateChanged?(.pressed)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !didMove {
            onClick?()
        }
        onDragStateChanged?(.idle)
        dragStartScreenLocation = nil
        dragStartFrameOrigin = nil
        didMove = false
    }
}

private struct PetEye: View {
    let blink: Bool

    var body: some View {
        Capsule(style: .continuous)
            .fill(.white.opacity(0.94))
            .frame(width: 7, height: blink ? 3 : 10)
    }
}

private struct PetMouth: Shape {
    let mood: PetMood
    let blink: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX + 2, y: rect.midY)
        let end = CGPoint(x: rect.maxX - 2, y: rect.midY)
        let controlY: CGFloat = switch mood {
        case .done:
            rect.maxY - 1
        case .under5m:
            blink ? rect.maxY - 2 : rect.midY
        case .under30m:
            rect.midY + 3
        default:
            rect.midY + 5
        }
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: rect.midX, y: controlY))
        return path
    }
}

private extension PetMood {
    var primaryColor: Color {
        switch self {
        case .idle:
            return Color(red: 0.62, green: 0.66, blue: 0.68)
        case .working:
            return Color(red: 0.17, green: 0.70, blue: 0.78)
        case .under1h:
            return Color(red: 0.30, green: 0.60, blue: 0.95)
        case .under30m:
            return Color(red: 0.94, green: 0.62, blue: 0.18)
        case .under5m:
            return Color(red: 1.00, green: 0.30, blue: 0.28)
        case .done:
            return Color(red: 0.23, green: 0.78, blue: 0.45)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .idle:
            return Color(red: 0.84, green: 0.86, blue: 0.85)
        case .working:
            return Color(red: 0.65, green: 0.90, blue: 0.74)
        case .under1h:
            return Color(red: 0.74, green: 0.76, blue: 1.00)
        case .under30m:
            return Color(red: 1.00, green: 0.82, blue: 0.36)
        case .under5m:
            return Color(red: 1.00, green: 0.62, blue: 0.45)
        case .done:
            return Color(red: 0.70, green: 0.92, blue: 0.44)
        }
    }

    var accentColor: Color {
        switch self {
        case .idle:
            return .gray
        case .working:
            return .cyan
        case .under1h:
            return .blue
        case .under30m:
            return .orange
        case .under5m:
            return .red
        case .done:
            return .green
        }
    }
}
