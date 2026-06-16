import AppKit
import MacWorkTimerCore
import SwiftUI

struct WorkPetView: View {
    @EnvironmentObject private var model: AppModel
    @State private var dragState: PetDragState = .idle
    @State private var temporaryMessage: String?
    @State private var capsulePhase: CapsuleRevealPhase = .idle
    @State private var capsulePhaseStartedAt = Date()

    private var mood: PetMood {
        PetMood.mood(remaining: model.remaining)
    }

    private var defaultEvolutionStage: PetEvolutionStage {
        PetEvolutionStage.stage(elapsed: model.elapsed, duration: workdayDuration)
    }

    private var workdayDuration: TimeInterval {
        model.currentSession?.workdayDuration ?? WorkSession.workdayDuration
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

    private var revealDisplay: PetRevealDisplay {
        model.petRevealDisplay(availablePetIDs: PetAsset.availablePetIDs)
    }

    private var labelText: String {
        if case .capsuleIdle = revealDisplay {
            return capsulePhase == .idle ? "출근 완료" : "누가 나올까"
        }

        return visualState.label
    }

    private var leaveTimeText: String? {
        PetVisualState.leaveTimeText(targetAt: model.currentSession?.targetAt)
    }

    private var agentUsageCards: [AgentUsageCard] {
        model.agentUsageCards
    }

    private var hasLeaveTime: Bool {
        leaveTimeText != nil
    }

    private var spriteOffsetY: CGFloat {
        CGFloat(PetPanelMetrics.spriteOffsetY(hasLeaveTime: hasLeaveTime))
    }

    private var labelTextColor: Color {
        if case .capsuleIdle = revealDisplay {
            return Color(red: 0.18, green: 0.20, blue: 0.22).opacity(0.78)
        }

        return visualState.textColor
    }

    private var labelGlassTint: Color {
        if case .capsuleIdle = revealDisplay {
            return Color(red: 0.72, green: 0.88, blue: 0.86).opacity(0.26)
        }

        return visualState.glassTint
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 1) {
                if let leaveTimeText {
                    Text(leaveTimeText)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(labelTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(labelText)
                        .font(.system(size: 10.2, weight: .semibold, design: .rounded))
                        .foregroundStyle(labelTextColor.opacity(0.74))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                } else {
                    Text(labelText)
                        .font(.system(size: 11.4, weight: .semibold, design: .rounded))
                        .foregroundStyle(labelTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

            }
                .padding(.horizontal, 8)
                .padding(.vertical, leaveTimeText == nil ? 5 : 3)
                .liquidGlass(
                    in: Capsule(style: .continuous),
                    tint: labelGlassTint,
                    interactive: true
                )
                .frame(maxWidth: PetPanelMetrics.labelMaxWidth)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .offset(y: 2)
                .animation(.smooth(duration: 0.18), value: labelText)
                .animation(.smooth(duration: 0.18), value: leaveTimeText)

            spritePetBody
                .offset(x: agentUsageCards.isEmpty ? 0 : CGFloat(PetPanelMetrics.agentUsageSpriteOffsetX))

            if !agentUsageCards.isEmpty {
                AgentUsageSidePanel(cards: agentUsageCards)
                    .frame(width: CGFloat(PetPanelMetrics.agentUsageGridWidth))
                    .offset(
                        x: CGFloat(PetPanelMetrics.agentUsageGridOffsetX),
                        y: CGFloat(PetPanelMetrics.agentUsageGridOffsetY)
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: PetPanelMetrics.width, height: PetPanelMetrics.height)
        .contentShape(Rectangle())
        .overlay {
            PetDragSurface(
                onDragStateChanged: { newState in
                    withAnimation(.smooth(duration: 0.12)) {
                        dragState = newState
                    }
                },
                onClick: {
                    handleClick()
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
            let capsuleElapsed = timeline.date.timeIntervalSince(capsulePhaseStartedAt)

            switch revealDisplay {
            case .idle:
                let frame = PetAsset.frame(
                    setName: visualState.frameSetName,
                    at: time,
                    duration: visualState.frameDuration
                )
                petBody(image: frame, petID: PetRevealState.defaultPetID, stage: defaultEvolutionStage, blink: fallbackBlink(at: time), time: time)
                    .offset(y: spriteOffsetY)
            case .capsuleIdle:
                capsuleBody(
                    image: PetAsset.capsuleFrame(phase: capsulePhase, at: time),
                    phase: capsulePhase,
                    time: time,
                    elapsed: capsuleElapsed
                )
                .offset(y: spriteOffsetY)
            case .petVisible(let petID):
                let stageCount = PetAsset.evolutionStageCount(for: petID)
                let stageIndex = PetEvolutionStage.stageIndex(
                    elapsed: model.elapsed,
                    duration: workdayDuration,
                    stageCount: stageCount
                )
                let stage = PetEvolutionStage.stage(forStageIndex: stageIndex, stageCount: stageCount)
                let frame = PetAsset.petFrame(
                    petID: petID,
                    setName: visualState.frameSetName,
                    stageIndex: stageIndex,
                    at: time,
                    duration: visualState.frameDuration
                )
                petBody(image: frame, petID: petID, stage: stage, blink: fallbackBlink(at: time), time: time)
                    .offset(y: spriteOffsetY)
            }
        }
    }

    private func petBody(image: NSImage?, petID: String, stage: PetEvolutionStage, blink: Bool, time: TimeInterval) -> some View {
        ZStack {
            if let image {
                if petID == PetAsset.localEvolutionPetID {
                    LocalEvolutionPetImage(
                        image: image,
                        stage: stage,
                        blink: blink,
                        time: time
                    )
                } else {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 76, height: 82)
                }
            } else if petID == PetAsset.builtInSpecterPetID {
                SpecterPetBody(
                    stage: stage,
                    mood: mood,
                    blink: blink,
                    time: time
                )
            } else {
                fallbackPetBody(blink: blink)

                statusDot
                    .offset(x: 25, y: -23)
            }
        }
    }

    private func fallbackBlink(at time: TimeInterval) -> Bool {
        let periodicBlink = time.truncatingRemainder(dividingBy: 4.1) > 3.92
        return periodicBlink || (mood == .done && sin(time * .pi) > 0.82)
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

    private func capsuleBody(
        image: NSImage?,
        phase: CapsuleRevealPhase,
        time: TimeInterval,
        elapsed: TimeInterval
    ) -> some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 76, height: 82)
                    .modifier(CapsuleImageMotion(phase: phase, elapsed: elapsed))
            } else {
                CapsuleBallFallback(phase: phase, time: time, elapsed: elapsed)
            }
        }
    }

    private func handleClick() {
        switch PetClickAction.action(for: revealDisplay) {
        case .openLogin:
            openLoginWindow()
        case .revealCapsule:
            revealCapsule()
        case .showStatusMessage:
            showCurrentMessage()
        }
    }

    private func openLoginWindow() {
        withAnimation(.smooth(duration: 0.18)) {
            temporaryMessage = nil
        }
        MainWindowController.shared.showLogin()
    }

    private func revealCapsule() {
        guard capsulePhase == .idle else {
            return
        }

        Task { @MainActor in
            withAnimation(.smooth(duration: 0.12)) {
                temporaryMessage = nil
                capsulePhaseStartedAt = Date()
                capsulePhase = .shaking
            }

            try? await Task.sleep(for: .milliseconds(760))

            withAnimation(.smooth(duration: 0.18)) {
                capsulePhaseStartedAt = Date()
                capsulePhase = .opening
            }

            try? await Task.sleep(for: .milliseconds(760))

            model.completePetReveal(availablePetIDs: PetAsset.availablePetIDs)
            withAnimation(.smooth(duration: 0.20)) {
                capsulePhase = .idle
                capsulePhaseStartedAt = Date()
            }
        }
    }

    private func showCurrentMessage() {
        withAnimation(.smooth(duration: 0.22)) {
            temporaryMessage = PetVisualState.clickMessage(remaining: model.remaining, elapsed: model.elapsed)
        }
    }
}

private struct AgentUsageSidePanel: View {
    let cards: [AgentUsageCard]

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(CGFloat(PetPanelMetrics.agentUsageGridColumnWidth)),
                spacing: CGFloat(PetPanelMetrics.agentUsageGridSpacing)
            ),
            count: PetPanelMetrics.agentUsageGridColumnCount
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: CGFloat(PetPanelMetrics.agentUsageGridSpacing)) {
            ForEach(cards) { card in
                AgentUsageCardBadge(card: card)
                    .frame(width: CGFloat(PetPanelMetrics.agentUsageGridColumnWidth))
            }
        }
        .animation(.smooth(duration: 0.22), value: cards)
    }
}

private struct AgentUsageCardBadge: View {
    let card: AgentUsageCard

    private var accent: Color {
        switch card.provider {
        case .codex:
            return Color(red: 0.18, green: 0.43, blue: 0.86)
        case .claude:
            return Color(red: 0.80, green: 0.37, blue: 0.16)
        }
    }

    private var providerText: String {
        card.provider.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(providerText)
                    .font(.system(size: CGFloat(PetPanelMetrics.agentUsageProviderFontSize), weight: .bold, design: .rounded))
                    .foregroundStyle(accent.opacity(0.76))
                    .lineLimit(1)

                Spacer(minLength: 3)

                if !card.isResetDominant, let secondaryText = card.secondaryText {
                    Text(secondaryText)
                        .font(.system(size: CGFloat(PetPanelMetrics.agentUsageSecondaryFontSize), weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.66))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }

            if card.isResetDominant {
                Text(card.primaryText)
                    .font(.system(size: CGFloat(PetPanelMetrics.agentUsageResetPrimaryFontSize), weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Text(card.primaryText)
                    .font(.system(size: CGFloat(PetPanelMetrics.agentUsagePrimaryFontSize), weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            if card.isResetDominant, let secondaryText = card.secondaryText {
                Text(secondaryText)
                    .font(.system(size: CGFloat(PetPanelMetrics.agentUsageSecondaryFontSize), weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.56))
            }

            AgentUsageMeter(percent: card.remainingPercent, accent: accent)
                .frame(height: CGFloat(PetPanelMetrics.agentUsageMeterHeight))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 9, style: .continuous),
            tint: accent.opacity(0.12),
            interactive: true
        )
    }
}

private struct AgentUsageMeter: View {
    let percent: Int
    let accent: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let width = max(4, proxy.size.width * CGFloat(percent) / 100)
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.16))

                    Capsule(style: .continuous)
                        .fill(accent.opacity(percent == 0 ? 0.36 : 0.9))
                        .frame(width: width)
                        .overlay(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(.white.opacity(percent == 0 ? 0.12 : 0.42))
                                .frame(width: 16)
                                .offset(x: (width + 12) * phase - 12)
                                .clipped()
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.35), lineWidth: 0.6)
                        }
                }
                .animation(.smooth(duration: 0.24), value: percent)
            }
        }
    }
}

private enum CapsuleRevealPhase: Equatable {
    case idle
    case shaking
    case opening

    var frameSetName: String {
        switch self {
        case .idle:
            return "capsule-idle"
        case .shaking:
            return "capsule-shake"
        case .opening:
            return "capsule-open"
        }
    }

    var frameCount: Int {
        switch self {
        case .idle:
            return 6
        case .shaking, .opening:
            return 8
        }
    }

    var frameDuration: TimeInterval {
        switch self {
        case .idle:
            return 0.22
        case .shaking:
            return 0.08
        case .opening:
            return 0.09
        }
    }
}

private struct CapsuleImageMotion: ViewModifier {
    let phase: CapsuleRevealPhase
    let elapsed: TimeInterval

    func body(content: Content) -> some View {
        let wobble = phase == .shaking ? sin(elapsed * 38) * 14 : 0
        let xOffset = phase == .shaking ? sin(elapsed * 38) * 3 : 0
        let scale = phase == .opening ? 1.04 : 1

        content
            .rotationEffect(.degrees(wobble))
            .offset(x: xOffset)
            .scaleEffect(scale)
    }
}

private struct CapsuleBallFallback: View {
    let phase: CapsuleRevealPhase
    let time: TimeInterval
    let elapsed: TimeInterval

    private var openingProgress: CGFloat {
        phase == .opening ? min(1, max(0, elapsed / 0.66)) : 0
    }

    private var wobble: Double {
        switch phase {
        case .idle:
            return sin(time * 2.8) * 1.6
        case .shaking:
            return sin(elapsed * 38) * 14
        case .opening:
            return 0
        }
    }

    private var xOffset: CGFloat {
        phase == .shaking ? CGFloat(sin(elapsed * 38) * 3) : 0
    }

    var body: some View {
        ZStack {
            if phase == .opening {
                openedBall
            } else {
                closedBall
            }
        }
        .frame(width: 76, height: 82)
        .rotationEffect(.degrees(wobble))
        .offset(x: xOffset)
    }

    private var openedBall: some View {
        ZStack {
            closedBall
                .clipShape(HalfClip(top: true))
                .offset(y: -18 * openingProgress)
                .rotationEffect(.degrees(-7 * Double(openingProgress)))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.72, green: 0.98, blue: 0.93).opacity(0.62),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 34
                    )
                )
                .frame(width: 62, height: 62)
                .scaleEffect(0.74 + openingProgress * 0.28)
                .opacity(openingProgress)

            closedBall
                .clipShape(HalfClip(top: false))
                .offset(y: 9 * openingProgress)
                .rotationEffect(.degrees(3 * Double(openingProgress)))
        }
    }

    private var closedBall: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.95, green: 0.96, blue: 0.92))

            CapsuleBallUpperShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.76, blue: 0.72),
                            Color(red: 0.51, green: 0.91, blue: 0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(red: 0.28, green: 0.32, blue: 0.33))
                .frame(width: 72, height: 12)
                .rotationEffect(.degrees(-6))
                .offset(y: 2)

            Circle()
                .fill(Color(red: 0.30, green: 0.35, blue: 0.35))
                .frame(width: 30, height: 30)
                .overlay {
                    Circle()
                        .fill(.white.opacity(0.94))
                        .frame(width: 19, height: 19)
                }
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.18), lineWidth: 2)
                        .frame(width: 21, height: 21)
                }

            Ellipse()
                .fill(.white.opacity(0.62))
                .frame(width: 20, height: 11)
                .rotationEffect(.degrees(-28))
                .offset(x: -17, y: -19)
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color(red: 0.16, green: 0.18, blue: 0.18).opacity(0.72), lineWidth: 2)
                .frame(width: 68, height: 68)
        }
    }
}

private struct CapsuleBallUpperShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + 5))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY + 8),
            control: CGPoint(x: rect.midX, y: rect.midY - 13)
        )
        path.closeSubpath()
        return path
    }
}

private struct HalfClip: Shape {
    let top: Bool

    func path(in rect: CGRect) -> Path {
        let half = CGRect(
            x: rect.minX,
            y: top ? rect.minY : rect.midY,
            width: rect.width,
            height: rect.height / 2
        )
        return Path(half)
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
    static let builtInSpecterPetID = "specter"
    static let localEvolutionPetID = LocalPetCatalog.legacyPetID

    static var availablePetIDs: [String] {
        availablePetIDsCache
    }

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

    static func petFrame(
        petID: String,
        setName: String,
        stageIndex: Int,
        at time: TimeInterval,
        duration: TimeInterval
    ) -> NSImage? {
        if let image = localPetImage(petID: petID, stageIndex: stageIndex) {
            return image
        }

        let requestedFrames = customPetFrames(petID: petID, setName: setName)
        let idleFrames = customPetFrames(petID: petID, setName: "idle")
        let resolvedFrames = requestedFrames.isEmpty ? idleFrames : requestedFrames

        if !resolvedFrames.isEmpty {
            let frameDuration = max(0.05, duration)
            let frameIndex = Int((time / frameDuration).rounded(.down)) % resolvedFrames.count
            return resolvedFrames[frameIndex]
        }

        if petID == builtInSpecterPetID {
            return nil
        }

        if petID == PetRevealState.defaultPetID {
            return frame(setName: setName, at: time, duration: duration)
        }

        return frame(setName: setName, at: time, duration: duration)
    }

    static func evolutionStageCount(for petID: String) -> Int {
        if let localPet = localPetDescriptor(for: petID) {
            return localPet.stageImageURLs.count
        }

        return 3
    }

    static func capsuleFrame(phase: CapsuleRevealPhase, at time: TimeInterval) -> NSImage? {
        let frames = capsuleFrames(named: phase.frameSetName)
        if !frames.isEmpty {
            let frameIndex = Int((time / phase.frameDuration).rounded(.down)) % frames.count
            return frames[frameIndex]
        }

        switch phase {
        case .idle, .shaking:
            return capsuleClosedImage
        case .opening:
            return capsuleOpenImage ?? capsuleClosedImage
        }
    }

    private static func frames(named setName: String) -> [NSImage] {
        cachedFrames[setName] ?? []
    }

    private static func customPetFrames(petID: String, setName: String) -> [NSImage] {
        customPetFrameCache["\(petID)-\(setName)"] ?? []
    }

    private static func capsuleFrames(named setName: String) -> [NSImage] {
        capsuleFrameCache[setName] ?? []
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

    private static let availablePetIDsCache: [String] = {
        let prefix = "pet-"
        let suffix = "-idle-0.png"
        let ids = (Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "Images/PetFrames") ?? [])
            .map(\.lastPathComponent)
            .compactMap { fileName -> String? in
                guard fileName.hasPrefix(prefix), fileName.hasSuffix(suffix) else {
                    return nil
                }

                return String(fileName.dropFirst(prefix.count).dropLast(suffix.count))
            }
            .filter { !$0.isEmpty }
            .sorted()

        let builtIns = localPetDescriptors.map(\.id) + [builtInSpecterPetID]
        return Array(Set(builtIns + ids)).sorted()
    }()

    private static let customPetFrameCache: [String: [NSImage]] = {
        let petIDs = availablePetIDsCache
            .filter { $0 != PetRevealState.defaultPetID && $0 != builtInSpecterPetID }
            .filter { localPetDescriptor(for: $0) == nil }
        let setNames = [
            "idle",
            "working",
            "working-afternoon",
            "working-late",
            "under1h",
            "under30m",
            "under5m",
            "done",
            "appear",
            "drag",
            "drag-left",
            "drag-right"
        ]

        var cache: [String: [NSImage]] = [:]
        for petID in petIDs {
            for setName in setNames {
                cache["\(petID)-\(setName)"] = loadCustomPetFrames(petID: petID, setName: setName)
            }
        }
        return cache
    }()

    private static let capsuleFrameCache: [String: [NSImage]] = [
        "capsule-idle": loadResourceFrames(prefix: "capsule-idle", count: 6),
        "capsule-shake": loadResourceFrames(prefix: "capsule-shake", count: 8),
        "capsule-open": loadResourceFrames(prefix: "capsule-open", count: 8)
    ]

    private static func loadFrames(named setName: String) -> [NSImage] {
        (0..<6).compactMap { index in
            Bundle.main.url(
                forResource: "work-pet-\(setName)-\(index)",
                withExtension: "png",
                subdirectory: "Images/PetFrames"
            ).flatMap(NSImage.init(contentsOf:))
        }
    }

    private static func loadCustomPetFrames(petID: String, setName: String) -> [NSImage] {
        loadResourceFrames(prefix: "pet-\(petID)-\(setName)", count: 6)
    }

    private static func loadResourceFrames(prefix: String, count: Int) -> [NSImage] {
        (0..<count).compactMap { index in
            Bundle.main.url(
                forResource: "\(prefix)-\(index)",
                withExtension: "png",
                subdirectory: "Images/PetFrames"
            ).flatMap(NSImage.init(contentsOf:))
        }
    }

    private static func localPetImage(petID: String, stageIndex: Int) -> NSImage? {
        guard let descriptor = localPetDescriptor(for: petID),
              !descriptor.stageImageURLs.isEmpty else {
            return nil
        }

        let index = min(max(0, stageIndex), descriptor.stageImageURLs.count - 1)
        return NSImage(contentsOf: descriptor.stageImageURLs[index])
    }

    private static func localPetDescriptor(for petID: String) -> LocalPetDescriptor? {
        localPetDescriptors.first { $0.id == petID }
    }

    private static let localEvolutionDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("MacWorkTimerLocalPets", isDirectory: true)

    private static let localPetDescriptors: [LocalPetDescriptor] =
        LocalPetCatalog(directory: localEvolutionDirectory).descriptors()

    private static let fallbackImage: NSImage? = Bundle.main.url(
        forResource: "work-pet",
        withExtension: "png",
        subdirectory: "Images"
    ).flatMap(NSImage.init(contentsOf:))

    private static let capsuleClosedImage: NSImage? = Bundle.main.url(
        forResource: "capsule-closed",
        withExtension: "png",
        subdirectory: "Images"
    ).flatMap(NSImage.init(contentsOf:))

    private static let capsuleOpenImage: NSImage? = Bundle.main.url(
        forResource: "capsule-open",
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

private struct SpecterPetBody: View {
    let stage: PetEvolutionStage
    let mood: PetMood
    let blink: Bool
    let time: TimeInterval

    private var floatOffset: CGFloat {
        CGFloat(sin(time * 2.4) * 2.2)
    }

    private var bodySize: CGSize {
        switch stage {
        case .base:
            return CGSize(width: 54, height: 56)
        case .middle:
            return CGSize(width: 62, height: 62)
        case .final:
            return CGSize(width: 68, height: 66)
        }
    }

    var body: some View {
        ZStack {
            aura

            if stage != .base {
                SpecterHand(side: .left, stage: stage, time: time)
                    .offset(x: stage == .final ? -31 : -28, y: stage == .final ? 4 : 7)
                SpecterHand(side: .right, stage: stage, time: time)
                    .offset(x: stage == .final ? 31 : 28, y: stage == .final ? 4 : 7)
            }

            SpecterBlobShape(stage: stage)
                .fill(
                    LinearGradient(
                        colors: palette,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: bodySize.width, height: bodySize.height)
                .overlay {
                    SpecterBlobShape(stage: stage)
                        .stroke(.white.opacity(0.42), lineWidth: 1.1)
                        .frame(width: bodySize.width, height: bodySize.height)
                }

            SpecterFace(stage: stage, blink: blink)
                .offset(y: stage == .base ? -3 : -5)

            if stage == .final {
                Image(systemName: mood == .done ? "sparkle" : "moon.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .offset(x: 19, y: -22)
            }
        }
        .frame(width: 76, height: 82)
        .offset(y: floatOffset)
        .scaleEffect(stage == .final && mood == .done ? 1.04 : 1)
    }

    private var palette: [Color] {
        switch stage {
        case .base:
            return [
                Color(red: 0.55, green: 0.72, blue: 0.92).opacity(0.96),
                Color(red: 0.72, green: 0.88, blue: 0.84).opacity(0.98)
            ]
        case .middle:
            return [
                Color(red: 0.44, green: 0.42, blue: 0.78).opacity(0.97),
                Color(red: 0.30, green: 0.70, blue: 0.78).opacity(0.98)
            ]
        case .final:
            return [
                Color(red: 0.32, green: 0.27, blue: 0.56).opacity(0.99),
                Color(red: 0.16, green: 0.58, blue: 0.64).opacity(0.98)
            ]
        }
    }

    private var aura: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.58, green: 0.92, blue: 0.86).opacity(stage == .base ? 0.28 : 0.36),
                        .clear
                    ],
                    center: .center,
                    startRadius: 3,
                    endRadius: stage == .final ? 39 : 32
                )
            )
            .frame(width: stage == .final ? 78 : 68, height: stage == .final ? 78 : 68)
            .scaleEffect(1 + CGFloat(sin(time * 3.0)) * 0.025)
    }
}

private struct LocalEvolutionPetImage: View {
    let image: NSImage
    let stage: PetEvolutionStage
    let blink: Bool
    let time: TimeInterval

    private var floatOffset: CGFloat {
        CGFloat(sin(time * 2.2) * 1.8)
    }

    var body: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: PetPanelMetrics.localImageWidth, height: PetPanelMetrics.localImageHeight)

            LocalPetBlinkOverlay(stage: stage)
                .opacity(blink ? 1 : 0)
                .animation(.smooth(duration: 0.08), value: blink)
        }
        .frame(width: PetPanelMetrics.localSpriteWidth, height: PetPanelMetrics.localSpriteHeight)
        .offset(y: floatOffset)
        .scaleEffect(stage == .final ? PetPanelMetrics.maxScale : 0.98)
    }
}

private struct LocalPetBlinkOverlay: View {
    let stage: PetEvolutionStage

    var body: some View {
        ZStack {
            ForEach(Array(eyes.enumerated()), id: \.offset) { _, eye in
                Capsule(style: .continuous)
                    .fill(eye.color)
                    .frame(width: eye.size.width, height: eye.size.height)
                    .rotationEffect(.degrees(eye.rotation))
                    .position(eye.position)
            }
        }
        .frame(width: PetPanelMetrics.localSpriteWidth, height: PetPanelMetrics.localSpriteHeight)
        .allowsHitTesting(false)
    }

    private var eyes: [BlinkEye] {
        switch stage {
        case .base:
            return [
                BlinkEye(position: CGPoint(x: 29, y: 39), size: CGSize(width: 24, height: 13), rotation: -10, color: Color.black.opacity(0.96)),
                BlinkEye(position: CGPoint(x: 52, y: 37), size: CGSize(width: 24, height: 13), rotation: 10, color: Color.black.opacity(0.96))
            ]
        case .middle:
            return [
                BlinkEye(position: CGPoint(x: 33, y: 30), size: CGSize(width: 21, height: 9), rotation: -7, color: Color(red: 0.32, green: 0.30, blue: 0.44).opacity(0.94)),
                BlinkEye(position: CGPoint(x: 52, y: 32), size: CGSize(width: 22, height: 9), rotation: 5, color: Color(red: 0.32, green: 0.30, blue: 0.44).opacity(0.94))
            ]
        case .final:
            return [
                BlinkEye(position: CGPoint(x: 30, y: 31), size: CGSize(width: 24, height: 10), rotation: 11, color: Color(red: 0.30, green: 0.25, blue: 0.48).opacity(0.96)),
                BlinkEye(position: CGPoint(x: 54, y: 31), size: CGSize(width: 24, height: 10), rotation: -11, color: Color(red: 0.30, green: 0.25, blue: 0.48).opacity(0.96))
            ]
        }
    }
}

private struct BlinkEye {
    let position: CGPoint
    let size: CGSize
    let rotation: Double
    let color: Color
}

private struct SpecterFace: View {
    let stage: PetEvolutionStage
    let blink: Bool

    var body: some View {
        VStack(spacing: stage == .base ? 5 : 6) {
            HStack(spacing: stage == .final ? 15 : 13) {
                SpecterEye(stage: stage, blink: blink)
                SpecterEye(stage: stage, blink: blink)
            }

            SpecterMouth(stage: stage)
                .stroke(.white.opacity(0.90), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                .frame(width: stage == .final ? 18 : 15, height: 8)
        }
    }
}

private struct SpecterEye: View {
    let stage: PetEvolutionStage
    let blink: Bool

    var body: some View {
        Capsule(style: .continuous)
            .fill(stage == .final ? Color(red: 0.95, green: 0.92, blue: 0.72) : .white.opacity(0.94))
            .frame(
                width: stage == .final ? 8 : 7,
                height: blink ? 3 : (stage == .base ? 9 : 11)
            )
            .overlay(alignment: .topTrailing) {
                if stage == .middle {
                    Rectangle()
                        .fill(Color.black.opacity(0.22))
                        .frame(width: 8, height: 1)
                        .rotationEffect(.degrees(-8))
                        .offset(y: 1)
                }
            }
    }
}

private struct SpecterMouth: Shape {
    let stage: PetEvolutionStage

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY))
        let controlY = switch stage {
        case .base:
            rect.maxY - 1
        case .middle:
            rect.midY + 2
        case .final:
            rect.minY + 1
        }
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.midY),
            control: CGPoint(x: rect.midX, y: controlY)
        )
        return path
    }
}

private struct SpecterHand: View {
    enum Side {
        case left
        case right
    }

    let side: Side
    let stage: PetEvolutionStage
    let time: TimeInterval

    private var direction: CGFloat {
        side == .left ? -1 : 1
    }

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color(red: 0.34, green: 0.67, blue: 0.74).opacity(stage == .final ? 0.92 : 0.78))
                .frame(width: stage == .final ? 21 : 17, height: 10)

            HStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.58))
                        .frame(width: 3, height: stage == .final ? 8 : 6)
                        .offset(y: CGFloat(index % 2) * 1.5)
                }
            }
            .offset(x: direction * 5)
        }
        .rotationEffect(.degrees(Double(direction * (stage == .final ? 16 : 10)) + sin(time * 3.2) * 3))
    }
}

private struct SpecterBlobShape: Shape {
    let stage: PetEvolutionStage

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = rect.minX
        let right = rect.maxX
        let top = rect.minY
        let bottom = rect.maxY
        let midX = rect.midX

        path.move(to: CGPoint(x: midX, y: top))
        path.addCurve(
            to: CGPoint(x: right, y: rect.midY + 6),
            control1: CGPoint(x: right - 9, y: top + 1),
            control2: CGPoint(x: right + 1, y: top + 24)
        )
        path.addCurve(
            to: CGPoint(x: midX + 14, y: bottom - 5),
            control1: CGPoint(x: right - 1, y: bottom - 6),
            control2: CGPoint(x: midX + 25, y: bottom - 2)
        )

        if stage == .base {
            path.addQuadCurve(to: CGPoint(x: midX, y: bottom - 1), control: CGPoint(x: midX + 8, y: bottom - 12))
            path.addQuadCurve(to: CGPoint(x: midX - 14, y: bottom - 5), control: CGPoint(x: midX - 8, y: bottom - 12))
        } else {
            path.addQuadCurve(to: CGPoint(x: midX + 4, y: bottom - 1), control: CGPoint(x: midX + 8, y: bottom - 12))
            path.addQuadCurve(to: CGPoint(x: midX - 8, y: bottom - 2), control: CGPoint(x: midX - 2, y: bottom - 13))
            path.addQuadCurve(to: CGPoint(x: midX - 18, y: bottom - 6), control: CGPoint(x: midX - 15, y: bottom - 13))
        }

        path.addCurve(
            to: CGPoint(x: left, y: rect.midY + 5),
            control1: CGPoint(x: left + 6, y: bottom - 2),
            control2: CGPoint(x: left - 1, y: bottom - 20)
        )
        path.addCurve(
            to: CGPoint(x: midX, y: top),
            control1: CGPoint(x: left + 2, y: top + 21),
            control2: CGPoint(x: left + 13, y: top + 1)
        )
        path.closeSubpath()
        return path
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
