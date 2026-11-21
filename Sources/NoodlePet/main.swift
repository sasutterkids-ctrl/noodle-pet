import AppKit
import ApplicationServices
import CoreImage
import AVFoundation
import UserNotifications

private let petSize = CGFloat(224)

private func makeDiscoTrack() -> Data? {
    let sampleRate: UInt32 = 44_100
    let duration = 25.0
    let sampleCount = Int(Double(sampleRate) * duration)
    var data = Data()

    func appendBytes<T>(_ value: T) {
        var value = value
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }

    data.append(contentsOf: Array("RIFF".utf8))
    appendBytes(UInt32(36 + sampleCount * 2).littleEndian)
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    appendBytes(UInt32(16).littleEndian)
    appendBytes(UInt16(1).littleEndian)
    appendBytes(UInt16(1).littleEndian)
    appendBytes(sampleRate.littleEndian)
    appendBytes((sampleRate * 2).littleEndian)
    appendBytes(UInt16(2).littleEndian)
    appendBytes(UInt16(16).littleEndian)
    data.append(contentsOf: Array("data".utf8))
    appendBytes(UInt32(sampleCount * 2).littleEndian)

    let beatLength = 60.0 / 132.0
    let notes: [Double] = [196.0, 220.0, 246.94, 220.0, 196.0, 174.61, 196.0, 220.0]
    for index in 0..<sampleCount {
        let time = Double(index) / Double(sampleRate)
        let step = Int(time / (beatLength * 0.5))
        let beat = Int(time / beatLength)
        let beatTime = time.truncatingRemainder(dividingBy: beatLength)
        let note = notes[step % notes.count]
        let lead = sin(time * note * 2 * .pi) * 0.20
        let harmony = sin(time * note * 1.25 * 2 * .pi) * 0.12
        let bass = sin(time * notes[(beat / 2) % notes.count] * 0.5 * 2 * .pi) * 0.28
        let kickEnvelope = max(0, 1 - beatTime / 0.20)
        let kick = sin(time * (105 - 50 * beatTime / 0.20) * 2 * .pi) * kickEnvelope * 0.55
        let snareTime = beatTime.truncatingRemainder(dividingBy: beatLength)
        let clapEnvelope = max(0, 1 - abs(snareTime - beatLength * 0.5) / 0.055)
        let clap = sin(time * 2861.0) * sin(time * 911.0) * clapEnvelope * 0.24
        let hatTime = time.truncatingRemainder(dividingBy: beatLength * 0.5)
        let hatEnvelope = max(0, 1 - hatTime / 0.035)
        let hiHat = sin(time * 7800.0) * sin(time * 1913.0) * hatEnvelope * 0.13
        let sweep = sin(time * 0.8 * 2 * .pi) * 0.05
        let fade = min(1, time * 5) * min(1, (duration - time) * 5)
        let sample = max(-1, min(1, (lead + harmony + bass + kick + clap + hiHat + sweep) * fade))
        let pcm = Int16(sample * Double(Int16.max) * 0.86).littleEndian
        appendBytes(pcm)
    }
    return data
}

private func loadDanceBreakTrack() -> Data? {
    if let url = Bundle.main.url(forResource: "DanceBreak", withExtension: "m4a"),
       let data = try? Data(contentsOf: url) {
        return data
    }
    return makeDiscoTrack()
}

final class DiscoOverlayView: NSView {
    var spotlightCenter = NSPoint.zero { didSet { needsDisplay = true } }
    var phase: CGFloat = 0 { didSet { needsDisplay = true } }
    var dimProgress: CGFloat = 0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let beatPulse = 0.5 + 0.5 * sin(phase * 10)
        let dimAlpha = min(0.97, 0.18 + dimProgress * 0.76 + beatPulse * 0.025 * dimProgress)
        NSColor.black.withAlphaComponent(dimAlpha).setFill()
        bounds.fill()

        let colors: [NSColor] = [.systemPink, .systemBlue, .systemGreen, .systemOrange]
        let washIndex = Int(phase * 0.9) % colors.count
        colors[washIndex].withAlphaComponent(0.035 + beatPulse * 0.04).setFill()
        bounds.fill()

        for index in 0..<10 {
            let y = bounds.height * (0.10 + CGFloat(index) * 0.085) + sin(phase * 2.2 + CGFloat(index)) * 8
            let scanline = NSBezierPath()
            scanline.move(to: NSPoint(x: 0, y: y))
            scanline.line(to: NSPoint(x: bounds.width, y: y + sin(phase + CGFloat(index)) * 18))
            colors[index % colors.count].withAlphaComponent(0.10 + beatPulse * 0.07).setStroke()
            scanline.lineWidth = 2 + beatPulse * 2
            scanline.stroke()
        }

        let ballCenter = NSPoint(x: bounds.midX + sin(phase * 0.7) * bounds.width * 0.28, y: bounds.maxY - 78 + cos(phase * 0.9) * 18)
        let ballRadius: CGFloat = 28 + beatPulse * 5
        NSColor.white.withAlphaComponent(0.18 + beatPulse * 0.12).setFill()
        NSBezierPath(ovalIn: NSRect(x: ballCenter.x - ballRadius, y: ballCenter.y - ballRadius, width: ballRadius * 2, height: ballRadius * 2)).fill()
        for dotIndex in 0..<18 {
            let dotAngle = phase * 2.4 + CGFloat(dotIndex) * 2.1
            let dotRadius = ballRadius * (0.55 + CGFloat(dotIndex % 3) * 0.12)
            let dot = NSPoint(x: ballCenter.x + cos(dotAngle) * dotRadius, y: ballCenter.y + sin(dotAngle) * dotRadius)
            colors[dotIndex % colors.count].withAlphaComponent(0.75).setFill()
            NSBezierPath(ovalIn: NSRect(x: dot.x - 3, y: dot.y - 3, width: 6, height: 6)).fill()
        }

        for index in 0..<8 {
            let angle = phase * 0.8 + CGFloat(index) * (.pi / 4)
            let radius: CGFloat = 230 + CGFloat(index % 3) * 70
            let center = NSPoint(x: spotlightCenter.x + cos(angle) * radius, y: spotlightCenter.y + sin(angle) * radius)
            let star = NSBezierPath()
            star.move(to: NSPoint(x: center.x - 12, y: center.y))
            star.line(to: NSPoint(x: center.x + 12, y: center.y))
            star.move(to: NSPoint(x: center.x, y: center.y - 12))
            star.line(to: NSPoint(x: center.x, y: center.y + 12))
            star.lineWidth = 3 + beatPulse * 3
            colors[index % colors.count].withAlphaComponent(0.32 + beatPulse * 0.35).setStroke()
            star.stroke()
        }

        for index in 0..<9 {
            let seed = CGFloat(index)
            let fogX = (bounds.width * (0.08 + CGFloat(index) * 0.11) + sin(phase * 0.35 + seed) * 90).truncatingRemainder(dividingBy: bounds.width)
            let fogY = 42 + cos(phase * 0.45 + seed * 0.8) * 16
            let fogWidth = 150 + CGFloat(index % 4) * 38
            let fogHeight = 34 + CGFloat(index % 3) * 14
            NSColor(calibratedWhite: 0.82, alpha: 0.045 + beatPulse * 0.035).setFill()
            NSBezierPath(ovalIn: NSRect(x: fogX - fogWidth / 2, y: fogY - fogHeight / 2, width: fogWidth, height: fogHeight)).fill()
        }

        for index in 0..<26 {
            let seed = CGFloat(index)
            let angle = phase * (1.8 + CGFloat(index % 4) * 0.18) + seed * 0.91
            let radius = 88 + CGFloat(index % 6) * 24 + sin(phase * 4 + seed) * 14
            let center = NSPoint(x: spotlightCenter.x + cos(angle) * radius, y: spotlightCenter.y + sin(angle) * radius)
            let sparkLength = 5 + beatPulse * 10
            let spark = NSBezierPath()
            spark.move(to: NSPoint(x: center.x - cos(angle) * sparkLength, y: center.y - sin(angle) * sparkLength))
            spark.line(to: NSPoint(x: center.x + cos(angle) * sparkLength, y: center.y + sin(angle) * sparkLength))
            spark.move(to: NSPoint(x: center.x - sin(angle) * sparkLength * 0.65, y: center.y + cos(angle) * sparkLength * 0.65))
            spark.line(to: NSPoint(x: center.x + sin(angle) * sparkLength * 0.65, y: center.y - cos(angle) * sparkLength * 0.65))
            colors[index % colors.count].withAlphaComponent(0.42 + beatPulse * 0.45).setStroke()
            spark.lineWidth = 1.5 + beatPulse * 2
            spark.stroke()
        }

        let noteAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 27 + beatPulse * 8),
            .foregroundColor: NSColor.white.withAlphaComponent(0.55 + beatPulse * 0.3)
        ]
        let noteY = bounds.height * 0.66 + sin(phase * 2.1) * 34
        ("♪" as NSString).draw(at: NSPoint(x: bounds.width * 0.12 + cos(phase) * 20, y: noteY), withAttributes: noteAttributes)
        ("♫" as NSString).draw(at: NSPoint(x: bounds.width * 0.82 + sin(phase * 1.4) * 18, y: noteY - 70), withAttributes: noteAttributes)

        let flash = max(0, sin(phase * 5.5))
        if flash > 0.78 {
            NSColor.white.withAlphaComponent((flash - 0.78) * 0.20).setFill()
            bounds.fill()
        }

        for index in 0..<4 {
            let angle = phase * (index.isMultiple(of: 2) ? 0.9 : -0.7) + CGFloat(index) * 1.57
            let origin = NSPoint(x: bounds.midX + cos(angle) * bounds.width * 0.46, y: bounds.midY + sin(angle) * bounds.height * 0.46)
            let beam = NSBezierPath()
            beam.move(to: origin)
            beam.line(to: NSPoint(x: spotlightCenter.x - 90, y: spotlightCenter.y + 26))
            beam.line(to: NSPoint(x: spotlightCenter.x + 90, y: spotlightCenter.y - 26))
            beam.close()
            colors[index].withAlphaComponent(0.10 + beatPulse * 0.12).setFill()
            beam.fill()
        }

        let haloRadius = 125 + sin(phase * 5) * 18 + beatPulse * 12
        NSColor.white.withAlphaComponent(0.10 + beatPulse * 0.08).setFill()
        NSBezierPath(ovalIn: NSRect(x: spotlightCenter.x - haloRadius, y: spotlightCenter.y - haloRadius, width: haloRadius * 2, height: haloRadius * 2)).fill()
        NSColor.systemYellow.withAlphaComponent(0.10 + beatPulse * 0.10).setFill()
        NSBezierPath(ovalIn: NSRect(x: spotlightCenter.x - 88, y: spotlightCenter.y - 88, width: 176, height: 176)).fill()

        for ringIndex in 0..<4 {
            let radius = 92 + CGFloat(ringIndex) * 28 + sin(phase * 4 + CGFloat(ringIndex)) * 10
            let ring = NSBezierPath(ovalIn: NSRect(x: spotlightCenter.x - radius, y: spotlightCenter.y - radius, width: radius * 2, height: radius * 2))
            colors[ringIndex].withAlphaComponent(0.12 + beatPulse * 0.10).setStroke()
            ring.lineWidth = 3 + beatPulse * 3
            ring.stroke()
        }

        for index in 0..<12 {
            let angle = phase * (0.8 + CGFloat(index % 3) * 0.15) + CGFloat(index) * 0.52
            let length = 170 + CGFloat(index % 4) * 55
            let ray = NSBezierPath()
            ray.move(to: spotlightCenter)
            ray.line(to: NSPoint(x: spotlightCenter.x + cos(angle) * length, y: spotlightCenter.y + sin(angle) * length))
            colors[index % colors.count].withAlphaComponent(0.08 + beatPulse * 0.07).setStroke()
            ray.lineWidth = 2 + beatPulse * 3
            ray.stroke()
        }

        for index in 0..<34 {
            let seed = CGFloat(index)
            let x = (bounds.width * (0.07 + CGFloat(index % 17) * 0.055) + sin(phase * 1.6 + seed) * 28).truncatingRemainder(dividingBy: bounds.width)
            let y = (bounds.height * (0.18 + CGFloat(index % 9) * 0.09) + cos(phase * 1.2 + seed * 0.7) * 42).truncatingRemainder(dividingBy: bounds.height)
            let size = 3 + CGFloat(index % 4) * 2
            colors[index % colors.count].withAlphaComponent(0.32 + beatPulse * 0.28).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: size, height: size * 1.8), xRadius: 2, yRadius: 2).fill()
        }

        for index in 0..<16 {
            let barWidth: CGFloat = 12
            let gap: CGFloat = 7
            let x = 18 + CGFloat(index) * (barWidth + gap)
            let height = 18 + (0.5 + 0.5 * sin(phase * 9 + CGFloat(index) * 0.9)) * 42
            colors[index % colors.count].withAlphaComponent(0.28 + beatPulse * 0.22).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: 12, width: barWidth, height: height), xRadius: 4, yRadius: 4).fill()
        }

        NSColor.white.withAlphaComponent(0.35 + beatPulse * 0.3).setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 14, dy: 14), xRadius: 18, yRadius: 18)
        border.lineWidth = 4 + beatPulse * 2
        border.stroke()

        if let context = NSGraphicsContext.current {
            context.saveGraphicsState()
            context.compositingOperation = .clear
            NSBezierPath(ovalIn: NSRect(x: spotlightCenter.x - 76, y: spotlightCenter.y - 76, width: 152, height: 152)).fill()
            context.restoreGraphicsState()
        }
    }
}

struct WallSegment {
    let start: NSPoint
    let end: NSPoint
}

final class WallOverlayView: NSView {
    weak var delegate: AppDelegate?
    var walls: [WallSegment] = [] { didSet { needsDisplay = true } }
    var treatPoint: NSPoint? { didSet { needsDisplay = true } }
    private(set) var isEditing = true
    private var placingTreat = false
    private var drawingStart: NSPoint?
    private var drawingEnd: NSPoint?

    private let treatButton = NSButton(title: "Place treat", target: nil, action: nil)
    private let mazeButton = NSButton(title: "Make maze", target: nil, action: nil)
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    private let hint = NSTextField(labelWithString: "Drag to draw walls • lines snap straight")

    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
        wantsLayer = true

        hint.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        hint.textColor = .white.withAlphaComponent(0.9)
        addSubview(hint)

        treatButton.target = delegate
        treatButton.action = #selector(AppDelegate.wallEditorToggleTreat(_:))
        mazeButton.target = delegate
        mazeButton.action = #selector(AppDelegate.wallEditorMakeMaze(_:))
        clearButton.target = delegate
        clearButton.action = #selector(AppDelegate.wallEditorClear(_:))
        doneButton.target = delegate
        doneButton.action = #selector(AppDelegate.wallEditorDone(_:))
        for button in [treatButton, mazeButton, clearButton, doneButton] {
            button.bezelStyle = .rounded
            button.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func beginEditing() {
        isEditing = true
        placingTreat = false
        treatButton.title = "Place treat"
        hint.stringValue = "Drag to draw walls • lines snap straight"
        [treatButton, mazeButton, clearButton, doneButton, hint].forEach { $0.isHidden = false }
        needsDisplay = true
    }

    func finishEditing() {
        isEditing = false
        placingTreat = false
        drawingStart = nil
        drawingEnd = nil
        [treatButton, mazeButton, clearButton, doneButton, hint].forEach { $0.isHidden = true }
        needsDisplay = true
    }

    func toggleTreatMode() {
        placingTreat.toggle()
        treatButton.title = placingTreat ? "Click desktop…" : "Place treat"
        hint.stringValue = placingTreat ? "Click anywhere to place the treat" : "Drag to draw walls • lines snap straight"
    }

    override func layout() {
        super.layout()
        let top: CGFloat = bounds.height - 48
        hint.frame = NSRect(x: 18, y: top + 8, width: 300, height: 24)
        doneButton.frame = NSRect(x: bounds.maxX - 92, y: top + 4, width: 74, height: 30)
        clearButton.frame = NSRect(x: bounds.maxX - 174, y: top + 4, width: 70, height: 30)
        mazeButton.frame = NSRect(x: bounds.maxX - 270, y: top + 4, width: 86, height: 30)
        treatButton.frame = NSRect(x: bounds.maxX - 382, y: top + 4, width: 104, height: 30)
    }

    private func screenPoint(from localPoint: NSPoint) -> NSPoint {
        window?.convertPoint(toScreen: localPoint) ?? localPoint
    }

    private func localPoint(from screenPoint: NSPoint) -> NSPoint {
        window?.convertPoint(fromScreen: screenPoint) ?? screenPoint
    }

    private func straightPoint(from start: NSPoint, to point: NSPoint) -> NSPoint {
        let dx = point.x - start.x
        let dy = point.y - start.y
        return abs(dx) >= abs(dy) ? NSPoint(x: point.x, y: start.y) : NSPoint(x: start.x, y: point.y)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEditing else { return }
        let screen = screenPoint(from: event.locationInWindow)
        if placingTreat {
            delegate?.wallEditorPlaceTreat(at: screen)
            placingTreat = false
            treatButton.title = "Place treat"
            hint.stringValue = "Drag to draw walls • lines snap straight"
            return
        }
        drawingStart = screen
        drawingEnd = screen
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEditing, let start = drawingStart else { return }
        drawingEnd = straightPoint(from: start, to: screenPoint(from: event.locationInWindow))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isEditing, let start = drawingStart else { return }
        let end = drawingEnd ?? straightPoint(from: start, to: screenPoint(from: event.locationInWindow))
        drawingStart = nil
        drawingEnd = nil
        guard hypot(end.x - start.x, end.y - start.y) > 16 else {
            needsDisplay = true
            return
        }
        delegate?.wallEditorAddWall(from: start, to: end)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isEditing {
            NSColor.black.withAlphaComponent(0.38).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: bounds.maxY - 52, width: bounds.width, height: 52)).fill()
        }

        for wall in walls {
            let path = NSBezierPath()
            path.move(to: localPoint(from: wall.start))
            path.line(to: localPoint(from: wall.end))
            path.lineWidth = 10
            path.lineCapStyle = .round
            NSColor(calibratedRed: 0.25, green: 0.78, blue: 1.0, alpha: 0.9).setStroke()
            path.stroke()
            NSColor.white.withAlphaComponent(0.7).setStroke()
            path.lineWidth = 2
            path.stroke()
        }

        if let start = drawingStart, let end = drawingEnd {
            let path = NSBezierPath()
            path.move(to: localPoint(from: start))
            path.line(to: localPoint(from: end))
            path.lineWidth = 10
            path.lineCapStyle = .round
            NSColor.systemYellow.withAlphaComponent(0.85).setStroke()
            path.stroke()
        }

        if let treatPoint {
            let local = localPoint(from: treatPoint)
            NSColor.black.withAlphaComponent(0.25).setFill()
            NSBezierPath(ovalIn: NSRect(x: local.x - 25, y: local.y - 9, width: 50, height: 13)).fill()
            NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.20, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: local.x - 20, y: local.y - 20, width: 40, height: 28)).fill()
            NSColor(calibratedRed: 0.72, green: 0.32, blue: 0.10, alpha: 1).setFill()
            for offset in [NSPoint(x: -9, y: 2), NSPoint(x: 2, y: -5), NSPoint(x: 10, y: 4)] {
                NSBezierPath(ovalIn: NSRect(x: local.x + offset.x - 3, y: local.y + offset.y - 3, width: 6, height: 5)).fill()
            }
        }
    }
}

struct GridWall {
    let first: Int
    let second: Int
}

final class MazeBuilderView: NSView {
    enum Mode {
        case wall
        case start
        case treat
    }

    weak var delegate: AppDelegate?
    private(set) var gridSize = 12
    private(set) var walls: [GridWall] = []
    private(set) var startIndex = 12 * 6
    private(set) var treatIndex = 12 * 6 + 11
    private var selectedDot: Int?
    private var mode: Mode = .wall
    private var isRunning = false

    private let titleLabel = NSTextField(labelWithString: "Maze Builder")
    private let hintLabel = NSTextField(labelWithString: "Click two dots to connect a wall")
    private let slider = NSSlider(value: 12, minValue: 6, maxValue: 20, target: nil, action: nil)
    private let sliderLabel = NSTextField(labelWithString: "Dots: 12 × 12")
    private let wallButton = NSButton(title: "Wall mode", target: nil, action: nil)
    private let startButton = NSButton(title: "Set Noodle start", target: nil, action: nil)
    private let treatButton = NSButton(title: "Set treat end", target: nil, action: nil)
    private let clearButton = NSButton(title: "Clear walls", target: nil, action: nil)
    private let randomButton = NSButton(title: "Random maze", target: nil, action: nil)
    private let okButton = NSButton(title: "OK — run maze", target: nil, action: nil)

    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
        wantsLayer = true

        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        hintLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        hintLabel.textColor = .white.withAlphaComponent(0.75)
        sliderLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        sliderLabel.textColor = .white.withAlphaComponent(0.85)
        addSubview(titleLabel)
        addSubview(hintLabel)
        addSubview(slider)
        addSubview(sliderLabel)

        wallButton.target = delegate
        wallButton.action = #selector(AppDelegate.mazeWallMode(_:))
        startButton.target = delegate
        startButton.action = #selector(AppDelegate.mazeStartMode(_:))
        treatButton.target = delegate
        treatButton.action = #selector(AppDelegate.mazeTreatMode(_:))
        clearButton.target = delegate
        clearButton.action = #selector(AppDelegate.mazeClear(_:))
        randomButton.target = delegate
        randomButton.action = #selector(AppDelegate.mazeRandom(_:))
        okButton.target = delegate
        okButton.action = #selector(AppDelegate.mazeOK(_:))
        slider.target = delegate
        slider.action = #selector(AppDelegate.mazeGridSliderChanged(_:))
        for button in [wallButton, startButton, treatButton, clearButton, randomButton, okButton] {
            button.bezelStyle = .rounded
            button.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setMode(_ mode: Mode) {
        guard !isRunning else { return }
        self.mode = mode
        selectedDot = nil
        hintLabel.stringValue = mode == .wall ? "Click two dots to connect a wall" : (mode == .start ? "Click a dot for Noodle's start" : "Click a dot for the treat end")
        needsDisplay = true
    }

    func setGridSize(_ size: Int) {
        guard !isRunning else { return }
        gridSize = min(20, max(6, size))
        walls.removeAll()
        selectedDot = nil
        startIndex = (gridSize / 2) * gridSize
        treatIndex = (gridSize / 2) * gridSize + gridSize - 1
        slider.integerValue = gridSize
        sliderLabel.stringValue = "Dots: \(gridSize) × \(gridSize)"
        needsDisplay = true
    }

    func clearWalls() {
        guard !isRunning else { return }
        walls.removeAll()
        selectedDot = nil
        needsDisplay = true
    }

    func makeRandomMaze() {
        guard !isRunning else { return }
        walls.removeAll()
        selectedDot = nil
        let wallCount = max(14, gridSize * 3)
        var connected: Set<Int> = []
        var frontier: [Int] = []
        let startingCandidates = (0..<(gridSize * gridSize)).filter { $0 != startIndex && $0 != treatIndex }
        guard let first = startingCandidates.randomElement() else {
            needsDisplay = true
            return
        }
        connected.insert(first)
        frontier.append(first)

        while walls.count < wallCount && !frontier.isEmpty {
            let frontierIndex = Int.random(in: 0..<frontier.count)
            let anchor = frontier[frontierIndex]
            let column = anchor % gridSize
            let row = anchor / gridSize
            let neighbors = [
                (column - 1, row), (column + 1, row),
                (column, row - 1), (column, row + 1)
            ].filter {
                $0.0 >= 0 && $0.0 < gridSize && $0.1 >= 0 && $0.1 < gridSize
            }.map { $0.1 * gridSize + $0.0 }.filter {
                $0 != startIndex && $0 != treatIndex && !connected.contains($0)
            }

            guard let next = neighbors.randomElement() else {
                frontier.remove(at: frontierIndex)
                continue
            }
            walls.append(GridWall(first: anchor, second: next))
            connected.insert(next)
            frontier.append(next)
        }
        needsDisplay = true
    }

    func setRunning() {
        isRunning = true
        selectedDot = nil
        hintLabel.stringValue = "Noodle is solving the maze…"
        [slider, wallButton, startButton, treatButton, clearButton, randomButton, okButton].forEach { $0.isEnabled = false }
        needsDisplay = true
    }

    func beginEditing() {
        isRunning = false
        hintLabel.stringValue = "Click two dots to connect a wall"
        [slider, wallButton, startButton, treatButton, clearButton, randomButton, okButton].forEach { $0.isEnabled = true }
        needsDisplay = true
    }

    func gridPointOnScreen(for index: Int) -> NSPoint {
        let local = gridPoint(for: index)
        guard let window else { return local }
        let windowPoint = convert(local, to: nil)
        return window.convertPoint(toScreen: windowPoint)
    }

    private func gridArea() -> NSRect {
        let side = min(bounds.width - 48, bounds.height - 190)
        return NSRect(x: (bounds.width - side) / 2, y: 112, width: side, height: side)
    }

    private func gridPoint(for index: Int) -> NSPoint {
        let area = gridArea()
        let column = index % gridSize
        let row = index / gridSize
        let spacing = area.width / CGFloat(gridSize - 1)
        return NSPoint(x: area.minX + CGFloat(column) * spacing, y: area.maxY - CGFloat(row) * spacing)
    }

    private func nearestDot(to point: NSPoint) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for index in 0..<(gridSize * gridSize) {
            let dot = gridPoint(for: index)
            let distance = hypot(dot.x - point.x, dot.y - point.y)
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }
        guard let best, best.distance < 26 else { return nil }
        return best.index
    }

    override func layout() {
        super.layout()
        titleLabel.frame = NSRect(x: 24, y: bounds.maxY - 42, width: 220, height: 28)
        hintLabel.frame = NSRect(x: 24, y: bounds.maxY - 66, width: 360, height: 20)
        sliderLabel.frame = NSRect(x: 24, y: 74, width: 110, height: 20)
        slider.frame = NSRect(x: 130, y: 74, width: 180, height: 20)
        wallButton.frame = NSRect(x: 330, y: 70, width: 92, height: 28)
        startButton.frame = NSRect(x: 430, y: 70, width: 126, height: 28)
        treatButton.frame = NSRect(x: 564, y: 70, width: 112, height: 28)
        clearButton.frame = NSRect(x: 24, y: 28, width: 100, height: 30)
        randomButton.frame = NSRect(x: 134, y: 28, width: 116, height: 30)
        okButton.frame = NSRect(x: bounds.maxX - 150, y: 28, width: 126, height: 30)
    }

    override func mouseDown(with event: NSEvent) {
        guard !isRunning else { return }
        let point = event.locationInWindow
        guard let index = nearestDot(to: point) else { return }
        switch mode {
        case .wall:
            if let selectedDot {
                guard selectedDot != index else {
                    self.selectedDot = nil
                    needsDisplay = true
                    return
                }
                if !walls.contains(where: { ($0.first == selectedDot && $0.second == index) || ($0.first == index && $0.second == selectedDot) }) {
                    walls.append(GridWall(first: selectedDot, second: index))
                }
                self.selectedDot = nil
            } else {
                selectedDot = index
            }
        case .start:
            startIndex = index
            selectedDot = nil
        case .treat:
            treatIndex = index
            selectedDot = nil
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor(calibratedRed: 0.08, green: 0.07, blue: 0.13, alpha: 1).setFill()
        bounds.fill()
        let area = gridArea()
        NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.22, alpha: 1).setFill()
        NSBezierPath(roundedRect: area.insetBy(dx: -18, dy: -18), xRadius: 18, yRadius: 18).fill()

        NSColor.white.withAlphaComponent(0.10).setStroke()
        for index in 0..<gridSize {
            let rowStart = gridPoint(for: index * gridSize)
            let rowEnd = gridPoint(for: index * gridSize + gridSize - 1)
            let columnStart = gridPoint(for: index)
            let columnEnd = gridPoint(for: (gridSize - 1) * gridSize + index)
            let row = NSBezierPath(); row.move(to: rowStart); row.line(to: rowEnd); row.lineWidth = 1; row.stroke()
            let column = NSBezierPath(); column.move(to: columnStart); column.line(to: columnEnd); column.lineWidth = 1; column.stroke()
        }

        for wall in walls {
            let path = NSBezierPath()
            path.move(to: gridPoint(for: wall.first))
            path.line(to: gridPoint(for: wall.second))
            path.lineWidth = 8
            path.lineCapStyle = .round
            NSColor(calibratedRed: 0.25, green: 0.78, blue: 1.0, alpha: 0.95).setStroke()
            path.stroke()
        }

        for index in 0..<(gridSize * gridSize) {
            let dot = gridPoint(for: index)
            let color: NSColor
            let radius: CGFloat
            if index == startIndex {
                color = .systemGreen
                radius = 9
            } else if index == treatIndex {
                color = NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.20, alpha: 1)
                radius = 9
            } else if index == selectedDot {
                color = .systemYellow
                radius = 8
            } else {
                color = .white.withAlphaComponent(0.82)
                radius = 5
            }
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: dot.x - radius, y: dot.y - radius, width: radius * 2, height: radius * 2)).fill()
        }
    }
}

final class PetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class ToyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum ToyKind: Hashable {
    case treat
    case goldenBone
    case trap
    case ball
    case yarn
    case robot
    case boombox
}

final class ToyView: NSView {
    weak var delegate: AppDelegate?
    let kind: ToyKind
    private var dragOffset = NSPoint.zero
    private var lastMousePoint = NSPoint.zero
    private var lastDragTime = Date()
    private var dragVelocity = NSPoint.zero

    init(delegate: AppDelegate, kind: ToyKind) {
        self.delegate = delegate
        self.kind = kind
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.withAlphaComponent(0.14).setFill()
        NSBezierPath(ovalIn: NSRect(x: 9, y: 7, width: 38, height: 10)).fill()
        switch kind {
        case .treat:
            NSColor(calibratedRed: 0.96, green: 0.64, blue: 0.22, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 8, y: 14, width: 40, height: 30)).fill()
            NSColor(calibratedRed: 0.72, green: 0.34, blue: 0.12, alpha: 1).setFill()
            for point in [NSPoint(x: 19, y: 32), NSPoint(x: 31, y: 24), NSPoint(x: 39, y: 35)] {
                NSBezierPath(ovalIn: NSRect(x: point.x - 3, y: point.y - 2, width: 6, height: 4)).fill()
            }
        case .goldenBone:
            NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.16, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 17, y: 25, width: 24, height: 12), xRadius: 5, yRadius: 5).fill()
            for point in [NSPoint(x: 15, y: 37), NSPoint(x: 15, y: 25), NSPoint(x: 43, y: 37), NSPoint(x: 43, y: 25)] {
                NSBezierPath(ovalIn: NSRect(x: point.x - 7, y: point.y - 6, width: 12, height: 12)).fill()
            }
            NSColor(calibratedRed: 0.72, green: 0.40, blue: 0.05, alpha: 1).setStroke()
            let boneShine = NSBezierPath()
            boneShine.move(to: NSPoint(x: 22, y: 34))
            boneShine.line(to: NSPoint(x: 36, y: 28))
            boneShine.lineWidth = 2
            boneShine.stroke()
        case .trap:
            NSColor(calibratedWhite: 0.28, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 8, y: 11, width: 40, height: 9), xRadius: 3, yRadius: 3).fill()
            NSColor(calibratedRed: 0.82, green: 0.18, blue: 0.20, alpha: 1).setStroke()
            let leftJaw = NSBezierPath()
            leftJaw.move(to: NSPoint(x: 12, y: 20))
            leftJaw.curve(to: NSPoint(x: 28, y: 43), controlPoint1: NSPoint(x: 14, y: 42), controlPoint2: NSPoint(x: 23, y: 46))
            leftJaw.lineWidth = 5
            leftJaw.stroke()
            let rightJaw = NSBezierPath()
            rightJaw.move(to: NSPoint(x: 44, y: 20))
            rightJaw.curve(to: NSPoint(x: 28, y: 43), controlPoint1: NSPoint(x: 42, y: 42), controlPoint2: NSPoint(x: 33, y: 46))
            rightJaw.lineWidth = 5
            rightJaw.stroke()
            NSColor.systemYellow.setFill()
            NSBezierPath(ovalIn: NSRect(x: 25, y: 15, width: 7, height: 7)).fill()
        case .ball:
            NSColor(calibratedRed: 0.25, green: 0.72, blue: 0.88, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 8, y: 12, width: 40, height: 40)).fill()
            NSColor.white.withAlphaComponent(0.88).setStroke()
            let seam = NSBezierPath()
            seam.move(to: NSPoint(x: 14, y: 36))
            seam.curve(to: NSPoint(x: 42, y: 28), controlPoint1: NSPoint(x: 22, y: 50), controlPoint2: NSPoint(x: 35, y: 14))
            seam.lineWidth = 3
            seam.stroke()
        case .yarn:
            NSColor(calibratedRed: 0.93, green: 0.38, blue: 0.58, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 10, y: 12, width: 36, height: 36)).fill()
            NSColor(calibratedRed: 0.72, green: 0.18, blue: 0.38, alpha: 1).setStroke()
            let yarn = NSBezierPath(ovalIn: NSRect(x: 10, y: 12, width: 36, height: 36))
            yarn.lineWidth = 5
            yarn.stroke()
            let looseEnd = NSBezierPath()
            looseEnd.move(to: NSPoint(x: 40, y: 16))
            looseEnd.curve(to: NSPoint(x: 52, y: 7), controlPoint1: NSPoint(x: 50, y: 17), controlPoint2: NSPoint(x: 50, y: 8))
            looseEnd.lineWidth = 4
            looseEnd.lineCapStyle = .round
            looseEnd.stroke()
        case .robot:
            NSColor(calibratedRed: 0.52, green: 0.58, blue: 0.68, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 12, y: 12, width: 32, height: 29), xRadius: 7, yRadius: 7).fill()
            NSColor(calibratedRed: 0.70, green: 0.76, blue: 0.86, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 15, y: 29, width: 26, height: 20), xRadius: 5, yRadius: 5).fill()
            NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.27, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 20, y: 36, width: 5, height: 5)).fill()
            NSBezierPath(ovalIn: NSRect(x: 31, y: 36, width: 5, height: 5)).fill()
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: NSRect(x: 26, y: 21, width: 4, height: 4)).fill()
            NSColor(calibratedRed: 0.40, green: 0.46, blue: 0.56, alpha: 1).setStroke()
            let antenna = NSBezierPath()
            antenna.move(to: NSPoint(x: 28, y: 49))
            antenna.line(to: NSPoint(x: 28, y: 54))
            antenna.lineWidth = 3
            antenna.stroke()
            NSColor.systemYellow.setFill()
            NSBezierPath(ovalIn: NSRect(x: 25, y: 51, width: 6, height: 6)).fill()
            NSColor(calibratedRed: 0.34, green: 0.40, blue: 0.50, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 8, y: 11, width: 9, height: 7), xRadius: 3, yRadius: 3).fill()
            NSBezierPath(roundedRect: NSRect(x: 39, y: 11, width: 9, height: 7), xRadius: 3, yRadius: 3).fill()
        case .boombox:
            NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.25, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 6, y: 13, width: 44, height: 35), xRadius: 6, yRadius: 6).fill()
            NSColor(calibratedRed: 0.92, green: 0.26, blue: 0.42, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 11, y: 18, width: 15, height: 15)).fill()
            NSColor(calibratedRed: 0.25, green: 0.78, blue: 0.92, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 30, y: 18, width: 15, height: 15)).fill()
            NSColor(calibratedWhite: 0.88, alpha: 1).setStroke()
            let handle = NSBezierPath(roundedRect: NSRect(x: 17, y: 44, width: 22, height: 10), xRadius: 5, yRadius: 5)
            handle.lineWidth = 3
            handle.stroke()
            NSColor.systemYellow.setFill()
            NSBezierPath(ovalIn: NSRect(x: 25, y: 37, width: 5, height: 5)).fill()
            NSColor.white.setFill()
            "♪".draw(at: NSPoint(x: 5, y: 45), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 15), .foregroundColor: NSColor.white])
            "♫".draw(at: NSPoint(x: 42, y: 44), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor.white])
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        if let window {
            delegate?.toyPickedUp(window)
            if kind == .boombox {
                delegate?.activateBoombox(window)
            }
        }
        dragOffset = event.locationInWindow
        lastMousePoint = NSEvent.mouseLocation
        lastDragTime = Date()
        dragVelocity = .zero
    }

    override func keyDown(with event: NSEvent) {
        delegate?.handleRobotKey(event)
    }

    override func keyUp(with event: NSEvent) {
        delegate?.handleRobotKey(event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let point = NSEvent.mouseLocation
        let now = Date()
        let elapsed = max(0.001, now.timeIntervalSince(lastDragTime))
        dragVelocity = NSPoint(
            x: (point.x - lastMousePoint.x) / elapsed,
            y: (point.y - lastMousePoint.y) / elapsed
        )
        lastMousePoint = point
        lastDragTime = now
        window.setFrameOrigin(NSPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y))
    }

    override func mouseUp(with event: NSEvent) {
        if let window { delegate?.toyDropped(window, kind: kind, velocity: dragVelocity) }
    }
}

final class PopcornBucketView: NSView {
    weak var delegate: AppDelegate?

    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.withAlphaComponent(0.16).setFill()
        NSBezierPath(ovalIn: NSRect(x: 10, y: 5, width: 60, height: 13)).fill()

        let bucket = NSBezierPath()
        bucket.move(to: NSPoint(x: 14, y: 48))
        bucket.line(to: NSPoint(x: 66, y: 48))
        bucket.line(to: NSPoint(x: 58, y: 10))
        bucket.line(to: NSPoint(x: 22, y: 10))
        bucket.close()
        NSColor(calibratedRed: 0.88, green: 0.14, blue: 0.18, alpha: 1).setFill()
        bucket.fill()

        NSColor.white.withAlphaComponent(0.9).setFill()
        for x in stride(from: CGFloat(25), through: 55, by: 15) {
            NSBezierPath(rect: NSRect(x: x, y: 12, width: 7, height: 35)).fill()
        }

        NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.28, alpha: 1).setFill()
        for (x, y, size) in [(22, 52, 16.0), (36, 57, 17.0), (51, 53, 16.0), (63, 55, 14.0), (29, 63, 13.0), (47, 65, 14.0)] {
            NSBezierPath(ovalIn: NSRect(x: CGFloat(x) - size / 2, y: CGFloat(y) - size / 2, width: size, height: size)).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.popcornBucketClicked()
    }
}

final class CloneMachineView: NSView {
    weak var delegate: AppDelegate?
    private let statusLabel = NSTextField(labelWithString: "Drag Noodle into the chamber")
    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let terminateButton = NSButton(title: "Terminate clone", target: nil, action: nil)
    private let cloneCountLabel = NSTextField(labelWithString: "Clones: 1")
    private let cloneCountSlider = NSSlider(value: 1, minValue: 1, maxValue: 7, target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private var doorOpenAmount: CGFloat = 1
    private var doorTimer: Timer?
    private var cloningTimer: Timer?
    private var dramaticProgress: CGFloat = 0
    private var isCloning = false

    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
        wantsLayer = true
        statusLabel.alignment = .center
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .white.withAlphaComponent(0.9)
        addSubview(statusLabel)

        startButton.target = delegate
        startButton.action = #selector(AppDelegate.cloneMachineStartPressed(_:))
        startButton.bezelStyle = .rounded
        startButton.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        addSubview(startButton)

        terminateButton.target = delegate
        terminateButton.action = #selector(AppDelegate.terminateClonePressed(_:))
        terminateButton.bezelStyle = .rounded
        terminateButton.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        terminateButton.contentTintColor = NSColor.systemRed
        addSubview(terminateButton)

        cloneCountLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        cloneCountLabel.textColor = .white.withAlphaComponent(0.9)
        addSubview(cloneCountLabel)
        cloneCountSlider.numberOfTickMarks = 7
        cloneCountSlider.allowsTickMarkValuesOnly = true
        cloneCountSlider.target = delegate
        cloneCountSlider.action = #selector(AppDelegate.cloneCountChanged(_:))
        addSubview(cloneCountSlider)

        closeButton.target = delegate
        closeButton.action = #selector(AppDelegate.closeCloneMachine(_:))
        closeButton.bezelStyle = .rounded
        closeButton.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        addSubview(closeButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        doorTimer?.invalidate()
        cloningTimer?.invalidate()
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
        needsDisplay = true
    }

    func setCloneCount(_ count: Int) {
        cloneCountSlider.integerValue = count
        cloneCountLabel.stringValue = "Clones: \(count)"
    }

    func setDoors(open: Bool) {
        doorTimer?.invalidate()
        doorOpenAmount = open ? 1 : 0
        needsDisplay = true
    }

    func animateDoors(open: Bool, completion: @escaping () -> Void = {}) {
        doorTimer?.invalidate()
        let start = doorOpenAmount
        let end: CGFloat = open ? 1 : 0
        let started = Date()
        doorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let progress = min(1, Date().timeIntervalSince(started) / 0.85)
            self.doorOpenAmount = start + (end - start) * CGFloat(progress)
            self.needsDisplay = true
            if progress >= 1 {
                timer.invalidate()
                self.doorTimer = nil
                completion()
            }
        }
    }

    func animateCloning(completion: @escaping () -> Void) {
        cloningTimer?.invalidate()
        startButton.isEnabled = false
        terminateButton.isEnabled = false
        cloneCountSlider.isEnabled = false
        closeButton.isEnabled = false
        animateDoors(open: false) { [weak self] in
            guard let self else { return }
            self.isCloning = true
            self.dramaticProgress = 0
            self.setStatus("CLONING...")
            let started = Date()
            self.cloningTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                let progress = min(1, Date().timeIntervalSince(started) / 2.2)
                self.dramaticProgress = CGFloat(progress)
                self.needsDisplay = true
                if progress >= 1 {
                    timer.invalidate()
                    self.cloningTimer = nil
                    self.isCloning = false
                    self.dramaticProgress = 0
                    self.startButton.isEnabled = true
                    self.terminateButton.isEnabled = true
                    self.cloneCountSlider.isEnabled = true
                    self.closeButton.isEnabled = true
                    completion()
                }
            }
        }
    }

    private func chamberFrames() -> [NSRect] {
        let machine = NSRect(x: 18, y: 56, width: bounds.width - 36, height: bounds.height - 108)
        let chamberArea = machine.insetBy(dx: 16, dy: 18)
        let gap: CGFloat = 12
        let chamberWidth = (chamberArea.width - gap * 2) / 3
        return (0..<3).map { index in
            NSRect(
                x: chamberArea.minX + CGFloat(index) * (chamberWidth + gap),
                y: chamberArea.minY,
                width: chamberWidth,
                height: chamberArea.height
            )
        }
    }

    override func layout() {
        super.layout()
        statusLabel.frame = NSRect(x: 18, y: bounds.height - 42, width: bounds.width - 36, height: 22)
        startButton.frame = NSRect(x: 22, y: 16, width: 110, height: 32)
        let terminateChamber = chamberFrames()[2]
        terminateButton.frame = NSRect(x: terminateChamber.minX + 8, y: terminateChamber.minY + 12, width: terminateChamber.width - 16, height: 32)
        cloneCountLabel.frame = NSRect(x: 150, y: 21, width: 62, height: 20)
        cloneCountSlider.frame = NSRect(x: 210, y: 20, width: 150, height: 22)
        closeButton.frame = NSRect(x: bounds.maxX - 92, y: 16, width: 70, height: 32)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor(calibratedRed: 0.12, green: 0.09, blue: 0.20, alpha: 1).setFill()
        bounds.fill()

        let machine = NSRect(x: 18, y: 56, width: bounds.width - 36, height: bounds.height - 108)
        NSColor(calibratedRed: 0.30, green: 0.34, blue: 0.46, alpha: 1).setFill()
        NSBezierPath(roundedRect: machine, xRadius: 18, yRadius: 18).fill()
        let chambers = chamberFrames()
        for chamber in chambers {
            NSColor(calibratedRed: 0.28, green: 0.80, blue: 0.94, alpha: 0.28).setFill()
            NSBezierPath(roundedRect: chamber, xRadius: 13, yRadius: 13).fill()
            NSColor(calibratedRed: 0.70, green: 0.88, blue: 1.0, alpha: 0.45).setStroke()
            let glass = NSBezierPath(roundedRect: chamber, xRadius: 13, yRadius: 13)
            glass.lineWidth = 3
            glass.stroke()
        }

        let inputChamber = chambers[0]
        let doorGap = inputChamber.width * doorOpenAmount
        let doorWidth = max(0, (inputChamber.width - doorGap) / 2)
        if doorWidth > 0 {
            NSColor(calibratedRed: 0.45, green: 0.49, blue: 0.60, alpha: 0.94).setFill()
            NSBezierPath(rect: NSRect(x: inputChamber.minX, y: inputChamber.minY, width: doorWidth, height: inputChamber.height)).fill()
            NSBezierPath(rect: NSRect(x: inputChamber.maxX - doorWidth, y: inputChamber.minY, width: doorWidth, height: inputChamber.height)).fill()
            NSColor(calibratedRed: 0.80, green: 0.86, blue: 0.95, alpha: 0.7).setFill()
            NSBezierPath(ovalIn: NSRect(x: inputChamber.minX + doorWidth - 13, y: inputChamber.midY - 5, width: 10, height: 10)).fill()
            NSBezierPath(ovalIn: NSRect(x: inputChamber.maxX - doorWidth + 3, y: inputChamber.midY - 5, width: 10, height: 10)).fill()
        }

        if isCloning {
            let pulse = 0.5 + 0.5 * sin(dramaticProgress * CGFloat.pi * 14)
            let inputCenter = NSPoint(x: chambers[0].midX, y: chambers[0].midY)
            let outputCenter = NSPoint(x: chambers[1].midX, y: chambers[1].midY)
            NSColor(calibratedRed: 0.45, green: 0.92, blue: 1.0, alpha: 0.16 + pulse * 0.20).setFill()
            NSBezierPath(ovalIn: NSRect(x: outputCenter.x - 48 - pulse * 8, y: outputCenter.y - 48 - pulse * 8, width: 96 + pulse * 16, height: 96 + pulse * 16)).fill()

            NSColor(calibratedRed: 0.45, green: 0.92, blue: 1.0, alpha: 0.55 + pulse * 0.4).setStroke()
            let beam = NSBezierPath()
            beam.move(to: NSPoint(x: inputCenter.x + 22, y: inputCenter.y))
            beam.curve(to: NSPoint(x: outputCenter.x - 22, y: outputCenter.y), controlPoint1: NSPoint(x: inputCenter.x + 70, y: inputCenter.y + 34 * sin(dramaticProgress * 18)), controlPoint2: NSPoint(x: outputCenter.x - 70, y: outputCenter.y - 34 * sin(dramaticProgress * 18)))
            beam.lineWidth = 4 + pulse * 4
            beam.lineCapStyle = .round
            beam.stroke()

            for index in 0..<8 {
                let angle = dramaticProgress * 18 + CGFloat(index) * 0.78
                let radius: CGFloat = 34 + pulse * 18
                let spark = NSPoint(x: outputCenter.x + cos(angle) * radius, y: outputCenter.y + sin(angle) * radius)
                NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.28, alpha: 0.8).setFill()
                NSBezierPath(ovalIn: NSRect(x: spark.x - 3, y: spark.y - 3, width: 6, height: 6)).fill()
            }
        }

        let chamberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        ("ORIGINAL / INPUT" as NSString).draw(at: NSPoint(x: chambers[0].midX - 49, y: chambers[0].maxY - 22), withAttributes: chamberAttributes)
        ("CLONE OUTPUT" as NSString).draw(at: NSPoint(x: chambers[1].midX - 42, y: chambers[1].maxY - 22), withAttributes: chamberAttributes)
        ("TERMINATE" as NSString).draw(at: NSPoint(x: chambers[2].midX - 30, y: chambers[2].maxY - 22), withAttributes: chamberAttributes)

        NSColor(calibratedRed: 0.95, green: 0.25, blue: 0.32, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: machine.minX + 20, y: machine.maxY - 18, width: 22, height: 10), xRadius: 4, yRadius: 4).fill()
        NSColor(calibratedRed: 0.98, green: 0.74, blue: 0.22, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: machine.maxX - 42, y: machine.maxY - 20, width: 12, height: 12)).fill()
    }
}

final class StatChangerView: NSView {
    weak var delegate: AppDelegate?
    private let bounceTitle = NSTextField(labelWithString: "Bounciness")
    private let gravityTitle = NSTextField(labelWithString: "Gravity")
    private let hungerTitle = NSTextField(labelWithString: "Hunger level")
    private let sizeTitle = NSTextField(labelWithString: "Size")
    private let bounceValue = NSTextField(labelWithString: "78%")
    private let gravityValue = NSTextField(labelWithString: "980")
    private let hungerValue = NSTextField(labelWithString: "100%")
    private let sizeValue = NSTextField(labelWithString: "100%")
    private let bounceSlider = NSSlider(value: 0.78, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)
    private let gravitySlider = NSSlider(value: 980, minValue: 0, maxValue: 1800, target: nil, action: nil)
    private let hungerSlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let sizeSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 1.5, target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "Feed Noodle a treat, then drag him into the chamber")
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)

    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
        wantsLayer = true

        bounceTitle.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        gravityTitle.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        hungerTitle.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        sizeTitle.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        bounceValue.alignment = .right
        gravityValue.alignment = .right
        hungerValue.alignment = .right
        sizeValue.alignment = .right
        [bounceTitle, gravityTitle, hungerTitle, sizeTitle, bounceValue, gravityValue, hungerValue, sizeValue].forEach {
            $0.textColor = .white.withAlphaComponent(0.92)
            addSubview($0)
        }

        bounceSlider.numberOfTickMarks = 10
        bounceSlider.allowsTickMarkValuesOnly = false
        bounceSlider.target = delegate
        bounceSlider.action = #selector(AppDelegate.statBounceChanged(_:))
        gravitySlider.numberOfTickMarks = 10
        gravitySlider.allowsTickMarkValuesOnly = false
        gravitySlider.target = delegate
        gravitySlider.action = #selector(AppDelegate.statGravityChanged(_:))
        hungerSlider.numberOfTickMarks = 10
        hungerSlider.allowsTickMarkValuesOnly = false
        hungerSlider.target = delegate
        hungerSlider.action = #selector(AppDelegate.statHungerChanged(_:))
        sizeSlider.numberOfTickMarks = 10
        sizeSlider.allowsTickMarkValuesOnly = false
        sizeSlider.target = delegate
        sizeSlider.action = #selector(AppDelegate.statSizeChanged(_:))
        addSubview(bounceSlider)
        addSubview(gravitySlider)
        addSubview(hungerSlider)
        addSubview(sizeSlider)

        statusLabel.alignment = .center
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .white.withAlphaComponent(0.78)
        addSubview(statusLabel)
        bounceSlider.isEnabled = false
        gravitySlider.isEnabled = false
        hungerSlider.isEnabled = false
        sizeSlider.isEnabled = false

        closeButton.target = delegate
        closeButton.action = #selector(AppDelegate.closeStatChanger(_:))
        closeButton.bezelStyle = .rounded
        addSubview(closeButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValues(bounce: CGFloat, gravity: CGFloat, hunger: CGFloat, size: CGFloat) {
        bounceSlider.doubleValue = Double(bounce)
        gravitySlider.doubleValue = Double(gravity)
        hungerSlider.doubleValue = Double(hunger)
        sizeSlider.doubleValue = Double(size)
        updateLabels()
    }

    func updateLabels() {
        bounceValue.stringValue = "\(Int(round(bounceSlider.doubleValue * 100)))%"
        gravityValue.stringValue = "\(Int(round(gravitySlider.doubleValue)))"
        hungerValue.stringValue = "\(Int(round(hungerSlider.doubleValue)))%"
        sizeValue.stringValue = "\(Int(round(sizeSlider.doubleValue * 100)))%"
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
        needsDisplay = true
    }

    func setNoodleInside(_ inside: Bool) {
        bounceSlider.isEnabled = inside
        gravitySlider.isEnabled = inside
        hungerSlider.isEnabled = inside
        sizeSlider.isEnabled = inside
        statusLabel.stringValue = inside ? "Noodle is inside — adjust his stats" : "Feed Noodle a treat, then drag him into the chamber"
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let controlX: CGFloat = 154
        let controlWidth = bounds.width - controlX - 28
        bounceTitle.frame = NSRect(x: controlX, y: bounds.height - 72, width: 130, height: 22)
        bounceValue.frame = NSRect(x: bounds.width - 78, y: bounds.height - 72, width: 50, height: 22)
        bounceSlider.frame = NSRect(x: controlX, y: bounds.height - 106, width: controlWidth, height: 24)
        gravityTitle.frame = NSRect(x: controlX, y: bounds.height - 146, width: 130, height: 22)
        gravityValue.frame = NSRect(x: bounds.width - 78, y: bounds.height - 146, width: 50, height: 22)
        gravitySlider.frame = NSRect(x: controlX, y: bounds.height - 180, width: controlWidth, height: 24)
        hungerTitle.frame = NSRect(x: controlX, y: bounds.height - 220, width: 130, height: 22)
        hungerValue.frame = NSRect(x: bounds.width - 78, y: bounds.height - 220, width: 50, height: 22)
        hungerSlider.frame = NSRect(x: controlX, y: bounds.height - 254, width: controlWidth, height: 24)
        sizeTitle.frame = NSRect(x: controlX, y: bounds.height - 294, width: 130, height: 22)
        sizeValue.frame = NSRect(x: bounds.width - 78, y: bounds.height - 294, width: 50, height: 22)
        sizeSlider.frame = NSRect(x: controlX, y: bounds.height - 328, width: controlWidth, height: 24)
        statusLabel.frame = NSRect(x: 20, y: 48, width: bounds.width - 40, height: 20)
        closeButton.frame = NSRect(x: bounds.width - 100, y: 38, width: 72, height: 30)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.18, alpha: 1).setFill()
        bounds.fill()
        let machine = bounds.insetBy(dx: 16, dy: 22)
        NSColor(calibratedRed: 0.28, green: 0.34, blue: 0.48, alpha: 1).setFill()
        NSBezierPath(roundedRect: machine, xRadius: 18, yRadius: 18).fill()
        let chamber = NSRect(x: 28, y: 72, width: 102, height: 140)
        NSColor(calibratedRed: 0.25, green: 0.78, blue: 0.94, alpha: 0.22).setFill()
        NSBezierPath(roundedRect: chamber, xRadius: 14, yRadius: 14).fill()
        NSColor(calibratedRed: 0.70, green: 0.88, blue: 1.0, alpha: 0.50).setStroke()
        let glass = NSBezierPath(roundedRect: chamber, xRadius: 14, yRadius: 14)
        glass.lineWidth = 3
        glass.stroke()
        NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.98, alpha: 0.18).setFill()
        NSBezierPath(roundedRect: NSRect(x: 166, y: 196, width: bounds.width - 194, height: 18), xRadius: 8, yRadius: 8).fill()
        NSColor.systemGreen.setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.width - 52, y: bounds.height - 36, width: 10, height: 10)).fill()
    }
}

final class TutorialView: NSView {
    weak var delegate: AppDelegate?
    private let textView = NSTextView()
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)

    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
        wantsLayer = true
        textView.string = """
        Welcome to Noodle!

        Click Noodle to open his menu. From there you can pet him, cage him, reset him, make him wander, follow your mouse, or start tricks.

        Drag Noodle and release him to make him bounce like a tennis ball. He gets angry when you throw him, then settles back into wandering.

        Toys:
        • Treat: drag it into a machine or throw it to Noodle.
        • Ball and yarn: drag and release them so Noodle chases and brings them back.
        • Robot: click it, then use W A S D. It also wanders by itself.
        • Boom box: click it to make Noodle and clones dance.

        Machines:
        Put a treat inside first, then drag Noodle into the chamber. The Clone Machine creates clones, and the Stat Changer unlocks bounciness and gravity controls.

        Disco mode plays your dance music with lights, fog, sparks, jumps, and effects. Spin until stopped is a persistent trick you can turn off from the Play menu.

        Tip: Triple-press Backspace to toggle Noodle on or off screen.
        """
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = .labelColor
        addSubview(textView)

        closeButton.target = delegate
        closeButton.action = #selector(AppDelegate.closeTutorial(_:))
        closeButton.bezelStyle = .rounded
        addSubview(closeButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        textView.frame = NSRect(x: 24, y: 58, width: bounds.width - 48, height: bounds.height - 76)
        closeButton.frame = NSRect(x: bounds.width - 100, y: 18, width: 72, height: 30)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
        bounds.fill()
    }
}

final class ToyPaletteItem: NSView {
    weak var delegate: AppDelegate?
    let kind: ToyKind
    let title: String
    private var dragStart = NSPoint.zero
    private var isDragging = false

    init(delegate: AppDelegate, kind: ToyKind, title: String) {
        self.delegate = delegate
        self.kind = kind
        self.title = title
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        isDragging = false
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        if hypot(event.locationInWindow.x - dragStart.x, event.locationInWindow.y - dragStart.y) > 5 {
            isDragging = true
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        NSCursor.pop()
        delegate?.spawnToyFromPanel(kind, at: NSEvent.mouseLocation)
        isDragging = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let colors: [ToyKind: NSColor] = [
            .treat: NSColor(calibratedRed: 0.96, green: 0.64, blue: 0.22, alpha: 1),
            .ball: NSColor(calibratedRed: 0.25, green: 0.72, blue: 0.88, alpha: 1),
            .yarn: NSColor(calibratedRed: 0.93, green: 0.38, blue: 0.58, alpha: 1),
            .robot: NSColor(calibratedRed: 0.52, green: 0.58, blue: 0.68, alpha: 1),
            .boombox: NSColor(calibratedRed: 0.70, green: 0.24, blue: 0.50, alpha: 1)
        ]
        colors[kind]?.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 12, yRadius: 12).fill()
        NSColor.white.withAlphaComponent(isDragging ? 1 : 0.84).setStroke()
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 12, yRadius: 12)
        outline.lineWidth = isDragging ? 4 : 2
        outline.stroke()
        (title as NSString).draw(at: NSPoint(x: bounds.midX - (title as NSString).size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: 14)]).width / 2, y: bounds.midY - 8), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor.white])
    }
}

final class ToyPanelView: NSView {
    weak var delegate: AppDelegate?
    private let items: [ToyPaletteItem]
    private let titleLabel = NSTextField(labelWithString: "Drag a toy card onto the desktop")

    init(delegate: AppDelegate) {
        self.delegate = delegate
        items = [
            ToyPaletteItem(delegate: delegate, kind: .treat, title: "Treat"),
            ToyPaletteItem(delegate: delegate, kind: .ball, title: "Ball"),
            ToyPaletteItem(delegate: delegate, kind: .yarn, title: "Yarn"),
            ToyPaletteItem(delegate: delegate, kind: .robot, title: "Robot"),
            ToyPaletteItem(delegate: delegate, kind: .boombox, title: "Boom box")
        ]
        super.init(frame: .zero)
        wantsLayer = true
        titleLabel.alignment = .center
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white.withAlphaComponent(0.9)
        addSubview(titleLabel)
        items.forEach(addSubview)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        titleLabel.frame = NSRect(x: 16, y: bounds.height - 42, width: bounds.width - 32, height: 24)
        let cardWidth = (bounds.width - 48) / 2
        for (index, item) in items.enumerated() {
            let column = index % 2
            let row = index / 2
            item.frame = NSRect(x: 16 + CGFloat(column) * (cardWidth + 16), y: bounds.height - 104 - CGFloat(row) * 62, width: cardWidth, height: 48)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.18, alpha: 1).setFill()
        bounds.fill()
    }
}

final class ClonePet {
    let window: PetWindow
    let view: CatView
    private var target = NSPoint.zero
    let mirrorOffset: NSPoint

    init(delegate: AppDelegate, origin: NSPoint, avatarImage: NSImage?, mirrorOffset: NSPoint = .zero) {
        self.mirrorOffset = mirrorOffset
        window = PetWindow(contentRect: NSRect(origin: origin, size: NSSize(width: petSize, height: petSize)), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        view = CatView(frame: NSRect(x: 0, y: 0, width: petSize, height: petSize))
        view.hostWindow = window
        view.delegate = delegate
        view.avatarImage = avatarImage
        view.menu = delegate.makePetMenu()
        window.contentView = view
        window.orderFrontRegardless()
        chooseNewTarget(in: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900))
    }

    func update(in screen: NSRect) {
        view.animationTime += 1.0 / 60.0
        let current = window.frame.origin
        let dx = target.x - current.x
        let dy = target.y - current.y
        let distance = sqrt(dx * dx + dy * dy)
        view.setWalking(distance >= 16)
        if distance < 16 {
            chooseNewTarget(in: screen)
        } else {
            let step = min(distance, max(2.2, distance * 0.024))
            window.setFrameOrigin(NSPoint(x: current.x + dx / distance * step, y: current.y + dy / distance * step))
        }
        view.needsDisplay = true
    }

    func setTarget(_ target: NSPoint) {
        self.target = target
    }

    func startPlaying() {
        view.trick = "Dance"
    }

    func mirror(leaderWindow: NSWindow, leaderView: CatView, in screen: NSRect, dancing: Bool) {
        let desired = NSPoint(
            x: min(max(leaderWindow.frame.minX + mirrorOffset.x, screen.minX + 8), screen.maxX - petSize - 8),
            y: min(max(leaderWindow.frame.minY + mirrorOffset.y, screen.minY + 8), screen.maxY - petSize - 8)
        )
        let current = window.frame.origin
        let dx = desired.x - current.x
        let dy = desired.y - current.y
        let distance = hypot(dx, dy)
        if distance > 2 {
            let step = min(distance, max(2.5, distance * 0.08))
            window.setFrameOrigin(NSPoint(x: current.x + dx / distance * step, y: current.y + dy / distance * step))
        }
        view.setWalking(leaderView.isWalking || distance > 16)
        view.trick = dancing ? "Dance" : leaderView.trick
        view.animationTime = leaderView.animationTime
        view.needsDisplay = true
    }

    private func chooseNewTarget(in screen: NSRect) {
        target = NSPoint(
            x: CGFloat.random(in: screen.minX + 35 ... screen.maxX - petSize - 35),
            y: CGFloat.random(in: screen.minY + 25 ... screen.maxY - petSize - 25)
        )
    }
}

final class CatView: NSView {
    weak var hostWindow: NSWindow?
    weak var delegate: AppDelegate?
    var avatarImage: NSImage? { didSet { needsDisplay = true } }
    var isWalking = true
    var isCaged = false { didSet { needsDisplay = true } }
    var speechText = "" {
        didSet {
            // The launch/reset box is a true pause state. Never let a queued
            // action or timer put a speech bubble over the closed box.
            if !speechText.isEmpty && (isInLaunchBox || delegate?.isLaunchBoxPaused == true) {
                speechText = ""
                return
            }
            needsDisplay = true
        }
    }
    var hunger: CGFloat = 100 { didSet { needsDisplay = true } }
    var hungerLocked = false { didSet { needsDisplay = true } }
    var isDead = false { didSet { needsDisplay = true } }
    var isInLaunchBox = false { didSet { needsDisplay = true } }
    var showTreats = false { didSet { needsDisplay = true } }
    var showPopcornMachine = false { didSet { needsDisplay = true } }
    var displayScale: CGFloat = 1 { didSet { needsDisplay = true } }
    var trick = ""
    var animationTime: CGFloat = 0
    private var dragOffset = CGPoint.zero
    private var mouseDownPoint = NSPoint.zero
    private var didDrag = false
    private var lastMousePoint = NSPoint.zero
    private var lastDragTime = Date()
    private var dragVelocity = NSPoint.zero

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let time = animationTime
        let walkPhase = time * 9.0
        let loweredTrick = trick.lowercased()
        let isDancing = loweredTrick.contains("dance")
        let isSpinning = loweredTrick.contains("spin")
        let isRolling = loweredTrick.contains("roll")
        let isJumping = loweredTrick.contains("jump")
        let isStretching = loweredTrick.contains("stretch")
        let bob = isJumping ? abs(sin(time * 8.0)) * 34.0 : (isDancing ? abs(sin(time * 11.0)) * 24.0 : (isStretching ? abs(sin(time * 3.0)) * 5.0 : (isWalking ? abs(sin(walkPhase)) * 4.0 : sin(time * 2.2) * 1.2)))
        let w = bounds.width

        NSGraphicsContext.saveGraphicsState()
        if displayScale != 1 {
            let transform = NSAffineTransform()
            transform.translateX(by: bounds.midX, yBy: bounds.midY)
            transform.scale(by: displayScale)
            transform.translateX(by: -bounds.midX, yBy: -bounds.midY)
            transform.concat()
        }

        // A soft grounding shadow keeps the avatar readable over any desktop.
        NSColor.black.withAlphaComponent(isWalking ? 0.13 : 0.16).setFill()
        let shadowWidth = isWalking ? (w - 60) - abs(sin(walkPhase)) * 10 : w - 60
        NSBezierPath(ovalIn: NSRect(x: (w - shadowWidth) / 2, y: 11, width: shadowWidth, height: 18)).fill()

        if isSpinning || isRolling {
            let spinTransform = NSAffineTransform()
            spinTransform.translateX(by: bounds.midX, yBy: bounds.midY)
            spinTransform.rotate(byRadians: time * (isRolling ? 4.5 : 9.0))
            spinTransform.translateX(by: -bounds.midX, yBy: -bounds.midY)
            spinTransform.concat()
        } else if isDancing {
            let danceTransform = NSAffineTransform()
            danceTransform.translateX(by: bounds.midX, yBy: 0)
            danceTransform.rotate(byRadians: CGFloat(sin(time * 11.0) * 0.10))
            danceTransform.translateX(by: -bounds.midX, yBy: 0)
            danceTransform.concat()
        }

        let body = NSRect(x: 35, y: 30 + bob, width: w - 70, height: 82)
        let head = NSRect(x: 25, y: 76 + bob, width: w - 50, height: 84)

        // Tail.
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: body.maxX - 4, y: body.minY + 25))
        tail.curve(to: NSPoint(x: w - 36, y: 100 + bob),
                   controlPoint1: NSPoint(x: w - 12, y: body.minY + 10),
                   controlPoint2: NSPoint(x: w - 16, y: 87 + bob))
        tail.curve(to: NSPoint(x: w - 48, y: 142 + bob),
                   controlPoint1: NSPoint(x: w - 22, y: 125 + bob),
                   controlPoint2: NSPoint(x: w - 30, y: 143 + bob))
        tail.lineWidth = 16
        tail.lineCapStyle = .round
        NSColor(calibratedRed: 0.98, green: 0.65, blue: 0.32, alpha: 1).setStroke()
        tail.stroke()

        // Body, using the imported photo as a clipped avatar when present.
        if let image = avatarImage {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(ovalIn: body).addClip()
            image.draw(in: body, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            NSColor.white.withAlphaComponent(0.22).setStroke()
            let outline = NSBezierPath(ovalIn: body.insetBy(dx: 1, dy: 1))
            outline.lineWidth = 3
            outline.stroke()
        } else {
            NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.50, alpha: 1).setFill()
            NSBezierPath(ovalIn: body).fill()
            NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.70, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: body.midX - 30, y: body.minY + 10, width: 60, height: 45)).fill()
        }

        // Ears.
        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: head.minX + 11, y: head.maxY - 23))
        leftEar.line(to: NSPoint(x: head.minX + 22, y: head.maxY + 11))
        leftEar.line(to: NSPoint(x: head.minX + 53, y: head.maxY - 15))
        leftEar.close()
        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: head.maxX - 53, y: head.maxY - 15))
        rightEar.line(to: NSPoint(x: head.maxX - 22, y: head.maxY + 11))
        rightEar.line(to: NSPoint(x: head.maxX - 11, y: head.maxY - 23))
        rightEar.close()
        NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.50, alpha: 1).setFill()
        leftEar.fill(); rightEar.fill()
        NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.43, alpha: 0.7).setFill()
        let innerLeft = NSBezierPath(); innerLeft.move(to: NSPoint(x: head.minX + 23, y: head.maxY - 16)); innerLeft.line(to: NSPoint(x: head.minX + 28, y: head.maxY - 1)); innerLeft.line(to: NSPoint(x: head.minX + 41, y: head.maxY - 14)); innerLeft.close(); innerLeft.fill()
        let innerRight = NSBezierPath(); innerRight.move(to: NSPoint(x: head.maxX - 41, y: head.maxY - 14)); innerRight.line(to: NSPoint(x: head.maxX - 28, y: head.maxY - 1)); innerRight.line(to: NSPoint(x: head.maxX - 23, y: head.maxY - 16)); innerRight.close(); innerRight.fill()

        // Head and face.
        NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.50, alpha: 1).setFill()
        NSBezierPath(ovalIn: head).fill()

        // Tabby stripes.
        NSColor(calibratedRed: 0.88, green: 0.42, blue: 0.18, alpha: 0.8).setStroke()
        for offset in [-18.0, 0.0, 18.0] {
            let stripe = NSBezierPath()
            stripe.move(to: NSPoint(x: head.midX + offset, y: head.maxY - 6))
            stripe.line(to: NSPoint(x: head.midX + offset * 0.8, y: head.maxY - 23))
            stripe.lineWidth = 5
            stripe.lineCapStyle = .round
            stripe.stroke()
        }

        let expression: String
        if isCaged {
            expression = "sad"
        } else if isDead || loweredTrick.contains("dead") {
            expression = "dead"
        } else if loweredTrick.contains("angry") {
            expression = "angry"
        } else if loweredTrick.contains("nap") {
            expression = "sleepy"
        } else if loweredTrick.contains("wave") {
            expression = "happy"
        } else if loweredTrick.contains("zoom") || loweredTrick.contains("spin") || loweredTrick.contains("roll") {
            expression = "surprised"
        } else if loweredTrick.contains("dance") {
            expression = "happy"
        } else {
            expression = "cute"
        }

        let blink = expression == "cute" && Int(time * 1.4) % 53 == 0
        let eyeY = head.midY + 5
        let eyeColor = NSColor(calibratedRed: 0.21, green: 0.14, blue: 0.12, alpha: 1)
        eyeColor.setStroke()
        eyeColor.setFill()
        if expression == "happy" {
            for x in [head.midX - 23, head.midX + 23] {
                let eye = NSBezierPath(); eye.move(to: NSPoint(x: x - 7, y: eyeY)); eye.curve(to: NSPoint(x: x + 7, y: eyeY), controlPoint1: NSPoint(x: x - 3, y: eyeY + 8), controlPoint2: NSPoint(x: x + 3, y: eyeY + 8)); eye.lineWidth = 3; eye.stroke()
            }
        } else if expression == "sleepy" {
            for x in [head.midX - 23, head.midX + 23] {
                NSBezierPath(ovalIn: NSRect(x: x - 10, y: eyeY - 2, width: 20, height: 6)).fill()
            }
        } else if expression == "sad" {
            NSBezierPath(ovalIn: NSRect(x: head.midX - 33, y: eyeY - 12, width: 23, height: 29)).fill()
            NSBezierPath(ovalIn: NSRect(x: head.midX + 10, y: eyeY - 12, width: 23, height: 29)).fill()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: head.midX - 28, y: eyeY + 4, width: 8, height: 10)).fill()
            NSBezierPath(ovalIn: NSRect(x: head.midX + 15, y: eyeY + 4, width: 8, height: 10)).fill()
        } else if expression == "surprised" {
            NSBezierPath(ovalIn: NSRect(x: head.midX - 36, y: eyeY - 16, width: 28, height: 36)).fill()
            NSBezierPath(ovalIn: NSRect(x: head.midX + 8, y: eyeY - 16, width: 28, height: 36)).fill()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: head.midX - 30, y: eyeY + 3, width: 9, height: 11)).fill()
            NSBezierPath(ovalIn: NSRect(x: head.midX + 14, y: eyeY + 3, width: 9, height: 11)).fill()
        } else if expression == "angry" {
            for x in [head.midX - 23, head.midX + 23] {
                let eye = NSBezierPath(ovalIn: NSRect(x: x - 9, y: eyeY - 8, width: 18, height: 22))
                eye.fill()
            }
            NSColor(calibratedRed: 0.75, green: 0.08, blue: 0.08, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: head.midX - 4, y: eyeY - 1, width: 8, height: 8)).fill()
            NSBezierPath(ovalIn: NSRect(x: head.midX - 27, y: eyeY + 17, width: 16, height: 4)).fill()
            NSBezierPath(ovalIn: NSRect(x: head.midX + 11, y: eyeY + 17, width: 16, height: 4)).fill()
        } else if expression == "dead" {
            eyeColor.setStroke()
            for x in [head.midX - 23, head.midX + 23] {
                let cross = NSBezierPath()
                cross.move(to: NSPoint(x: x - 8, y: eyeY - 8)); cross.line(to: NSPoint(x: x + 8, y: eyeY + 8))
                cross.move(to: NSPoint(x: x + 8, y: eyeY - 8)); cross.line(to: NSPoint(x: x - 8, y: eyeY + 8))
                cross.lineWidth = 4
                cross.stroke()
            }
        } else if blink {
            eyeColor.setStroke()
            for x in [head.midX - 23, head.midX + 23] {
                let eye = NSBezierPath(); eye.move(to: NSPoint(x: x - 6, y: eyeY)); eye.curve(to: NSPoint(x: x + 6, y: eyeY), controlPoint1: NSPoint(x: x - 2, y: eyeY - 4), controlPoint2: NSPoint(x: x + 2, y: eyeY - 4)); eye.lineWidth = 3; eye.stroke()
            }
        } else {
            NSBezierPath(ovalIn: NSRect(x: head.midX - 33, y: eyeY - 12, width: 23, height: 29)).fill()
            NSBezierPath(ovalIn: NSRect(x: head.midX + 10, y: eyeY - 12, width: 23, height: 29)).fill()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: head.midX - 28, y: eyeY + 4, width: 8, height: 10)).fill()
            NSBezierPath(ovalIn: NSRect(x: head.midX + 15, y: eyeY + 4, width: 8, height: 10)).fill()
        }

        NSColor(calibratedRed: 0.92, green: 0.34, blue: 0.36, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: head.midX - 6, y: head.midY - 14, width: 12, height: 8)).fill()
        NSColor(calibratedRed: 0.27, green: 0.16, blue: 0.13, alpha: 1).setStroke()
        if expression == "surprised" {
            NSBezierPath(ovalIn: NSRect(x: head.midX - 8, y: head.midY - 31, width: 16, height: 19)).fill()
        } else if expression == "sleepy" {
            let mouth = NSBezierPath(); mouth.move(to: NSPoint(x: head.midX - 6, y: head.midY - 23)); mouth.curve(to: NSPoint(x: head.midX + 6, y: head.midY - 23), controlPoint1: NSPoint(x: head.midX - 2, y: head.midY - 19), controlPoint2: NSPoint(x: head.midX + 2, y: head.midY - 19)); mouth.lineWidth = 2.5; mouth.stroke()
        } else if expression == "sad" {
            let mouth = NSBezierPath(); mouth.move(to: NSPoint(x: head.midX - 8, y: head.midY - 26)); mouth.curve(to: NSPoint(x: head.midX + 8, y: head.midY - 26), controlPoint1: NSPoint(x: head.midX - 4, y: head.midY - 16), controlPoint2: NSPoint(x: head.midX + 4, y: head.midY - 16)); mouth.lineWidth = 2.5; mouth.stroke()
        } else if expression == "angry" {
            let mouth = NSBezierPath(); mouth.move(to: NSPoint(x: head.midX - 9, y: head.midY - 22)); mouth.curve(to: NSPoint(x: head.midX + 9, y: head.midY - 22), controlPoint1: NSPoint(x: head.midX - 4, y: head.midY - 31), controlPoint2: NSPoint(x: head.midX + 4, y: head.midY - 31)); mouth.lineWidth = 3; mouth.stroke()
        } else if expression == "dead" {
            let mouth = NSBezierPath(ovalIn: NSRect(x: head.midX - 9, y: head.midY - 31, width: 18, height: 12))
            mouth.lineWidth = 2.5
            mouth.stroke()
        } else {
            let cuteMouth = NSBezierPath()
            cuteMouth.move(to: NSPoint(x: head.midX - 2, y: head.midY - 20))
            cuteMouth.curve(to: NSPoint(x: head.midX + 8, y: head.midY - 23), controlPoint1: NSPoint(x: head.midX + 3, y: head.midY - 18), controlPoint2: NSPoint(x: head.midX + 8, y: head.midY - 18))
            cuteMouth.curve(to: NSPoint(x: head.midX - 2, y: head.midY - 27), controlPoint1: NSPoint(x: head.midX + 8, y: head.midY - 28), controlPoint2: NSPoint(x: head.midX + 3, y: head.midY - 28))
            cuteMouth.lineWidth = 2.5
            cuteMouth.lineCapStyle = .round
            cuteMouth.stroke()
        }

        if expression == "sad" {
            let tearDrop = NSBezierPath()
            tearDrop.move(to: NSPoint(x: head.midX - 22, y: eyeY - 15))
            tearDrop.curve(to: NSPoint(x: head.midX - 22, y: eyeY - 31), controlPoint1: NSPoint(x: head.midX - 29, y: eyeY - 22), controlPoint2: NSPoint(x: head.midX - 27, y: eyeY - 28))
            tearDrop.curve(to: NSPoint(x: head.midX - 22, y: eyeY - 15), controlPoint1: NSPoint(x: head.midX - 17, y: eyeY - 28), controlPoint2: NSPoint(x: head.midX - 16, y: eyeY - 22))
            tearDrop.close()
            NSColor(calibratedRed: 0.25, green: 0.65, blue: 0.98, alpha: 0.9).setFill()
            tearDrop.fill()
            let secondTear = tearDrop.copy() as! NSBezierPath
            secondTear.transform(using: AffineTransform(translationByX: 44, byY: 0))
            secondTear.fill()
        }

        // Whiskers.
        for y in [-4.0, 5.0, 14.0] {
            let whisker = NSBezierPath(); whisker.move(to: NSPoint(x: head.minX + 42, y: head.midY + y)); whisker.line(to: NSPoint(x: head.minX + 3, y: head.midY + y + (y / 3))); whisker.move(to: NSPoint(x: head.maxX - 42, y: head.midY + y)); whisker.line(to: NSPoint(x: head.maxX - 3, y: head.midY + y + (y / 3))); whisker.lineWidth = 1.5; whisker.stroke()
        }

        // Trick poses.
        if trick.lowercased().contains("wave") {
            NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.50, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: head.maxX - 11, y: body.maxY - 2, width: 30, height: 48)).fill()
        } else if trick.lowercased().contains("nap") {
            NSColor.white.withAlphaComponent(0.85).setFill()
            let z = "Z  Z"
            z.draw(at: NSPoint(x: head.maxX - 4, y: head.maxY - 12), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 15), .foregroundColor: NSColor.white])
        } else if trick.lowercased().contains("zoom") || trick.lowercased().contains("spin") {
            NSColor.white.withAlphaComponent(0.8).setStroke()
            let motion = NSBezierPath(); motion.move(to: NSPoint(x: 12, y: 75)); motion.curve(to: NSPoint(x: 27, y: 92), controlPoint1: NSPoint(x: 4, y: 90), controlPoint2: NSPoint(x: 14, y: 104)); motion.lineWidth = 4; motion.lineCapStyle = .round; motion.stroke()
        } else if loweredTrick.contains("jump") {
            NSColor.white.withAlphaComponent(0.85).setStroke()
            let motion = NSBezierPath()
            motion.move(to: NSPoint(x: 14, y: 34)); motion.line(to: NSPoint(x: 30, y: 22))
            motion.move(to: NSPoint(x: w - 14, y: 34)); motion.line(to: NSPoint(x: w - 30, y: 22))
            motion.lineWidth = 4
            motion.lineCapStyle = .round
            motion.stroke()
        } else if loweredTrick.contains("beg") {
            NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.50, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: body.minX - 15, y: body.maxY - 22, width: 28, height: 42)).fill()
            NSBezierPath(ovalIn: NSRect(x: body.maxX - 13, y: body.maxY - 22, width: 28, height: 42)).fill()
        } else if loweredTrick.contains("stretch") {
            NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.50, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: body.minX - 30, y: body.minY + 20, width: 46, height: 28)).fill()
            NSBezierPath(ovalIn: NSRect(x: body.maxX - 16, y: body.minY + 20, width: 46, height: 28)).fill()
        } else if loweredTrick.contains("roll") {
            NSColor.white.withAlphaComponent(0.8).setStroke()
            let rollLines = NSBezierPath()
            rollLines.move(to: NSPoint(x: 12, y: 92)); rollLines.line(to: NSPoint(x: 30, y: 104))
            rollLines.move(to: NSPoint(x: w - 12, y: 92)); rollLines.line(to: NSPoint(x: w - 30, y: 104))
            rollLines.lineWidth = 4
            rollLines.stroke()
        } else if trick.lowercased().contains("dance") {
            NSColor.white.withAlphaComponent(0.9).setFill()
            "♪  ♫".draw(at: NSPoint(x: 18, y: 162), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 18), .foregroundColor: NSColor.white])
        }

        if isCaged {
            let cage = NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 8), xRadius: 18, yRadius: 18)
            NSColor(calibratedWhite: 0.28, alpha: 0.78).setStroke()
            cage.lineWidth = 5
            cage.stroke()
            for x in stride(from: bounds.minX + 28, through: bounds.maxX - 28, by: 28) {
                let bar = NSBezierPath(); bar.move(to: NSPoint(x: x, y: bounds.minY + 14)); bar.line(to: NSPoint(x: x, y: bounds.maxY - 14)); bar.lineWidth = 3; bar.stroke()
            }
        }

        if showPopcornMachine {
            let machine = NSRect(x: bounds.maxX - 82, y: 12, width: 66, height: 60)
            NSColor(calibratedRed: 0.82, green: 0.22, blue: 0.26, alpha: 1).setFill()
            NSBezierPath(roundedRect: machine, xRadius: 10, yRadius: 10).fill()
            NSColor(calibratedWhite: 0.98, alpha: 0.92).setFill()
            NSBezierPath(roundedRect: NSRect(x: machine.minX + 8, y: machine.minY + 21, width: machine.width - 16, height: 27), xRadius: 7, yRadius: 7).fill()
            NSColor(calibratedRed: 0.98, green: 0.74, blue: 0.28, alpha: 1).setFill()
            for (x, y, size) in [(machine.minX + 21, machine.minY + 37, 8.0), (machine.minX + 34, machine.minY + 31, 7.0), (machine.minX + 45, machine.minY + 39, 8.0)] {
                NSBezierPath(ovalIn: NSRect(x: x - size / 2, y: y - size / 2, width: size, height: size)).fill()
            }
            NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: machine.minX + 22, y: machine.minY + 5, width: 22, height: 10), xRadius: 3, yRadius: 3).fill()
            NSColor.white.withAlphaComponent(0.8).setFill()
            NSBezierPath(ovalIn: NSRect(x: machine.minX + 28, y: machine.maxY - 3, width: 8, height: 8)).fill()
        }

        if showTreats {
            NSColor(calibratedRed: 0.96, green: 0.64, blue: 0.22, alpha: 1).setFill()
            for (x, y) in [(head.midX - 18, head.midY - 27), (head.midX, head.midY - 34), (head.midX + 18, head.midY - 27)] {
                NSBezierPath(ovalIn: NSRect(x: x - 8, y: y - 5, width: 16, height: 10)).fill()
                NSColor(calibratedRed: 0.70, green: 0.34, blue: 0.12, alpha: 1).setStroke()
                let stripe = NSBezierPath()
                stripe.move(to: NSPoint(x: x - 3, y: y - 4))
                stripe.line(to: NSPoint(x: x + 3, y: y + 4))
                stripe.lineWidth = 2
                stripe.stroke()
                NSColor(calibratedRed: 0.96, green: 0.64, blue: 0.22, alpha: 1).setFill()
            }
        }

        if isInLaunchBox {
            let box = NSRect(x: 18, y: 24, width: bounds.width - 36, height: 150)
            NSColor.black.withAlphaComponent(0.22).setFill()
            NSBezierPath(roundedRect: NSRect(x: box.minX + 5, y: box.minY - 5, width: box.width, height: box.height), xRadius: 10, yRadius: 10).fill()
            NSColor(calibratedRed: 0.72, green: 0.42, blue: 0.18, alpha: 1).setFill()
            NSBezierPath(roundedRect: box, xRadius: 10, yRadius: 10).fill()
            NSColor(calibratedRed: 0.90, green: 0.62, blue: 0.28, alpha: 1).setFill()
            let flap = NSBezierPath()
            flap.move(to: NSPoint(x: box.minX + 4, y: box.maxY - 20))
            flap.line(to: NSPoint(x: box.midX, y: box.maxY + 22))
            flap.line(to: NSPoint(x: box.maxX - 4, y: box.maxY - 20))
            flap.close()
            flap.fill()
            NSColor(calibratedRed: 0.45, green: 0.24, blue: 0.10, alpha: 0.8).setStroke()
            let tape = NSBezierPath()
            tape.move(to: NSPoint(x: box.midX, y: box.minY))
            tape.line(to: NSPoint(x: box.midX, y: box.maxY + 18))
            tape.lineWidth = 7
            tape.stroke()
            ("CLICK TO OPEN" as NSString).draw(at: NSPoint(x: box.midX - 47, y: box.midY - 8), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.white])
        }

        let hungerRect = NSRect(x: 48, y: 183, width: 128, height: 12)
        NSColor.black.withAlphaComponent(0.42).setFill()
        NSBezierPath(roundedRect: hungerRect, xRadius: 6, yRadius: 6).fill()
        let hungerColor: NSColor = hunger > 55 ? .systemGreen : (hunger > 25 ? .systemYellow : .systemRed)
        hungerColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: hungerRect.minX + 2, y: hungerRect.minY + 2, width: max(0, (hungerRect.width - 4) * hunger / 100), height: hungerRect.height - 4), xRadius: 4, yRadius: 4).fill()
        ((hungerLocked ? "Hunger ∞" : "Hunger") as NSString).draw(at: NSPoint(x: hungerRect.minX, y: hungerRect.maxY + 2), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 10), .foregroundColor: NSColor.white.withAlphaComponent(0.9)])

        if !speechText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.14, blue: 0.25, alpha: 1)]
            let textSize = (speechText as NSString).size(withAttributes: attributes)
            let bubble = NSRect(x: max(4, min(bounds.width - textSize.width - 28, bounds.midX - textSize.width / 2 - 14)), y: hungerRect.maxY + 2, width: textSize.width + 28, height: 27)
            NSColor.white.withAlphaComponent(0.94).setFill()
            NSBezierPath(roundedRect: bubble, xRadius: 12, yRadius: 12).fill()
            (speechText as NSString).draw(at: NSPoint(x: bubble.minX + 14, y: bubble.minY + 7), withAttributes: attributes)
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    func setWalking(_ walking: Bool) {
        guard isWalking != walking else { return }
        isWalking = walking
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard let hostWindow else { return }
        delegate?.noodleStartedDragging()
        let point = hostWindow.convertPoint(fromScreen: NSEvent.mouseLocation)
        dragOffset = point
        mouseDownPoint = event.locationInWindow
        didDrag = false
        lastMousePoint = NSEvent.mouseLocation
        lastDragTime = Date()
        dragVelocity = .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let hostWindow else { return }
        guard !isDead, !isInLaunchBox, delegate?.isLaunchBoxPaused != true else { return }
        let screenPoint = NSEvent.mouseLocation
        let now = Date()
        let elapsed = max(0.001, now.timeIntervalSince(lastDragTime))
        dragVelocity = NSPoint(
            x: (screenPoint.x - lastMousePoint.x) / elapsed,
            y: (screenPoint.y - lastMousePoint.y) / elapsed
        )
        lastMousePoint = screenPoint
        lastDragTime = now
        if hypot(event.locationInWindow.x - mouseDownPoint.x, event.locationInWindow.y - mouseDownPoint.y) > 5 {
            didDrag = true
        }
        hostWindow.setFrameOrigin(NSPoint(x: screenPoint.x - dragOffset.x, y: screenPoint.y - dragOffset.y))
    }

    override func mouseUp(with event: NSEvent) {
        guard let delegate else { return }
        if didDrag {
            delegate.noodleFinishedDragging(velocity: dragVelocity)
            return
        }
        if isInLaunchBox {
            delegate.openLaunchBox()
            return
        }
        let menu = delegate.makePetMenu()
        menu.popUp(positioning: nil, at: event.locationInWindow, in: self)
    }
}

private func makeNoodleStyle(from data: Data) -> NSImage? {
    guard let input = CIImage(data: data) else { return nil }
    let extent = input.extent.integral
    let side = min(extent.width, extent.height)
    let crop = CGRect(x: extent.midX - side / 2, y: extent.midY - side / 2, width: side, height: side)
    var image = input.cropped(to: crop)

    if let color = CIFilter(name: "CIColorControls") {
        color.setValue(image, forKey: kCIInputImageKey)
        color.setValue(1.32, forKey: kCIInputSaturationKey)
        color.setValue(1.10, forKey: kCIInputContrastKey)
        color.setValue(0.025, forKey: kCIInputBrightnessKey)
        image = color.outputImage ?? image
    }
    if let sepia = CIFilter(name: "CISepiaTone") {
        sepia.setValue(image, forKey: kCIInputImageKey)
        sepia.setValue(0.08, forKey: kCIInputIntensityKey)
        image = sepia.outputImage ?? image
    }
    if let sharpen = CIFilter(name: "CISharpenLuminance") {
        sharpen.setValue(image, forKey: kCIInputImageKey)
        sharpen.setValue(0.28, forKey: kCIInputSharpnessKey)
        image = sharpen.outputImage ?? image
    }

    let context = CIContext(options: [.useSoftwareRenderer: false])
    guard let output = context.createCGImage(image, from: image.extent) else { return nil }
    return NSImage(cgImage: output, size: NSSize(width: side, height: side))
}

final class ControlView: NSView {
    weak var delegate: AppDelegate?
    private let statusLabel = NSTextField(labelWithString: "Noodle is feeling curious")
    private let photoPreview = NSImageView()
    private var styleButton: NSButton?
    private var buttons: [NSButton] = []

    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.99, alpha: 1).cgColor
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: delegate, action: action)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.contentTintColor = NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.42, alpha: 1)
        buttons.append(button)
        addSubview(button)
        return button
    }

    private func setup() {
        let title = NSTextField(labelWithString: "Noodle")
        title.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        title.textColor = NSColor(calibratedRed: 0.25, green: 0.16, blue: 0.30, alpha: 1)
        addSubview(title)

        let subtitle = NSTextField(labelWithString: "Your tiny desktop companion")
        subtitle.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = NSColor.secondaryLabelColor
        addSubview(subtitle)

        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = NSColor(calibratedRed: 0.42, green: 0.27, blue: 0.50, alpha: 1)
        addSubview(statusLabel)

        let photoTitle = NSTextField(labelWithString: "Avatar")
        photoTitle.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        photoTitle.textColor = NSColor.secondaryLabelColor
        addSubview(photoTitle)

        photoPreview.imageScaling = .scaleProportionallyUpOrDown
        photoPreview.wantsLayer = true
        photoPreview.layer?.cornerRadius = 32
        photoPreview.layer?.masksToBounds = true
        addSubview(photoPreview)

        _ = makeButton("Move around", #selector(AppDelegate.toggleMovement(_:)))
        _ = makeButton("Follow mouse", #selector(AppDelegate.toggleFollowMouse(_:)))
        _ = makeButton("Wave", #selector(AppDelegate.wave(_:)))
        _ = makeButton("Zoomies", #selector(AppDelegate.zoomies(_:)))
        _ = makeButton("Nap", #selector(AppDelegate.nap(_:)))
        _ = makeButton("Fetch ball", #selector(AppDelegate.fetchBall(_:)))
        _ = makeButton("Toss yarn", #selector(AppDelegate.tossYarn(_:)))
        _ = makeButton("Spawn robot", #selector(AppDelegate.spawnRobot(_:)))
        _ = makeButton("Spawn boom box", #selector(AppDelegate.spawnBoombox(_:)))
        _ = makeButton("Import pet photo", #selector(AppDelegate.importPhoto(_:)))
        styleButton = makeButton("Style as Noodle", #selector(AppDelegate.stylePhoto(_:)))
        styleButton?.isEnabled = false
        _ = makeButton("Teach a trick", #selector(AppDelegate.teachTrick(_:)))
        _ = makeButton("Nudge front window", #selector(AppDelegate.nudgeWindow(_:)))
        _ = makeButton("Tidy windows", #selector(AppDelegate.organizeWindows(_:)))
    }

    func setStatus(_ message: String) { statusLabel.stringValue = message }
    func setMovementButtonTitle(_ title: String) { buttons.first?.title = title }
    func setPhoto(_ image: NSImage?) {
        photoPreview.image = image
        styleButton?.isEnabled = image != nil
    }

    override func layout() {
        super.layout()
        let pad: CGFloat = 22
        let width = bounds.width - pad * 2
        let title = subviews[0]; title.frame = NSRect(x: pad, y: bounds.height - 55, width: width, height: 34)
        let subtitle = subviews[1]; subtitle.frame = NSRect(x: pad, y: bounds.height - 78, width: width, height: 20)
        statusLabel.frame = NSRect(x: pad, y: bounds.height - 112, width: width - 70, height: 22)
        let photoTitle = subviews[3]; photoTitle.frame = NSRect(x: pad, y: bounds.height - 152, width: width, height: 18)
        photoPreview.frame = NSRect(x: bounds.width - pad - 64, y: bounds.height - 166, width: 64, height: 64)

        let startY = bounds.height - 214
        let buttonHeight: CGFloat = 32
        let gap: CGFloat = 10
        for (index, button) in buttons.enumerated() {
            if index < 4 {
                let col = index % 2
                let row = index / 2
                button.frame = NSRect(x: pad + CGFloat(col) * (width / 2 + 5), y: startY - CGFloat(row) * (buttonHeight + gap), width: width / 2 - 5, height: buttonHeight)
            } else {
                let row = index - 4
                button.frame = NSRect(x: pad, y: startY - 2 * (buttonHeight + gap) - CGFloat(row) * (buttonHeight + gap), width: width, height: buttonHeight)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var petWindow: PetWindow!
    private var catView: CatView!
    private var controls: ControlView!
    private var cloneMachineWindow: NSWindow?
    private var cloneMachineView: CloneMachineView?
    private var statChangerWindow: NSWindow?
    private var statChangerView: StatChangerView?
    private var tutorialWindow: NSWindow?
    private var toyPanelWindow: NSWindow?
    private var tutorialNarrationTimer: Timer?
    private var tutorialNarrationIndex = 0
    private var machineTreatReady = false
    private var statMachineHasNoodle = false
    private var clonePets: [ClonePet] = []
    private var cloneCount = 1
    private var cloneInProgress = false
    private var nextClonePlayAt = Date.distantPast
    private var clonePlayUntil = Date.distantPast
    private var tagRunning = false
    private var tagEndsAt = Date.distantPast
    private var nextTagCatchAt = Date.distantPast
    private var wallOverlayWindow: NSWindow?
    private var wallOverlayView: WallOverlayView?
    private var mazeBuilderWindow: NSWindow?
    private var mazeBuilderView: MazeBuilderView?
    private var mazeBuilderAccepted = false
    private var wallSegments: [WallSegment] = []
    private var mazeTreatPoint: NSPoint?
    private var pathPoints: [NSPoint] = []
    private var pathIndex = 0
    private var mazeRunning = false
    private var timer: Timer?
    private var target = CGPoint.zero
    private var moving = true
    private var noodleVelocity = NSPoint.zero
    private var noodleIsBouncing = false
    private var noodleBounciness: CGFloat = 0.78
    private var noodleGravity: CGFloat = 980
    private var noodleSizeScale: CGFloat = 1
    private var noodleHunger: CGFloat = 100
    private var lastHungerUpdate = Date()
    private var feedTreatsUntil = Date.distantPast
    private var noodleIsDead = false
    private var goldenBoneFed = false
    private var nextGoldenBoneChanceAt = Date.distantPast
    private var activeTrick = ""
    private var trickEndsAt = Date.distantPast
    private var importedImage: NSImage?
    private var restingUntil = Date.distantPast
    private var nextWindowRestAt = Date.distantPast
    private var followingMouse = false
    private var toyWindow: NSWindow?
    private var popcornBucketWindow: NSWindow?
    private var toyKind: ToyKind = .ball
    private var fetchingToy = false
    private var toyTarget = NSPoint.zero
    private var toyVelocity = NSPoint.zero
    private var toyIsThrown = false
    private var toyReturning = false
    private var toyHomeOrigin = NSPoint.zero
    private var trapArmed = false
    private var trapTriggered = false
    private var trapReleaseAt = Date.distantPast
    private var robotKeys = Set<Character>()
    private var robotTarget = NSPoint.zero
    private var robotNextTurnAt = Date.distantPast
    private var boomboxPlaying = false
    private var treatSpeechUntil = Date.distantPast
    private var popcornTrip = false
    private var popcornOffscreen = false
    private var popcornWalkingOut = false
    private var popcornLeavingAt = Date.distantPast
    private var popcornReturnAt = Date.distantPast
    private var popcornReturnOrigin = NSPoint.zero
    private var popcornExitTarget = NSPoint.zero
    private var popcornFlavorPromptPending = false
    private var popcornFlavor: String?
    private var popcornCookUntil = Date.distantPast
    private var requestedAccessibilityPrompt = false
    private let automaticFollowInterval: TimeInterval = 25 * 60
    private var nextAutomaticFollowAt = Date().addingTimeInterval(25 * 60)
    private var automaticFollowUntil = Date.distantPast
    private var greetingUntil = Date.distantPast
    private var backspaceMonitor: Any?
    private var robotKeyboardMonitor: Any?
    private var backspacePresses: [Date] = []
    private var noodleManuallyOffscreen = false
    private var savedNoodleOrigin = NSPoint.zero
    private let openingGreetingLines = [
        "Hi, I'm Noodle, your new pet!",
        "Click and drag me!",
        "Click me to open my menu!",
        "Using that, you can care and play with me :3"
    ]
    private var openingGreetingIndex = 0
    private var openingGreetingActive = false
    private var resetBoxDropAt = Date.distantPast
    private var resetBoxDropping = false
    private var resetBoxTarget = NSPoint.zero
    private var discoOverlayWindow: NSWindow?
    private var discoOverlayView: DiscoOverlayView?
    private var discoPlayer: AVAudioPlayer?
    private var discoEndsAt = Date.distantPast
    private var discoPhase: CGFloat = 0
    private var discoBaseOrigin = NSPoint.zero
    private var spinMode = false

    var isMoving: Bool { moving }
    var isCaged: Bool { catView?.isCaged ?? false }
    var isFollowingMouse: Bool { followingMouse }
    var isLaunchBoxPaused: Bool {
        (catView?.isInLaunchBox ?? false) || resetBoxDropping || resetBoxDropAt != Date.distantPast
    }

    func makePetMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let heading = NSMenuItem(title: "Noodle", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())

        func add(_ title: String, _ action: Selector, to submenu: NSMenu) {
            let item = submenu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
        }

        let careMenu = NSMenu()
        add("Pet Noodle", #selector(petNoodle(_:)), to: careMenu)
        add("Feed Noodle", #selector(feedNoodle(_:)), to: careMenu)
        add(isCaged ? "Let Noodle out" : "Send Noodle to cage", #selector(toggleCage(_:)), to: careMenu)
        add("Reset Noodle", #selector(resetNoodle(_:)), to: careMenu)
        let careItem = NSMenuItem(title: "Care", action: nil, keyEquivalent: "")
        careItem.submenu = careMenu
        menu.addItem(careItem)

        let avatarMenu = NSMenu()
        add("Import pet photo", #selector(importPhoto(_:)), to: avatarMenu)
        add("Style as Noodle", #selector(stylePhoto(_:)), to: avatarMenu)
        let avatarItem = NSMenuItem(title: "Avatar", action: nil, keyEquivalent: "")
        avatarItem.submenu = avatarMenu
        menu.addItem(avatarItem)

        let tricksMenu = NSMenu()
        add("Wave", #selector(wave(_:)), to: tricksMenu)
        add("Zoomies", #selector(zoomies(_:)), to: tricksMenu)
        add("Nap", #selector(nap(_:)), to: tricksMenu)
        add("Jump", #selector(jump(_:)), to: tricksMenu)
        add("Roll over", #selector(rollOver(_:)), to: tricksMenu)
        add("Beg", #selector(beg(_:)), to: tricksMenu)
        add("Play dead", #selector(playDead(_:)), to: tricksMenu)
        add("Stretch", #selector(stretch(_:)), to: tricksMenu)
        add("Dance", #selector(dance(_:)), to: tricksMenu)
        add(spinMode ? "Stop spinning" : "Spin until stopped", #selector(toggleSpinMode(_:)), to: tricksMenu)
        add("Teach a trick", #selector(teachTrick(_:)), to: tricksMenu)
        let tricksItem = NSMenuItem(title: "Tricks", action: nil, keyEquivalent: "")
        tricksItem.submenu = tricksMenu
        menu.addItem(tricksItem)

        let playMenu = NSMenu()
        if tagRunning {
            add("Stop Tag", #selector(stopTag(_:)), to: playMenu)
        } else {
            add("Tag", #selector(startTag(_:)), to: playMenu)
        }
        add("Make popcorn", #selector(makePopcorn(_:)), to: playMenu)
        add("Clone machine", #selector(spawnCloneMachine(_:)), to: playMenu)
        add("Stat changer machine", #selector(spawnStatChanger(_:)), to: playMenu)
        let playItem = NSMenuItem(title: "Play", action: nil, keyEquivalent: "")
        playItem.submenu = playMenu
        menu.addItem(playItem)

        let toysMenu = NSMenu()
        add("Spawn treat", #selector(spawnTreat(_:)), to: toysMenu)
        add("Set trap", #selector(spawnTrap(_:)), to: toysMenu)
        add("Fetch ball", #selector(fetchBall(_:)), to: toysMenu)
        add("Toss yarn", #selector(tossYarn(_:)), to: toysMenu)
        add("Spawn robot", #selector(spawnRobot(_:)), to: toysMenu)
        add("Spawn boom box", #selector(spawnBoombox(_:)), to: toysMenu)
        add("Make popcorn", #selector(makePopcorn(_:)), to: toysMenu)
        add("Clone machine", #selector(spawnCloneMachine(_:)), to: toysMenu)
        add("Stat changer machine", #selector(spawnStatChanger(_:)), to: toysMenu)
        let toysItem = NSMenuItem(title: "Toys", action: nil, keyEquivalent: "")
        toysItem.submenu = toysMenu
        menu.addItem(toysItem)

        let movementMenu = NSMenu()
        let followItem = movementMenu.addItem(withTitle: followingMouse ? "Stop following mouse" : "Follow my mouse", action: #selector(toggleFollowMouse(_:)), keyEquivalent: "")
        followItem.target = self
        followItem.state = followingMouse ? .on : .off
        add("Rest on a random window", #selector(restOnRandomWindow(_:)), to: movementMenu)
        add("Nudge front window", #selector(nudgeWindow(_:)), to: movementMenu)
        add("Tidy open windows", #selector(organizeWindows(_:)), to: movementMenu)
        add(moving ? "Pause wandering" : "Resume wandering", #selector(toggleMovementFromMenu(_:)), to: movementMenu)
        let movementItem = NSMenuItem(title: "Movement", action: nil, keyEquivalent: "")
        movementItem.submenu = movementMenu
        menu.addItem(movementItem)

        menu.addItem(.separator())
        add("Quit Noodle", #selector(quitNoodle(_:)), to: menu)

        return menu
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let oldReminderIDs = ["noodle.exercise.reminder", "noodle.water.reminder"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: oldReminderIDs)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: oldReminderIDs)
        // Keep status updates available internally without showing a separate window.
        controls = ControlView(delegate: self)
        makePetWindow()
        chooseNewTarget()
        nextWindowRestAt = Date().addingTimeInterval(20)
        let launchBoxHasBeenOpened = UserDefaults.standard.bool(forKey: "NoodleLaunchBoxOpened")
        if launchBoxHasBeenOpened {
            startOpeningGreeting()
        } else {
            catView.isInLaunchBox = false
            catView.speechText = ""
            greetingUntil = Date.distantPast
            openingGreetingActive = false
            moving = false
            noodleManuallyOffscreen = true
            resetBoxDropAt = Date().addingTimeInterval(5)
            petWindow.orderOut(nil)
            controls.setStatus("Noodle will arrive in his box in 5 seconds")
        }
        backspaceMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 51, !event.isARepeat else { return }
            DispatchQueue.main.async {
                self?.registerBackspacePress()
            }
        }
        robotKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleRobotKey(event)
            }
        }
        startAnimation()
        moving = false
        controls.setMovementButtonTitle("Move around")
        controls.setStatus("Noodle is staying put")
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func startOpeningGreeting() {
        guard !isLaunchBoxPaused else {
            openingGreetingActive = false
            catView.speechText = ""
            return
        }
        openingGreetingIndex = 0
        openingGreetingActive = true
        catView.speechText = openingGreetingLines[openingGreetingIndex]
        greetingUntil = Date().addingTimeInterval(3)
    }

    func openLaunchBox() {
        guard catView.isInLaunchBox else { return }
        catView.isInLaunchBox = false
        UserDefaults.standard.set(true, forKey: "NoodleLaunchBoxOpened")
        noodleManuallyOffscreen = false
        resetBoxDropping = false
        resetBoxDropAt = Date.distantPast
        petWindow.orderFrontRegardless()
        startOpeningGreeting()
        controls.setStatus("Noodle is out of the box")
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let backspaceMonitor {
            NSEvent.removeMonitor(backspaceMonitor)
            self.backspaceMonitor = nil
        }
        if let robotKeyboardMonitor {
            NSEvent.removeMonitor(robotKeyboardMonitor)
            self.robotKeyboardMonitor = nil
        }
    }

    private func activeVisibleFrame() -> NSRect {
        NSScreen.screens.first(where: { $0.visibleFrame.contains(NSEvent.mouseLocation) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    func handleRobotKey(_ event: NSEvent) {
        guard toyKind == .robot, toyWindow != nil,
              let key = event.charactersIgnoringModifiers?.lowercased().first,
              "wasd".contains(key) else { return }
        if event.type == .keyDown {
            robotKeys.insert(key)
        } else if event.type == .keyUp {
            robotKeys.remove(key)
        }
    }

    private func updateRobotToy(_ window: NSWindow) {
        let screen = window.screen?.visibleFrame ?? activeVisibleFrame()
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        if robotKeys.contains("a") { dx -= 1 }
        if robotKeys.contains("d") { dx += 1 }
        if robotKeys.contains("s") { dy -= 1 }
        if robotKeys.contains("w") { dy += 1 }

        let manuallyControlled = dx != 0 || dy != 0
        if manuallyControlled {
            robotNextTurnAt = Date().addingTimeInterval(1.0)
        } else {
            let distanceToTarget = hypot(robotTarget.x - window.frame.minX, robotTarget.y - window.frame.minY)
            if Date() >= robotNextTurnAt || distanceToTarget < 12 {
                robotTarget = NSPoint(
                    x: CGFloat.random(in: screen.minX ... max(screen.minX, screen.maxX - window.frame.width)),
                    y: CGFloat.random(in: screen.minY ... max(screen.minY, screen.maxY - window.frame.height))
                )
                robotNextTurnAt = Date().addingTimeInterval(Double.random(in: 1.5 ... 4.0))
            }
            dx = robotTarget.x - window.frame.minX
            dy = robotTarget.y - window.frame.minY
        }

        guard dx != 0 || dy != 0 else {
            catView.setWalking(false)
            return
        }
        let length = sqrt(dx * dx + dy * dy)
        let speed: CGFloat = manuallyControlled ? 6.0 : 2.4
        let nextOrigin = NSPoint(
            x: min(max(window.frame.minX + dx / length * speed, screen.minX), screen.maxX - window.frame.width),
            y: min(max(window.frame.minY + dy / length * speed, screen.minY), screen.maxY - window.frame.height)
        )
        window.setFrameOrigin(nextOrigin)
        catView.setWalking(false)
        catView.speechText = "Beep boop!"
        treatSpeechUntil = Date().addingTimeInterval(0.35)
    }

    private func randomDesktopWindow() -> CGRect? {
        guard let rawWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let ignoredOwners = Set(["Noodle", "Dock", "Window Server", "Control Center", "SystemUIServer", "Notification Center"])
        let candidates = rawWindows.compactMap { window -> CGRect? in
            guard let owner = window[kCGWindowOwnerName as String] as? String,
                  !ignoredOwners.contains(owner),
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width >= 260,
                  rect.height >= 160 else { return nil }
            return rect
        }
        return candidates.randomElement()
    }

    private func requestAccessibilityAccess() {
        guard !AXIsProcessTrusted() else { return }
        requestedAccessibilityPrompt = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func registerBackspacePress() {
        let now = Date()
        backspacePresses = backspacePresses.filter { now.timeIntervalSince($0) < 0.9 }
        backspacePresses.append(now)
        guard backspacePresses.count >= 3 else { return }
        backspacePresses.removeAll()
        toggleNoodleVisibility()
    }

    private func toggleNoodleVisibility() {
        cancelOtherPlayModes(except: "visibility")
        if noodleManuallyOffscreen {
            noodleManuallyOffscreen = false
            let screen = petWindow.screen?.visibleFrame ?? activeVisibleFrame()
            let x = min(max(savedNoodleOrigin.x, screen.minX + 8), screen.maxX - petSize - 8)
            let y = min(max(savedNoodleOrigin.y, screen.minY + 8), screen.maxY - petSize - 8)
            petWindow.setFrameOrigin(NSPoint(x: x, y: y))
            petWindow.orderFrontRegardless()
            chooseNewTarget()
            controls.setStatus("Noodle is back on-screen")
        } else {
            savedNoodleOrigin = petWindow.frame.origin
            noodleManuallyOffscreen = true
            let screen = petWindow.screen?.visibleFrame ?? activeVisibleFrame()
            let y = min(max(petWindow.frame.minY, screen.minY + 8), screen.maxY - petSize - 8)
            petWindow.setFrameOrigin(NSPoint(x: screen.maxX + petSize + 40, y: y))
            petWindow.orderFrontRegardless()
            controls.setStatus("Noodle is off-screen")
        }
    }

    @objc func openWallEditor(_ sender: Any?) {
        if let mazeBuilderWindow, let mazeBuilderView {
            mazeBuilderView.beginEditing()
            mazeBuilderWindow.ignoresMouseEvents = false
            mazeBuilderWindow.orderFrontRegardless()
            return
        }

        let screen = activeVisibleFrame()
        let size = NSSize(width: 720, height: 720)
        let origin = NSPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
        let window = NSWindow(contentRect: NSRect(origin: origin, size: size), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Noodle Maze"
        window.isOpaque = true
        window.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.07, blue: 0.13, alpha: 1)
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.delegate = self
        let view = MazeBuilderView(delegate: self)
        window.contentView = view
        mazeBuilderWindow = window
        mazeBuilderView = view
        window.orderFrontRegardless()
        moving = false
        catView.setWalking(false)
        controls.setStatus("Build a maze, then press OK")
    }

    @objc func mazeGridSliderChanged(_ sender: NSSlider) {
        mazeBuilderView?.setGridSize(sender.integerValue)
    }

    @objc func mazeWallMode(_ sender: Any?) {
        mazeBuilderView?.setMode(.wall)
    }

    @objc func mazeStartMode(_ sender: Any?) {
        mazeBuilderView?.setMode(.start)
    }

    @objc func mazeTreatMode(_ sender: Any?) {
        mazeBuilderView?.setMode(.treat)
    }

    @objc func mazeClear(_ sender: Any?) {
        mazeBuilderView?.clearWalls()
    }

    @objc func mazeRandom(_ sender: Any?) {
        mazeBuilderView?.makeRandomMaze()
    }

    @objc func mazeOK(_ sender: Any?) {
        guard let view = mazeBuilderView, let window = mazeBuilderWindow else { return }
        let start = view.gridPointOnScreen(for: view.startIndex)
        let treat = view.gridPointOnScreen(for: view.treatIndex)
        guard hypot(start.x - treat.x, start.y - treat.y) > 20 else {
            controls.setStatus("Choose different start and treat dots")
            return
        }

        wallSegments = view.walls.map {
            WallSegment(start: view.gridPointOnScreen(for: $0.first), end: view.gridPointOnScreen(for: $0.second))
        }
        mazeTreatPoint = treat
        pathPoints.removeAll()
        pathIndex = 0
        target = NSPoint(x: treat.x - petSize / 2, y: treat.y - petSize / 2)
        mazeRunning = true
        catView.displayScale = 0.68
        petWindow.setFrameOrigin(NSPoint(x: start.x - petSize / 2, y: start.y - petSize / 2))
        petWindow.orderFrontRegardless()
        moving = false
        pathPoints = wallPath(to: treat)
        pathIndex = 0
        mazeBuilderAccepted = true
        view.setRunning()
        window.title = "Noodle Maze — Running"
        window.ignoresMouseEvents = false
        window.orderFrontRegardless()
        petWindow.orderFrontRegardless()
        controls.setStatus("Noodle is solving the maze")
    }

    func wallEditorAddWall(from start: NSPoint, to end: NSPoint) {
        wallSegments.append(WallSegment(start: start, end: end))
        wallOverlayView?.walls = wallSegments
        rebuildPathToCurrentTarget()
    }

    func wallEditorPlaceTreat(at point: NSPoint) {
        mazeTreatPoint = point
        wallOverlayView?.treatPoint = point
        rebuildPathToCurrentTarget()
        controls.setStatus("Noodle is finding a path to the treat")
    }

    @objc func wallEditorToggleTreat(_ sender: Any?) {
        wallOverlayView?.toggleTreatMode()
    }

    @objc func wallEditorMakeMaze(_ sender: Any?) {
        let screen = activeVisibleFrame()
        let spacing: CGFloat = min(240, max(170, screen.width / 7))
        var maze: [WallSegment] = []
        for index in 0..<5 {
            let x = screen.minX + 180 + CGFloat(index) * spacing
            if index.isMultiple(of: 2) {
                maze.append(WallSegment(start: NSPoint(x: x, y: screen.minY + 110), end: NSPoint(x: x, y: screen.maxY - 180)))
            } else {
                maze.append(WallSegment(start: NSPoint(x: x, y: screen.minY + 180), end: NSPoint(x: x, y: screen.maxY - 110)))
            }
        }
        wallSegments = maze
        wallOverlayView?.walls = maze
        rebuildPathToCurrentTarget()
        controls.setStatus("Maze walls added")
    }

    @objc func wallEditorClear(_ sender: Any?) {
        wallSegments.removeAll()
        mazeTreatPoint = nil
        pathPoints.removeAll()
        pathIndex = 0
        wallOverlayView?.walls = []
        wallOverlayView?.treatPoint = nil
        controls.setStatus("Walls and treat cleared")
    }

    @objc func wallEditorDone(_ sender: Any?) {
        wallOverlayView?.finishEditing()
        wallOverlayWindow?.ignoresMouseEvents = true
        wallOverlayWindow?.orderFrontRegardless()
        petWindow.orderFrontRegardless()
        for clone in clonePets {
            clone.window.orderFrontRegardless()
        }
        controls.setStatus("Noodle is navigating around the walls")
    }

    private func distance(from point: NSPoint, to segment: WallSegment) -> CGFloat {
        let dx = segment.end.x - segment.start.x
        let dy = segment.end.y - segment.start.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 {
            return hypot(point.x - segment.start.x, point.y - segment.start.y)
        }
        let projection = max(0, min(1, ((point.x - segment.start.x) * dx + (point.y - segment.start.y) * dy) / lengthSquared))
        let closest = NSPoint(x: segment.start.x + projection * dx, y: segment.start.y + projection * dy)
        return hypot(point.x - closest.x, point.y - closest.y)
    }

    private func isWallBlocked(_ point: NSPoint) -> Bool {
        wallSegments.contains { distance(from: point, to: $0) < 38 }
    }

    private func wallPath(to destination: NSPoint) -> [NSPoint] {
        guard !wallSegments.isEmpty else { return [] }
        let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(destination) })?.visibleFrame ?? activeVisibleFrame()
        let cell: CGFloat = 34
        let columns = max(1, Int(screen.width / cell))
        let rows = max(1, Int(screen.height / cell))
        let total = columns * rows
        func index(_ column: Int, _ row: Int) -> Int { row * columns + column }
        func point(_ column: Int, _ row: Int) -> NSPoint {
            NSPoint(x: screen.minX + (CGFloat(column) + 0.5) * cell, y: screen.minY + (CGFloat(row) + 0.5) * cell)
        }
        func cellFor(_ value: NSPoint) -> (Int, Int) {
            let column = min(columns - 1, max(0, Int((value.x - screen.minX) / cell)))
            let row = min(rows - 1, max(0, Int((value.y - screen.minY) / cell)))
            return (column, row)
        }

        let startCenter = NSPoint(x: petWindow.frame.midX, y: petWindow.frame.midY)
        let (startColumn, startRow) = cellFor(startCenter)
        let (goalColumn, goalRow) = cellFor(destination)
        let start = index(startColumn, startRow)
        let goal = index(goalColumn, goalRow)
        var parents = Array(repeating: -2, count: total)
        var queue: [Int] = [start]
        var head = 0
        parents[start] = -1
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        while head < queue.count {
            let current = queue[head]
            head += 1
            if current == goal { break }
            let column = current % columns
            let row = current / columns
            for (dx, dy) in directions {
                let nextColumn = column + dx
                let nextRow = row + dy
                guard nextColumn >= 0, nextColumn < columns, nextRow >= 0, nextRow < rows else { continue }
                let next = index(nextColumn, nextRow)
                guard parents[next] == -2 else { continue }
                let isGoal = next == goal
                guard isGoal || !isWallBlocked(point(nextColumn, nextRow)) else { continue }
                parents[next] = current
                queue.append(next)
            }
        }

        guard parents[goal] != -2 else { return [] }
        var cells: [Int] = []
        var current = goal
        while current != -1 {
            cells.append(current)
            current = parents[current]
        }
        cells.reverse()
        return cells.dropFirst().map { cellIndex in
            let column = cellIndex % columns
            let row = cellIndex / columns
            let center = point(column, row)
            return NSPoint(x: center.x - petSize / 2, y: center.y - petSize / 2)
        }
    }

    private func rebuildPathToCurrentTarget() {
        if let treat = mazeTreatPoint {
            pathPoints = wallPath(to: treat)
        } else if !wallSegments.isEmpty {
            pathPoints = wallPath(to: target)
        } else {
            pathPoints.removeAll()
        }
        pathIndex = 0
    }

    @objc func makePopcorn(_ sender: Any?) {
        guard !catView.isCaged, !popcornTrip, !popcornFlavorPromptPending, popcornFlavor == nil, popcornBucketWindow == nil else {
            controls.setStatus("Noodle is already making popcorn")
            return
        }
        cancelOtherPlayModes(except: "popcorn")
        guard toyWindow == nil else {
            controls.setStatus("Noodle is already playing with a toy")
            return
        }

        popcornTrip = true
        popcornOffscreen = false
        popcornWalkingOut = true
        popcornLeavingAt = Date().addingTimeInterval(3)
        popcornReturnAt = popcornLeavingAt.addingTimeInterval(5)
        popcornReturnOrigin = petWindow.frame.origin
        let screen = petWindow.screen?.visibleFrame ?? activeVisibleFrame()
        popcornExitTarget = NSPoint(
            x: screen.maxX + 40,
            y: min(max(petWindow.frame.minY, screen.minY + 8), screen.maxY - petSize - 8)
        )
        catView.showPopcornMachine = false
        catView.speechText = ""
        catView.setWalking(true)
        controls.setStatus("Noodle is getting the popcorn machine")
    }

    private func showPopcornFlavorMenu() {
        guard popcornFlavorPromptPending else { return }
        popcornFlavorPromptPending = false

        let menu = NSMenu(title: "Popcorn flavor")
        let heading = NSMenuItem(title: "Pick a flavor", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())
        for (title, flavor) in [("Butter", "butter"), ("Cheese", "cheese"), ("Caramel", "caramel"), ("Kettle corn", "kettle corn")] {
            let item = menu.addItem(withTitle: title, action: #selector(selectPopcornFlavor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = flavor
        }
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSPoint(x: petWindow.frame.midX, y: petWindow.frame.midY), in: nil)
    }

    @objc func selectPopcornFlavor(_ sender: NSMenuItem) {
        guard let flavor = sender.representedObject as? String else { return }
        popcornFlavor = flavor
        popcornCookUntil = Date().addingTimeInterval(3)
        catView.speechText = ""
        controls.setStatus("Noodle is cooking \(flavor) popcorn")
    }

    private func dropPopcornBucket() {
        popcornBucketWindow?.orderOut(nil)

        let screen = petWindow.screen?.visibleFrame ?? activeVisibleFrame()
        let size: CGFloat = 86
        let x = min(max(petWindow.frame.midX - size / 2, screen.minX + 8), screen.maxX - size - 8)
        let y = max(screen.minY + 8, petWindow.frame.minY - size + 22)
        let window = ToyWindow(contentRect: NSRect(x: x, y: y, width: size, height: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = PopcornBucketView(delegate: self)
        window.orderFrontRegardless()
        popcornBucketWindow = window
        controls.setStatus("Click the popcorn bucket to eat it")
    }

    func popcornBucketClicked() {
        guard let window = popcornBucketWindow else { return }
        window.orderOut(nil)
        popcornBucketWindow = nil
        catView.speechText = "Nom nom!"
        treatSpeechUntil = Date().addingTimeInterval(2)
        runTrick("Wave")
        controls.setStatus("Noodle ate the popcorn")
    }

    private func cancelOtherPlayModes(except mode: String) {
        if mode != "disco", discoOverlayWindow != nil {
            stopDiscoMode()
        }
        if mode != "tag", tagRunning {
            endTagGame(message: "Tag cancelled")
        }
        if mode != "popcorn" {
            cancelPopcorn()
        }
        if mode != "clone", cloneMachineWindow != nil {
            hideCloneMachine()
        }
        if mode != "stats", statChangerWindow != nil {
            hideStatChanger()
        }
        if mode != "toy" {
            cancelToyPlay()
        }
    }

    private func cancelPopcorn() {
        guard popcornTrip || popcornFlavorPromptPending || popcornFlavor != nil || popcornBucketWindow != nil || catView.showPopcornMachine else { return }
        popcornTrip = false
        popcornOffscreen = false
        popcornWalkingOut = false
        popcornFlavorPromptPending = false
        popcornFlavor = nil
        popcornCookUntil = Date.distantPast
        popcornBucketWindow?.orderOut(nil)
        popcornBucketWindow = nil
        catView.showPopcornMachine = false
        catView.speechText = ""
        petWindow.orderFrontRegardless()
    }

    private func cancelToyPlay() {
        toyWindow?.orderOut(nil)
        toyWindow = nil
        fetchingToy = false
        toyTarget = .zero
        toyVelocity = .zero
        toyIsThrown = false
        toyReturning = false
        toyHomeOrigin = .zero
        trapArmed = false
        trapTriggered = false
        trapReleaseAt = Date.distantPast
        robotKeys.removeAll()
        robotTarget = .zero
        robotNextTurnAt = Date.distantPast
        boomboxPlaying = false
    }

    @objc func discoMode(_ sender: Any?) {
        if discoOverlayWindow != nil {
            stopDiscoMode()
            return
        }
        cancelOtherPlayModes(except: "disco")

        let screen = activeVisibleFrame()
        let overlay = NSWindow(contentRect: screen, styleMask: [.borderless], backing: .buffered, defer: false)
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.level = .floating
        overlay.ignoresMouseEvents = true
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let view = DiscoOverlayView(frame: NSRect(origin: .zero, size: screen.size))
        view.dimProgress = 0
        overlay.contentView = view
        discoOverlayWindow = overlay
        discoOverlayView = view
        discoEndsAt = Date().addingTimeInterval(25)
        discoPhase = 0
        discoBaseOrigin = petWindow.frame.origin
        overlay.orderFrontRegardless()

        moving = false
        followingMouse = false
        catView.setWalking(false)
        catView.trick = spinMode ? "Spin" : "Dance"
        catView.speechText = "DANCE BREAK! TURN VOLUME UP UP UP!"
        treatSpeechUntil = Date().addingTimeInterval(4)
        petWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        if let data = loadDanceBreakTrack() {
            discoPlayer = try? AVAudioPlayer(data: data)
            discoPlayer?.numberOfLoops = -1
            discoPlayer?.volume = 1.0
            discoPlayer?.prepareToPlay()
            discoPlayer?.play()
        }
        controls.setStatus("Disco mode is on")
    }

    @objc func killSwitch(_ sender: Any?) {
        stopDiscoMode()
    }

    private func stopDiscoMode() {
        discoPlayer?.stop()
        discoPlayer = nil
        discoOverlayWindow?.orderOut(nil)
        discoOverlayWindow = nil
        discoOverlayView = nil
        discoPhase = 0
        petWindow.setFrameOrigin(discoBaseOrigin)
        moving = true
        catView.trick = spinMode ? "Spin" : ""
        if catView.speechText == "DANCE BREAK! TURN VOLUME UP UP UP!" {
            catView.speechText = ""
        }
        chooseNewTarget()
        controls.setStatus("Disco mode ended")
    }

    @objc func startTag(_ sender: Any?) {
        guard !tagRunning, !catView.isCaged else { return }
        cancelOtherPlayModes(except: "tag")
        tagRunning = true
        tagEndsAt = Date().addingTimeInterval(30)
        nextTagCatchAt = Date.distantPast
        moving = false
        followingMouse = false
        restingUntil = Date.distantPast
        nextWindowRestAt = Date.distantFuture
        catView.speechText = "Catch me!"
        treatSpeechUntil = Date().addingTimeInterval(2)
        controls.setStatus("Tag started — move your mouse!")
    }

    @objc func stopTag(_ sender: Any?) {
        endTagGame(message: "Tag ended")
    }

    private func endTagGame(message: String) {
        tagRunning = false
        tagEndsAt = Date.distantPast
        nextTagCatchAt = Date.distantPast
        moving = true
        nextWindowRestAt = Date().addingTimeInterval(Double.random(in: 20 ... 40))
        if catView.speechText == "Tag!" || catView.speechText == "Catch me!" || catView.speechText == "Tagged!" {
            catView.speechText = ""
        }
        chooseNewTarget()
        controls.setStatus(message)
    }

    private func moveNoodleToward(_ destination: NSPoint) -> CGFloat {
        let current = petWindow.frame.origin
        let dx = destination.x - current.x
        let dy = destination.y - current.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 0 else { return 0 }
        let step = min(distance, max(3.0, distance * 0.035))
        petWindow.setFrameOrigin(NSPoint(x: current.x + dx / distance * step, y: current.y + dy / distance * step))
        return distance
    }

    private func updateNoodleBounce() {
        let screen = activeVisibleFrame()
        let gravity = noodleGravity
        let dt: CGFloat = 1.0 / 60.0
        var nextOrigin = petWindow.frame.origin
        noodleVelocity.y -= gravity * dt
        nextOrigin.x += noodleVelocity.x * dt
        nextOrigin.y += noodleVelocity.y * dt
        var bounced = false

        if nextOrigin.x <= screen.minX || nextOrigin.x + petWindow.frame.width >= screen.maxX {
            noodleVelocity.x *= -noodleBounciness
            nextOrigin.x = min(max(nextOrigin.x, screen.minX), screen.maxX - petWindow.frame.width)
            bounced = true
        }
        if nextOrigin.y <= screen.minY {
            nextOrigin.y = screen.minY
            if abs(noodleVelocity.y) < 120 {
                noodleVelocity.y = 0
            } else {
                noodleVelocity.y *= -noodleBounciness
                bounced = true
            }
        } else if nextOrigin.y + petWindow.frame.height >= screen.maxY {
            nextOrigin.y = screen.maxY - petWindow.frame.height
            noodleVelocity.y *= -noodleBounciness
            bounced = true
        }

        petWindow.setFrameOrigin(nextOrigin)
        noodleVelocity.x *= 0.992
        catView.setWalking(false)
        if bounced {
            spendNoodleEnergy(1.5)
            controls.setStatus("Noodle bounced!")
        }

        let onFloor = nextOrigin.y <= screen.minY + 0.5
        if onFloor && abs(noodleVelocity.y) < 90 && abs(noodleVelocity.x) < 35 {
            noodleVelocity = .zero
            noodleIsBouncing = false
            catView.trick = ""
            moving = true
            nextWindowRestAt = Date().addingTimeInterval(Double.random(in: 20 ... 40))
            chooseNewTarget()
            controls.setStatus("Noodle is back to normal")
        }
    }

    private func updateTagGame() {
        guard tagRunning else { return }
        if Date() >= tagEndsAt {
            endTagGame(message: "Tag round over")
            return
        }

        let screen = activeVisibleFrame()
        let mouse = NSEvent.mouseLocation
        let destination = NSPoint(
            x: min(max(mouse.x - petSize / 2, screen.minX + 8), screen.maxX - petSize - 8),
            y: min(max(mouse.y - petSize / 2, screen.minY + 8), screen.maxY - petSize - 8)
        )
        let noodleCenter = NSPoint(x: petWindow.frame.midX, y: petWindow.frame.midY)
        let distance = hypot(noodleCenter.x - mouse.x, noodleCenter.y - mouse.y)
        if distance < 70 && Date() >= nextTagCatchAt {
            nextTagCatchAt = Date().addingTimeInterval(2)
            catView.speechText = "Tagged!"
            treatSpeechUntil = Date().addingTimeInterval(1.5)
            runTrick("Wave")
            controls.setStatus("Noodle tagged your mouse!")
        }

        let remaining = moveNoodleToward(destination)
        catView.setWalking(remaining >= 16)
    }

    @objc func spawnCloneMachine(_ sender: Any?) {
        guard cloneMachineWindow == nil else {
            cloneMachineWindow?.orderFrontRegardless()
            return
        }
        cancelOtherPlayModes(except: "clone")
        machineTreatReady = false
        statMachineHasNoodle = false

        moving = false
        followingMouse = false
        catView.setWalking(false)

        let screen = activeVisibleFrame()
        let size = NSSize(width: 760, height: 360)
        let petFrame = petWindow.frame
        let x = min(max(petFrame.minX - size.width - 24, screen.minX + 12), screen.maxX - size.width - 12)
        let y = min(max(petFrame.minY, screen.minY + 12), screen.maxY - size.height - 12)
        let window = NSWindow(contentRect: NSRect(x: x, y: y, width: size.width, height: size.height), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Noodle Clone Machine"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self

        let machineView = CloneMachineView(delegate: self)
        window.contentView = machineView
        cloneMachineWindow = window
        cloneMachineView = machineView
        cloneCount = 1
        machineView.setCloneCount(cloneCount)
        machineView.setDoors(open: true)
        window.orderFrontRegardless()
        cloneMachineView?.setStatus("Put a treat in, then drag Noodle into the chamber")
        controls.setStatus("Put a treat in the clone machine first")
    }

    @objc func cloneCountChanged(_ sender: NSSlider) {
        cloneCount = min(7, max(1, sender.integerValue))
        cloneMachineView?.setCloneCount(cloneCount)
    }

    @objc func spawnStatChanger(_ sender: Any?) {
        guard statChangerWindow == nil else {
            statChangerWindow?.orderFrontRegardless()
            return
        }
        cancelOtherPlayModes(except: "stats")
        machineTreatReady = false
        statMachineHasNoodle = false

        let screen = activeVisibleFrame()
        let size = NSSize(width: 440, height: 400)
        let petFrame = petWindow.frame
        let x = min(max(petFrame.maxX + 24, screen.minX + 12), screen.maxX - size.width - 12)
        let y = min(max(petFrame.minY, screen.minY + 12), screen.maxY - size.height - 12)
        let window = NSWindow(contentRect: NSRect(x: x, y: y, width: size.width, height: size.height), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Noodle Stat Changer"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self

        let view = StatChangerView(delegate: self)
        view.setValues(bounce: noodleBounciness, gravity: noodleGravity, hunger: noodleHunger, size: noodleSizeScale)
        window.contentView = view
        statChangerWindow = window
        statChangerView = view
        window.orderFrontRegardless()
        controls.setStatus("Stat changer ready — changes apply to everything live")
    }

    @objc func statBounceChanged(_ sender: NSSlider) {
        noodleBounciness = CGFloat(sender.doubleValue)
        statChangerView?.updateLabels()
        controls.setStatus("Everything bounces at: \(Int(round(noodleBounciness * 100)))%")
    }

    @objc func statGravityChanged(_ sender: NSSlider) {
        noodleGravity = CGFloat(sender.doubleValue)
        statChangerView?.updateLabels()
        controls.setStatus("Everything uses gravity: \(Int(round(noodleGravity)))")
    }

    @objc func statHungerChanged(_ sender: NSSlider) {
        goldenBoneFed = false
        catView.hungerLocked = false
        noodleHunger = CGFloat(sender.doubleValue)
        lastHungerUpdate = Date()
        catView.hunger = noodleHunger
        controls.setStatus("Noodle hunger: \(Int(round(noodleHunger)))%")
        if noodleHunger <= 0 && !noodleIsDead {
            starveNoodle()
        }
    }

    @objc func statSizeChanged(_ sender: NSSlider) {
        noodleSizeScale = CGFloat(sender.doubleValue)
        catView.displayScale = noodleSizeScale
        statChangerView?.updateLabels()
        controls.setStatus("Noodle size: \(Int(round(noodleSizeScale * 100)))%")
    }

    @objc func closeStatChanger(_ sender: Any?) {
        hideStatChanger()
    }

    private func hideStatChanger() {
        statChangerWindow?.orderOut(nil)
        statChangerWindow = nil
        statChangerView = nil
        machineTreatReady = false
        statMachineHasNoodle = false
        moving = true
        chooseNewTarget()
        restorePetsToDesktop()
        controls.setStatus("Stat changer closed")
    }

    @objc func closeCloneMachine(_ sender: Any?) {
        hideCloneMachine()
    }

    private func hideCloneMachine() {
        cloneMachineWindow?.orderOut(nil)
        cloneMachineWindow = nil
        cloneMachineView = nil
        cloneInProgress = false
        machineTreatReady = false
        moving = true
        chooseNewTarget()
        restorePetsToDesktop()
        controls.setStatus("Clone machine closed")
    }

    private func restorePetsToDesktop() {
        let screen = petWindow.screen?.visibleFrame ?? activeVisibleFrame()
        let safeX = min(max(petWindow.frame.minX, screen.minX + 8), screen.maxX - petSize - 8)
        let safeY = min(max(petWindow.frame.minY, screen.minY + 8), screen.maxY - petSize - 8)
        petWindow.setFrameOrigin(NSPoint(x: safeX, y: safeY))
        petWindow.orderFrontRegardless()
        for clone in clonePets {
            let cloneX = min(max(clone.window.frame.minX, screen.minX + 8), screen.maxX - petSize - 8)
            let cloneY = min(max(clone.window.frame.minY, screen.minY + 8), screen.maxY - petSize - 8)
            clone.window.setFrameOrigin(NSPoint(x: cloneX, y: cloneY))
            clone.window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === tutorialWindow {
            closeTutorial(sender)
            return false
        }
        if sender === toyPanelWindow {
            closeToyPanel(sender)
            return false
        }
        if sender === statChangerWindow {
            hideStatChanger()
            return false
        }
        if sender === cloneMachineWindow {
            hideCloneMachine()
            return false
        }
        if sender === mazeBuilderWindow {
            sender.orderOut(nil)
            mazeBuilderWindow = nil
            mazeBuilderView = nil
            mazeRunning = false
            catView.displayScale = noodleSizeScale
            mazeBuilderAccepted = false
            moving = true
            chooseNewTarget()
            petWindow.orderFrontRegardless()
            return false
        }
        return true
    }

    private func cloneMachineChamberFrame(_ index: Int) -> NSRect? {
        guard let machineWindow = cloneMachineWindow, (0..<3).contains(index) else { return nil }
        let content = machineWindow.contentRect(forFrameRect: machineWindow.frame)
        let machine = NSRect(x: content.minX + 18, y: content.minY + 56, width: content.width - 36, height: content.height - 108)
        let chamberArea = machine.insetBy(dx: 16, dy: 18)
        let gap: CGFloat = 12
        let chamberWidth = (chamberArea.width - gap * 2) / 3
        return NSRect(
            x: chamberArea.minX + CGFloat(index) * (chamberWidth + gap),
            y: chamberArea.minY,
            width: chamberWidth,
            height: chamberArea.height
        )
    }

    func noodleStartedDragging() {
        savedNoodleOrigin = petWindow.frame.origin
        noodleVelocity = .zero
        noodleIsBouncing = false
    }

    private func rejectMachineEntry() {
        petWindow.setFrameOrigin(savedNoodleOrigin)
        petWindow.orderFrontRegardless()
        moving = true
        chooseNewTarget()
        catView.speechText = "Nope!"
        treatSpeechUntil = Date().addingTimeInterval(1.5)
        controls.setStatus("Noodle wants a treat before entering")
    }

    func noodleFinishedDragging(velocity: NSPoint) {
        guard !noodleIsDead else { return }
        if let machineWindow = cloneMachineWindow,
           let inputChamber = cloneMachineChamberFrame(0),
           inputChamber.intersects(petWindow.frame) {
            guard machineTreatReady else {
                cloneMachineView?.setStatus("Noodle refuses — put a treat in first")
                rejectMachineEntry()
                return
            }
            cloneMachineView?.setStatus("Noodle is inside — press Start")
            machineWindow.orderFrontRegardless()
            petWindow.orderFrontRegardless()
            noodleVelocity = .zero
            noodleIsBouncing = false
            moving = false
            return
        }

        if let statMachineWindow = statChangerWindow, statMachineWindow.frame.intersects(petWindow.frame) {
            guard machineTreatReady else {
                statChangerView?.setStatus("Noodle refuses — put a treat in first")
                rejectMachineEntry()
                return
            }
            statMachineHasNoodle = true
            statChangerView?.setNoodleInside(true)
            noodleVelocity = .zero
            noodleIsBouncing = false
            moving = false
            statMachineWindow.orderFrontRegardless()
            petWindow.orderFrontRegardless()
            controls.setStatus("Noodle is inside the stat changer")
            return
        }

        let speed = hypot(velocity.x, velocity.y)
        noodleVelocity = speed > 100
            ? NSPoint(x: velocity.x * 0.72, y: velocity.y * 0.72)
            : NSPoint(x: 240, y: 420)
        noodleIsBouncing = true
        moving = false
        followingMouse = false
        restingUntil = Date.distantPast
        spendNoodleEnergy(8)
        catView.trick = "Angry"
        catView.speechText = "Hey! Put me down!"
        treatSpeechUntil = Date().addingTimeInterval(2)
        catView.setWalking(false)
        controls.setStatus("Noodle is bouncing like a tennis ball")
    }

    @objc func cloneMachineStartPressed(_ sender: Any?) {
        guard cloneMachineWindow != nil else { return }
        guard !cloneInProgress else { return }
        guard machineTreatReady else {
            cloneMachineView?.setStatus("Put a treat in the machine first")
            return
        }
        guard let inputChamber = cloneMachineChamberFrame(0), inputChamber.intersects(petWindow.frame) else {
            cloneMachineView?.setStatus("Drag Noodle into the chamber first")
            return
        }

        cloneInProgress = true
        machineTreatReady = false
        cloneMachineView?.animateCloning { [weak self] in
            self?.finishCloneCreation()
        }
    }

    private func finishCloneCreation() {
        guard cloneMachineWindow != nil else {
            cloneInProgress = false
            return
        }
        let outputChamber = cloneMachineChamberFrame(1)
        let screen = activeVisibleFrame()
        let petFrame = petWindow.frame
        let outputOrigin = outputChamber.map { NSPoint(x: $0.midX - petSize / 2, y: $0.midY - petSize / 2) }
        let count = cloneCount
        for index in 0..<count {
            let spread = CGFloat(index) - CGFloat(count - 1) / 2
            let proposedX = (outputOrigin?.x ?? petFrame.maxX + 28) + spread * 42
            let proposedY = (outputOrigin?.y ?? petFrame.minY) + spread * 18
            let cloneX = min(max(proposedX, screen.minX + 12), screen.maxX - petSize - 12)
            let cloneY = min(max(proposedY, screen.minY + 12), screen.maxY - petSize - 12)
            let clone = ClonePet(
                delegate: self,
                origin: NSPoint(x: cloneX, y: cloneY),
                avatarImage: catView.avatarImage,
                mirrorOffset: NSPoint(x: cloneX - petFrame.minX, y: cloneY - petFrame.minY)
            )
            clonePets.append(clone)
        }
        nextClonePlayAt = Date().addingTimeInterval(6)
        cloneMachineView?.setStatus(count == 1 ? "Clone created!" : "\(count) clones created!")
        controls.setStatus(count == 1 ? "Noodle has a new clone" : "Noodle has \(count) new clones")
        moving = true
        chooseNewTarget()
        catView.speechText = "Clone!"
        treatSpeechUntil = Date().addingTimeInterval(2)
        runTrick("Wave")
        cloneMachineView?.animateDoors(open: true)
        petWindow.orderFrontRegardless()
        cloneInProgress = false
    }

    @objc func terminateClonePressed(_ sender: Any?) {
        guard let clone = clonePets.popLast() else {
            cloneMachineView?.setStatus("There is no clone to terminate")
            return
        }
        clone.window.orderOut(nil)
        clonePlayUntil = Date.distantPast
        nextClonePlayAt = Date.distantFuture
        cloneMachineView?.setStatus("Clone terminated")
        controls.setStatus("The extra Noodle was removed")
    }

    private func updateClones() {
        guard !clonePets.isEmpty else { return }
        let now = Date()
        let screen = activeVisibleFrame()
        if now >= nextClonePlayAt {
            nextClonePlayAt = now.addingTimeInterval(Double.random(in: 10 ... 18))
            clonePlayUntil = now.addingTimeInterval(4)
        }

        let dancing = boomboxPlaying || now < clonePlayUntil
        if dancing {
            catView.trick = "Dance"
        } else if catView.trick == "Dance" && activeTrick.isEmpty {
            catView.trick = ""
        }

        for clone in clonePets {
            clone.view.trick = dancing ? "Dance" : ""
            clone.update(in: screen)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === tutorialWindow {
            tutorialNarrationTimer?.invalidate()
            tutorialNarrationTimer = nil
            catView.speechText = ""
            tutorialWindow = nil
            return
        }
        if window === toyPanelWindow {
            toyPanelWindow = nil
            return
        }
        if window === wallOverlayWindow {
            wallOverlayWindow = nil
            wallOverlayView = nil
            controls.setStatus("Maze walls are still active")
            return
        }
        if window === mazeBuilderWindow {
            mazeBuilderWindow = nil
            mazeBuilderView = nil
            mazeRunning = false
            catView.displayScale = noodleSizeScale
            if !mazeBuilderAccepted {
                moving = true
                chooseNewTarget()
            }
            mazeBuilderAccepted = false
            petWindow.orderFrontRegardless()
            return
        }
        if window === statChangerWindow {
            statChangerWindow = nil
            statChangerView = nil
            machineTreatReady = false
            statMachineHasNoodle = false
            moving = true
            chooseNewTarget()
            restorePetsToDesktop()
            controls.setStatus("Stat changer closed")
            return
        }
        guard window === cloneMachineWindow else { return }
        cloneMachineWindow = nil
        cloneMachineView = nil
        cloneInProgress = false
        moving = true
        chooseNewTarget()
        restorePetsToDesktop()
        controls.setStatus("Clone machine closed")
    }

    @objc func showTutorial(_ sender: Any?) {
        guard tutorialWindow == nil else {
            tutorialWindow?.orderFrontRegardless()
            return
        }
        let size = NSSize(width: 560, height: 560)
        let screen = activeVisibleFrame()
        let x = min(max(screen.midX - size.width / 2, screen.minX + 12), screen.maxX - size.width - 12)
        let y = min(max(screen.midY - size.height / 2, screen.minY + 12), screen.maxY - size.height - 12)
        let window = NSWindow(contentRect: NSRect(x: x, y: y, width: size.width, height: size.height), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Noodle Tutorial"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self
        window.contentView = TutorialView(delegate: self)
        tutorialWindow = window
        window.orderFrontRegardless()
        startTutorialNarration()
    }

    @objc func closeTutorial(_ sender: Any?) {
        tutorialNarrationTimer?.invalidate()
        tutorialNarrationTimer = nil
        catView.speechText = ""
        tutorialWindow?.orderOut(nil)
        tutorialWindow = nil
    }

    private func startTutorialNarration() {
        tutorialNarrationTimer?.invalidate()
        let lines = [
            "Hi! I'm Noodle, your new pet!",
            "Click me to open my menu and choose what we do.",
            "Drag toys from the Toy Control Panel onto your desktop.",
            "Give me treats before asking me to enter a machine.",
            "The Clone Machine makes friends, and the Stat Changer changes my physics.",
            "Try Disco mode, the boom box, or Spin until stopped!",
            "Have fun taking care of me!"
        ]
        tutorialNarrationIndex = 0
        catView.speechText = lines[0]
        tutorialNarrationTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.tutorialNarrationIndex += 1
            if self.tutorialNarrationIndex >= lines.count {
                timer.invalidate()
                self.tutorialNarrationTimer = nil
                self.catView.speechText = ""
            } else {
                self.catView.speechText = lines[self.tutorialNarrationIndex]
            }
        }
    }

    @objc func showToyPanel(_ sender: Any?) {
        guard toyPanelWindow == nil else {
            toyPanelWindow?.orderFrontRegardless()
            return
        }
        let size = NSSize(width: 340, height: 330)
        let screen = activeVisibleFrame()
        let x = min(max(screen.minX + 36, screen.minX + 12), screen.maxX - size.width - 12)
        let y = min(max(screen.minY + 90, screen.minY + 12), screen.maxY - size.height - 12)
        let window = NSWindow(contentRect: NSRect(x: x, y: y, width: size.width, height: size.height), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Noodle Toy Control Panel"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self
        window.contentView = ToyPanelView(delegate: self)
        toyPanelWindow = window
        window.orderFrontRegardless()
    }

    @objc func closeToyPanel(_ sender: Any?) {
        toyPanelWindow?.orderOut(nil)
        toyPanelWindow = nil
    }

    func spawnToyFromPanel(_ kind: ToyKind, at point: NSPoint) {
        let status: String
        switch kind {
        case .treat: status = "Drag the treat and throw it to Noodle"
        case .goldenBone: status = "Golden bone"
        case .trap: status = "Place the trap, then let Noodle walk into it"
        case .ball: status = "Drag the ball anywhere and Noodle will fetch it"
        case .yarn: status = "Toss the yarn and watch Noodle chase it"
        case .robot: status = "Use W A S D to drive the robot"
        case .boombox: status = "Click the boom box to start the dance"
        }
        spawnToy(kind: kind, status: status, at: point)
    }

    @objc func restOnRandomWindow(_ sender: Any?) {
        guard !catView.isCaged, let windowRect = randomDesktopWindow() else {
            nextWindowRestAt = Date().addingTimeInterval(20)
            controls.setStatus("Noodle could not find a window to rest on")
            return
        }
        let screen = activeVisibleFrame()
        let x = min(max(windowRect.midX - petSize / 2, screen.minX + 8), screen.maxX - petSize - 8)
        let topY = screen.maxY - windowRect.minY
        let y = min(topY + 6, screen.maxY - petSize - 8)
        petWindow.setFrameOrigin(NSPoint(x: x, y: y))
        restingUntil = Date().addingTimeInterval(8)
        nextWindowRestAt = Date().addingTimeInterval(Double.random(in: 20 ... 40))
        catView.setWalking(false)
        controls.setStatus("Noodle is resting on a window")
    }

    @objc func spawnTreat(_ sender: Any?) {
        spawnToy(kind: .treat, status: "Drag the treat and throw it to Noodle")
    }

    @objc func spawnTrap(_ sender: Any?) {
        spawnToy(kind: .trap, status: "Place the trap, then let Noodle walk into it")
    }

    @objc func fetchBall(_ sender: Any?) {
        spawnToy(kind: .ball, status: "Drag the ball anywhere and Noodle will fetch it")
    }

    @objc func tossYarn(_ sender: Any?) {
        spawnToy(kind: .yarn, status: "Toss the yarn and watch Noodle chase it")
    }

    @objc func spawnRobot(_ sender: Any?) {
        spawnToy(kind: .robot, status: "Use W A S D to drive the robot")
    }

    @objc func spawnBoombox(_ sender: Any?) {
        spawnToy(kind: .boombox, status: "Click the boom box to start the dance")
    }

    func activateBoombox(_ window: NSWindow) {
        guard toyWindow === window, toyKind == .boombox else { return }
        boomboxPlaying.toggle()
        catView.trick = boomboxPlaying ? "Dance" : ""
        catView.speechText = boomboxPlaying ? "Dance break!" : ""
        treatSpeechUntil = Date().addingTimeInterval(2)
        controls.setStatus(boomboxPlaying ? "The clones are mirroring the dance" : "Boom box stopped")
    }

    private func spawnToy(kind: ToyKind, status: String, at requestedPoint: NSPoint? = nil, preservePlayModes: Bool = false) {
        guard toyWindow == nil else {
            controls.setStatus("Noodle is already playing with a toy")
            return
        }
        let feedingAMachine = kind == .treat && (cloneMachineWindow != nil || statChangerWindow != nil)
        if !feedingAMachine && !preservePlayModes {
            cancelOtherPlayModes(except: "toy")
        }

        let screen = activeVisibleFrame()
        let mouse = requestedPoint ?? NSEvent.mouseLocation
        let size: CGFloat = 56
        let x = min(max(mouse.x - size / 2, screen.minX + 8), screen.maxX - size - 8)
        let y = min(max(mouse.y - size / 2, screen.minY + 8), screen.maxY - size - 8)
        let window = NSWindow(contentRect: NSRect(x: x, y: y, width: size, height: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = ToyView(delegate: self, kind: kind)
        window.orderFrontRegardless()
        toyWindow = window
        toyKind = kind
        fetchingToy = false
        toyTarget = .zero
        toyVelocity = .zero
        toyIsThrown = false
        toyReturning = false
        toyHomeOrigin = window.frame.origin
        trapArmed = false
        trapTriggered = false
        trapReleaseAt = Date.distantPast
        robotKeys.removeAll()
        robotTarget = .zero
        robotNextTurnAt = Date.distantPast
        boomboxPlaying = false
        controls.setStatus(status)
    }

    private func maybeDropGoldenBone(at now: Date) {
        guard !goldenBoneFed, !noodleIsDead, toyWindow == nil, now >= nextGoldenBoneChanceAt else { return }
        nextGoldenBoneChanceAt = now.addingTimeInterval(Double.random(in: 12 ... 28))

        let isPlaying = !activeTrick.isEmpty || !catView.trick.isEmpty || noodleIsBouncing || tagRunning ||
            discoOverlayWindow != nil || boomboxPlaying || clonePlayUntil > now
        guard isPlaying, Double.random(in: 0 ... 1) < 0.24 else { return }

        let size: CGFloat = 56
        let point = NSPoint(x: petWindow.frame.midX - size / 2, y: petWindow.frame.maxY - size / 2 + 24)
        spawnToy(kind: .goldenBone, status: "Noodle threw up a golden bone! Feed it to him for endless hunger", at: point, preservePlayModes: true)
        catView.speechText = "Golden bone!"
        treatSpeechUntil = now.addingTimeInterval(2)
    }

    private func triggerTrap() {
        guard trapArmed, !trapTriggered, !noodleIsDead else { return }
        trapArmed = false
        trapTriggered = true
        trapReleaseAt = Date().addingTimeInterval(3)
        moving = false
        followingMouse = false
        noodleVelocity = .zero
        noodleIsBouncing = false
        catView.setWalking(false)
        catView.trick = "Surprised"
        catView.speechText = "Gotcha!"
        treatSpeechUntil = Date().addingTimeInterval(2)
        controls.setStatus("Noodle stepped on the trap — he will be free soon")
    }

    func toyDropped(_ window: NSWindow, kind: ToyKind, velocity: NSPoint) {
        guard toyWindow === window else { return }

        toyReturning = false

        if kind == .treat,
           let machineWindow = cloneMachineWindow ?? statChangerWindow,
           machineWindow.frame.intersects(window.frame) {
            window.orderOut(nil)
            toyWindow = nil
            machineTreatReady = true
            catView.speechText = "Good treat!"
            treatSpeechUntil = Date().addingTimeInterval(1.5)
            cloneMachineView?.setStatus("Treat accepted — Noodle will go inside now")
            statChangerView?.setStatus("Treat accepted — drag Noodle into the chamber")
            controls.setStatus("Treat placed in the machine")
            return
        }

        if kind == .boombox {
            toyIsThrown = false
            fetchingToy = false
            toyVelocity = .zero
            toyHomeOrigin = window.frame.origin
            return
        }

        if kind == .robot {
            toyIsThrown = false
            fetchingToy = false
            toyVelocity = .zero
            robotKeys.removeAll()
            toyHomeOrigin = window.frame.origin
            robotTarget = window.frame.origin
            robotNextTurnAt = Date().addingTimeInterval(0.5)
            catView.speechText = "Ready!"
            treatSpeechUntil = Date().addingTimeInterval(1.5)
            controls.setStatus("Robot ready — use W A S D")
            return
        }

        if kind == .trap {
            toyIsThrown = false
            fetchingToy = false
            toyReturning = false
            toyVelocity = .zero
            toyHomeOrigin = window.frame.origin
            trapArmed = true
            controls.setStatus("Trap set — let Noodle walk into it")
            let distanceToNoodle = hypot(window.frame.midX - petWindow.frame.midX, window.frame.midY - petWindow.frame.midY)
            if distanceToNoodle < 115 {
                triggerTrap()
            }
            return
        }

        let treatCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let noodleCenter = NSPoint(x: petWindow.frame.midX, y: petWindow.frame.midY)
        let distance = hypot(treatCenter.x - noodleCenter.x, treatCenter.y - noodleCenter.y)
        guard distance < 115 else {
            let speed = hypot(velocity.x, velocity.y)
            toyVelocity = speed > 120 ? NSPoint(x: velocity.x * 0.72, y: velocity.y * 0.72) : NSPoint(x: 420, y: 280)
            toyIsThrown = true
            fetchingToy = false
            followingMouse = false
            restingUntil = Date.distantPast
            toyTarget = NSPoint(x: window.frame.midX, y: window.frame.midY)
            catView.speechText = kind == .yarn ? "Wheee!" : "Throw!"
            treatSpeechUntil = Date().addingTimeInterval(2)
            if kind == .ball {
                controls.setStatus("Ball thrown!")
            } else if kind == .yarn {
                controls.setStatus("Yarn thrown!")
            } else {
                controls.setStatus("Treat thrown!")
            }
            return
        }

        if kind == .goldenBone {
            window.orderOut(nil)
            toyWindow = nil
            feedGoldenBone()
            runTrick("Wave", costsEnergy: false)
            controls.setStatus("Noodle ate the golden bone — hunger will never run out")
        } else if kind == .treat {
            window.orderOut(nil)
            toyWindow = nil
            giveTreat()
            runTrick("Wave", costsEnergy: false)
            controls.setStatus("Noodle caught the treat")
        } else {
            toyIsThrown = false
            fetchingToy = false
            toyReturning = true
            toyVelocity = .zero
            catView.speechText = kind == .yarn ? "Purr!" : "Got it!"
            treatSpeechUntil = Date().addingTimeInterval(2)
            controls.setStatus(kind == .yarn ? "Noodle is bringing back the yarn" : "Noodle is bringing back the ball")
        }
    }

    func toyPickedUp(_ window: NSWindow) {
        guard toyWindow === window else { return }
        toyIsThrown = false
        fetchingToy = false
        toyReturning = false
        toyVelocity = .zero
        restingUntil = Date.distantPast
    }

    private func makePetWindow() {
        // NSScreen.main can refer to a different display when the app launches
        // from Finder or Terminal. Prefer the display under the pointer so the
        // pet always starts somewhere the user can see.
        let screen = activeVisibleFrame()
        let origin = NSPoint(x: screen.maxX - petSize - 80, y: screen.minY + 90)
        petWindow = PetWindow(contentRect: NSRect(origin: origin, size: NSSize(width: petSize, height: petSize)), styleMask: [.borderless], backing: .buffered, defer: false)
        petWindow.isOpaque = false
        petWindow.backgroundColor = .clear
        petWindow.hasShadow = false
        petWindow.level = .floating
        petWindow.alphaValue = 1
        petWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        catView = CatView(frame: NSRect(x: 0, y: 0, width: petSize, height: petSize))
        catView.hostWindow = petWindow
        catView.delegate = self
        petWindow.contentView = catView
        petWindow.orderFrontRegardless()
    }

    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func updateLaunchBox(now: Date) -> Bool {
        if !resetBoxDropping && resetBoxDropAt != Date.distantPast && now >= resetBoxDropAt {
            let screen = activeVisibleFrame()
            resetBoxTarget = NSPoint(
                x: min(max(screen.maxX - petSize - 80, screen.minX + 12), screen.maxX - petSize - 12),
                y: screen.maxY - petSize - 36
            )
            petWindow.setFrameOrigin(NSPoint(x: resetBoxTarget.x, y: screen.maxY + 30))
            petWindow.orderFrontRegardless()
            noodleManuallyOffscreen = false
            resetBoxDropAt = Date.distantPast
            resetBoxDropping = true
            catView.isInLaunchBox = true
            catView.speechText = ""
        }

        if resetBoxDropping {
            let current = petWindow.frame.origin
            let distance = current.y - resetBoxTarget.y
            if distance <= 2 {
                petWindow.setFrameOrigin(resetBoxTarget)
                resetBoxDropping = false
                catView.speechText = ""
                controls.setStatus("Noodle's box arrived — click it to open him")
            } else {
                let step = min(distance, max(10, distance * 0.08))
                petWindow.setFrameOrigin(NSPoint(x: resetBoxTarget.x, y: current.y - step))
            }
        }

        guard isLaunchBoxPaused else { return false }
        // Keep every pet timer frozen while Noodle is off-screen or boxed.
        lastHungerUpdate = now
        catView.speechText = ""
        catView.trick = ""
        catView.setWalking(false)
        catView.showTreats = false
        return true
    }

    private func tick() {
        let now = Date()
        if updateLaunchBox(now: now) {
            return
        }
        catView.animationTime += 1.0 / 60.0
        let hungerElapsed = now.timeIntervalSince(lastHungerUpdate)
        if goldenBoneFed {
            noodleHunger = 100
        } else {
            let trick = catView.trick.lowercased()
            var hungerRate: CGFloat = 0.08
            if noodleIsBouncing { hungerRate += 0.32 }
            if trick.contains("dance") { hungerRate += 0.28 }
            if trick.contains("jump") || trick.contains("zoom") || trick.contains("spin") || trick.contains("roll") {
                hungerRate += 0.18
            }
            noodleHunger = max(0, noodleHunger - CGFloat(hungerElapsed) * hungerRate)
        }
        lastHungerUpdate = now
        catView.hunger = noodleHunger
        catView.hungerLocked = goldenBoneFed
        catView.showTreats = now < feedTreatsUntil
        if !noodleIsDead && noodleHunger <= 0 {
            starveNoodle()
        }
        if noodleIsDead {
            return
        }
        if Date() > trickEndsAt && !activeTrick.isEmpty {
            activeTrick = ""
            catView.trick = ""
        }
        if openingGreetingActive && now >= greetingUntil {
            openingGreetingIndex += 1
            if openingGreetingIndex < openingGreetingLines.count {
                catView.speechText = openingGreetingLines[openingGreetingIndex]
                greetingUntil = now.addingTimeInterval(3)
            } else {
                catView.speechText = ""
                greetingUntil = Date.distantPast
                openingGreetingActive = false
            }
        }
        if Date() >= treatSpeechUntil && (catView.speechText == "Yum!" || catView.speechText == "Treats!" || catView.speechText == "Nom nom!" || catView.speechText == "Catch me!" || catView.speechText == "Tagged!" || catView.speechText == "DANCE BREAK! TURN VOLUME UP UP UP!" || catView.speechText == "Hey! Put me down!" || catView.speechText == "Nope!" || catView.speechText == "Good treat!" || catView.speechText == "Follow me!" || catView.speechText == "Free!") {
            catView.speechText = ""
        }
        if now >= nextAutomaticFollowAt && !catView.isCaged && !noodleManuallyOffscreen && !followingMouse {
            nextAutomaticFollowAt = now.addingTimeInterval(automaticFollowInterval)
            automaticFollowUntil = now.addingTimeInterval(12)
            followingMouse = true
            moving = true
            restingUntil = Date.distantPast
            catView.speechText = "Follow me!"
            treatSpeechUntil = now.addingTimeInterval(3)
            controls.setStatus("Noodle is following your cursor for a moment")
        }
        if automaticFollowUntil != Date.distantPast && now >= automaticFollowUntil {
            automaticFollowUntil = Date.distantPast
            followingMouse = false
            nextWindowRestAt = now.addingTimeInterval(Double.random(in: 20 ... 40))
            chooseNewTarget()
            controls.setStatus("Noodle finished following your cursor")
        }
        maybeDropGoldenBone(at: now)
        if trapArmed, let trapWindow = toyWindow {
            let distanceToNoodle = hypot(trapWindow.frame.midX - petWindow.frame.midX, trapWindow.frame.midY - petWindow.frame.midY)
            if distanceToNoodle < 100 {
                triggerTrap()
            }
        }
        if trapTriggered {
            if now >= trapReleaseAt {
                toyWindow?.orderOut(nil)
                toyWindow = nil
                trapTriggered = false
                trapReleaseAt = Date.distantPast
                catView.trick = ""
                catView.speechText = "Free!"
                treatSpeechUntil = now.addingTimeInterval(1.5)
                moving = true
                nextWindowRestAt = now.addingTimeInterval(Double.random(in: 20 ... 40))
                chooseNewTarget()
                controls.setStatus("Noodle escaped the trap")
            } else {
                catView.setWalking(false)
                return
            }
        }

        if let overlay = discoOverlayWindow, let overlayView = discoOverlayView {
            if Date() >= discoEndsAt {
                stopDiscoMode()
            } else {
                discoPhase += 1.0 / 60.0
                overlayView.dimProgress = min(1, overlayView.dimProgress + (1.0 / 60.0) / 2.4)
                overlayView.phase = discoPhase
                overlayView.spotlightCenter = NSPoint(
                    x: petWindow.frame.midX - overlay.frame.minX,
                    y: petWindow.frame.midY - overlay.frame.minY
                )
                let jump = abs(sin(discoPhase * 7.0)) * 28
                let sway = sin(discoPhase * 3.0) * 20
                petWindow.setFrameOrigin(NSPoint(x: discoBaseOrigin.x + sway, y: discoBaseOrigin.y + jump))
                catView.trick = spinMode ? "Spin" : "Dance"
                catView.setWalking(false)
                petWindow.orderFrontRegardless()
            }
        }

        if popcornTrip {
            if !popcornOffscreen {
                let current = petWindow.frame.origin
                let dx = popcornExitTarget.x - current.x
                let dy = popcornExitTarget.y - current.y
                let distance = sqrt(dx * dx + dy * dy)
                if Date() >= popcornLeavingAt || distance < 24 {
                    popcornOffscreen = true
                    popcornWalkingOut = false
                    catView.speechText = ""
                    petWindow.orderOut(nil)
                } else {
                    popcornWalkingOut = true
                    catView.setWalking(true)
                    let step = min(distance, max(5.0, distance * 0.035))
                    petWindow.setFrameOrigin(NSPoint(x: current.x + dx / distance * step, y: current.y + dy / distance * step))
                }
            } else if Date() >= popcornReturnAt {
                popcornTrip = false
                popcornOffscreen = false
                popcornWalkingOut = false
                petWindow.setFrameOrigin(popcornReturnOrigin)
                petWindow.orderFrontRegardless()
                catView.showPopcornMachine = true
                catView.speechText = ""
                popcornFlavorPromptPending = true
                DispatchQueue.main.async { [weak self] in self?.showPopcornFlavorMenu() }
            }
        }

        if popcornFlavor != nil && Date() >= popcornCookUntil {
            self.popcornFlavor = nil
            catView.showPopcornMachine = false
            catView.speechText = ""
            dropPopcornBucket()
            moving = true
            nextWindowRestAt = Date().addingTimeInterval(Double.random(in: 20 ... 40))
            chooseNewTarget()
        }

        if let treat = mazeTreatPoint, hypot(treat.x - petWindow.frame.midX, treat.y - petWindow.frame.midY) < 58 {
            mazeTreatPoint = nil
            pathPoints.removeAll()
            pathIndex = 0
            mazeRunning = false
            catView.displayScale = noodleSizeScale
            wallOverlayView?.treatPoint = nil
            catView.speechText = "Yum!"
            treatSpeechUntil = Date().addingTimeInterval(3)
            runTrick("Wave")
            controls.setStatus("Noodle found the treat")
            if let mazeBuilderWindow, mazeBuilderAccepted {
                mazeBuilderWindow.close()
            }
        }

        if followingMouse {
            let screen = activeVisibleFrame()
            let mouse = NSEvent.mouseLocation
            target = NSPoint(
                x: min(max(mouse.x - petSize / 2, screen.minX + 8), screen.maxX - petSize - 8),
                y: min(max(mouse.y - petSize / 2, screen.minY + 8), screen.maxY - petSize - 8)
            )
            pathPoints.removeAll()
            pathIndex = 0
        }

        updateClones()
        if !noodleManuallyOffscreen {
            updateTagGame()
        }

        if noodleManuallyOffscreen {
            catView.setWalking(false)
        } else if tagRunning {
            // Tag movement is handled by updateTagGame.
        } else if discoOverlayWindow != nil {
            catView.setWalking(false)
        } else if spinMode {
            catView.setWalking(false)
        } else if popcornTrip {
            catView.setWalking(popcornWalkingOut && !popcornOffscreen)
        } else if noodleIsBouncing {
            updateNoodleBounce()
        } else if toyKind == .robot, let toyWindow {
            updateRobotToy(toyWindow)
        } else if toyIsThrown, let toyWindow {
            let screen = toyWindow.screen?.visibleFrame ?? activeVisibleFrame()
            var nextOrigin = toyWindow.frame.origin
            toyVelocity.y -= noodleGravity / 60.0
            nextOrigin.x += toyVelocity.x / 60.0
            nextOrigin.y += toyVelocity.y / 60.0
            var bounced = false

            if nextOrigin.x <= screen.minX || nextOrigin.x + toyWindow.frame.width >= screen.maxX {
                toyVelocity.x *= -noodleBounciness
                nextOrigin.x = min(max(nextOrigin.x, screen.minX), screen.maxX - toyWindow.frame.width)
                bounced = true
            }
            if nextOrigin.y <= screen.minY || nextOrigin.y + toyWindow.frame.height >= screen.maxY {
                toyVelocity.y *= -noodleBounciness
                nextOrigin.y = min(max(nextOrigin.y, screen.minY), screen.maxY - toyWindow.frame.height)
                bounced = true
            }

            let toyCenter = NSPoint(x: nextOrigin.x + toyWindow.frame.width / 2, y: nextOrigin.y + toyWindow.frame.height / 2)
            for wall in wallSegments where distance(from: toyCenter, to: wall) < 30 {
                if abs(wall.end.x - wall.start.x) >= abs(wall.end.y - wall.start.y) {
                    toyVelocity.y *= -noodleBounciness
                } else {
                    toyVelocity.x *= -noodleBounciness
                }
                bounced = true
                break
            }

            toyWindow.setFrameOrigin(nextOrigin)
            toyVelocity.x *= 0.987
            toyVelocity.y *= 0.987
            if bounced {
                controls.setStatus("Toy bounced!")
            }

            let noodleCenter = NSPoint(x: petWindow.frame.midX, y: petWindow.frame.midY)
            let catchDistance = hypot(toyCenter.x - noodleCenter.x, toyCenter.y - noodleCenter.y)
            if catchDistance < 76 {
                toyIsThrown = false
                toyVelocity = .zero
                if toyKind == .treat || toyKind == .goldenBone {
                    toyWindow.orderOut(nil)
                    self.toyWindow = nil
                    fetchingToy = false
                    toyReturning = false
                    if toyKind == .goldenBone {
                        feedGoldenBone()
                    } else {
                        giveTreat()
                    }
                    runTrick("Wave", costsEnergy: false)
                    controls.setStatus(toyKind == .goldenBone ? "Noodle ate the golden bone — hunger will never run out" : "Noodle caught the treat")
                } else {
                    fetchingToy = false
                    toyReturning = true
                    catView.speechText = toyKind == .yarn ? "Purr!" : "Got it!"
                    treatSpeechUntil = Date().addingTimeInterval(2)
                    controls.setStatus(toyKind == .yarn ? "Noodle is bringing back the yarn" : "Noodle is bringing back the ball")
                }
            } else {
                let remaining = moveNoodleToward(NSPoint(x: toyCenter.x - petSize / 2, y: toyCenter.y - petSize / 2))
                catView.setWalking(remaining >= 16)
            }
            if toyIsThrown && hypot(toyVelocity.x, toyVelocity.y) < 24 {
                toyIsThrown = false
                fetchingToy = true
                toyTarget = toyCenter
                controls.setStatus("Noodle is chasing the toy")
            }
        } else if toyReturning, let toyWindow {
            let remaining = moveNoodleToward(toyHomeOrigin)
            let carriedOrigin = NSPoint(
                x: petWindow.frame.midX - toyWindow.frame.width / 2,
                y: petWindow.frame.minY + 18
            )
            toyWindow.setFrameOrigin(carriedOrigin)
            catView.setWalking(remaining >= 16)
            if remaining < 18 {
                toyReturning = false
                toyWindow.setFrameOrigin(toyHomeOrigin)
                catView.speechText = ""
                controls.setStatus("Noodle brought the toy back")
                moving = true
                nextWindowRestAt = Date().addingTimeInterval(Double.random(in: 20 ... 40))
                chooseNewTarget()
            }
        } else if fetchingToy, let toyWindow {
            let current = petWindow.frame.origin
            let targetOrigin = NSPoint(x: toyTarget.x - petSize / 2, y: toyTarget.y - petSize / 2)
            let dx = targetOrigin.x - current.x
            let dy = targetOrigin.y - current.y
            let distance = sqrt(dx * dx + dy * dy)
            catView.setWalking(distance >= 16)
            if distance < 18 {
                fetchingToy = false
                if toyKind == .treat || toyKind == .goldenBone {
                    toyWindow.orderOut(nil)
                    self.toyWindow = nil
                    toyReturning = false
                    if toyKind == .goldenBone {
                        feedGoldenBone()
                    } else {
                        giveTreat()
                    }
                    runTrick("Wave", costsEnergy: false)
                    controls.setStatus(toyKind == .goldenBone ? "Noodle ate the golden bone — hunger will never run out" : "Noodle fetched the treat")
                } else if toyKind == .yarn {
                    toyReturning = true
                    toyVelocity = .zero
                    catView.speechText = "Purr!"
                    treatSpeechUntil = Date().addingTimeInterval(2)
                    controls.setStatus("Noodle is bringing back the yarn")
                } else {
                    toyReturning = true
                    toyVelocity = .zero
                    catView.speechText = "Got it!"
                    treatSpeechUntil = Date().addingTimeInterval(2)
                    controls.setStatus("Noodle is bringing back the ball")
                }
            } else {
                let step = min(distance, max(3.2, distance * 0.045))
                petWindow.setFrameOrigin(NSPoint(x: current.x + dx / distance * step, y: current.y + dy / distance * step))
            }
        } else if catView.isCaged {
            catView.setWalking(false)
        } else if Date() < restingUntil {
            catView.setWalking(false)
        } else if moving || followingMouse {
            if restingUntil != Date.distantPast {
                restingUntil = Date.distantPast
                chooseNewTarget()
            }
            if !followingMouse && Date() >= nextWindowRestAt {
                restOnRandomWindow(nil)
                return
            }
            let current = petWindow.frame.origin
            let destination = !followingMouse && pathIndex < pathPoints.count ? pathPoints[pathIndex] : target
            let dx = destination.x - current.x
            let dy = destination.y - current.y
            let distance = sqrt(dx * dx + dy * dy)
            catView.setWalking(distance >= 16)
            if distance < 16 {
                if pathIndex < pathPoints.count {
                    pathIndex += 1
                } else {
                    chooseNewTarget()
                }
            }
            else {
                let step = min(distance, max(2.2, distance * 0.024))
                petWindow.setFrameOrigin(NSPoint(x: current.x + dx / distance * step, y: current.y + dy / distance * step))
            }
        } else { catView.setWalking(false) }
        catView.needsDisplay = true
    }

    private func chooseNewTarget() {
        let screen = activeVisibleFrame()
        let current = petWindow?.frame.origin ?? NSPoint(x: screen.midX, y: screen.midY)
        var next = current
        repeat {
            next = NSPoint(x: CGFloat.random(in: screen.minX + 35 ... screen.maxX - petSize - 35), y: CGFloat.random(in: screen.minY + 25 ... screen.maxY - petSize - 25))
        } while hypot(next.x - current.x, next.y - current.y) < 220
        target = next
        if let treat = mazeTreatPoint {
            pathPoints = wallPath(to: treat)
        } else if !wallSegments.isEmpty {
            pathPoints = wallPath(to: target)
        } else {
            pathPoints.removeAll()
        }
        pathIndex = 0
    }

    @objc func toggleMovement(_ sender: NSButton) {
        moving.toggle()
        sender.title = moving ? "Pause movement" : "Move around"
        controls.setStatus(moving ? "Noodle is exploring your desktop" : "Noodle is taking a little break")
    }

    @objc func toggleMovementFromMenu(_ sender: Any?) {
        moving.toggle()
        controls.setStatus(moving ? "Noodle is exploring your desktop" : "Noodle is taking a little break")
    }

    @objc func toggleFollowMouse(_ sender: Any?) {
        guard !catView.isCaged else {
            controls.setStatus("Let Noodle out before following the mouse")
            return
        }
        automaticFollowUntil = Date.distantPast
        followingMouse.toggle()
        restingUntil = Date.distantPast
        if followingMouse {
            moving = true
            nextWindowRestAt = Date.distantFuture
            controls.setStatus("Noodle is following your mouse")
        } else {
            nextWindowRestAt = Date().addingTimeInterval(Double.random(in: 20 ... 40))
            chooseNewTarget()
            controls.setStatus("Noodle is exploring your desktop")
        }
        if let menuItem = sender as? NSMenuItem {
            menuItem.state = followingMouse ? .on : .off
            menuItem.title = followingMouse ? "Stop following mouse" : "Follow my mouse"
        } else if let button = sender as? NSButton {
            button.title = followingMouse ? "Stop following" : "Follow mouse"
        }
    }

    @objc func quitNoodle(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc func petNoodle(_ sender: Any?) {
        runTrick("Wave")
        controls.setStatus("Noodle is enjoying the attention")
    }

    @objc func feedNoodle(_ sender: Any?) {
        guard !noodleIsDead else {
            controls.setStatus("Noodle is gone — use Care > Reset Noodle")
            return
        }
        spawnToy(kind: .treat, status: "Treat ready — drag and toss it to Noodle")
    }

    private func giveTreat(amount: CGFloat = 35) {
        guard !noodleIsDead else { return }
        noodleHunger = min(100, noodleHunger + amount)
        lastHungerUpdate = Date()
        feedTreatsUntil = Date().addingTimeInterval(2)
        catView.showTreats = true
        catView.hunger = noodleHunger
        catView.speechText = "Treats!"
        treatSpeechUntil = Date().addingTimeInterval(2)
    }

    private func feedGoldenBone() {
        guard !noodleIsDead else { return }
        goldenBoneFed = true
        noodleHunger = 100
        lastHungerUpdate = Date()
        feedTreatsUntil = Date().addingTimeInterval(2)
        catView.hunger = noodleHunger
        catView.hungerLocked = true
        catView.showTreats = true
        catView.speechText = "Golden bone!"
        treatSpeechUntil = Date().addingTimeInterval(3)
    }

    @objc func toggleCage(_ sender: Any?) {
        catView.isCaged.toggle()
        if catView.isCaged {
            restingUntil = Date.distantFuture
            controls.setStatus("Noodle is resting in his cage")
        } else {
            restingUntil = Date.distantPast
            nextWindowRestAt = Date().addingTimeInterval(20)
            chooseNewTarget()
            controls.setStatus("Noodle is back out exploring")
        }
    }

    @objc func resetNoodle(_ sender: Any?) {
        if discoOverlayWindow != nil {
            stopDiscoMode()
        }
        if statChangerWindow != nil {
            hideStatChanger()
        }
        machineTreatReady = false
        statMachineHasNoodle = false
        if tagRunning {
            endTagGame(message: "Tag reset")
        }
        moving = false
        noodleVelocity = .zero
        noodleIsBouncing = false
        noodleHunger = 100
        lastHungerUpdate = Date()
        feedTreatsUntil = Date.distantPast
        noodleIsDead = false
        goldenBoneFed = false
        nextGoldenBoneChanceAt = Date.distantPast
        spinMode = false
        followingMouse = false
        automaticFollowUntil = Date.distantPast
        nextAutomaticFollowAt = Date().addingTimeInterval(automaticFollowInterval)
        noodleManuallyOffscreen = false
        resetBoxDropAt = Date.distantPast
        resetBoxDropping = false
        backspacePresses.removeAll()
        activeTrick = ""
        catView.trick = ""
        catView.isDead = false
        catView.hungerLocked = false
        catView.isCaged = false
        catView.showTreats = false
        catView.speechText = ""
        toyWindow?.orderOut(nil)
        toyWindow = nil
        fetchingToy = false
        toyTarget = .zero
        toyVelocity = .zero
        toyIsThrown = false
        toyReturning = false
        toyHomeOrigin = .zero
        trapArmed = false
        trapTriggered = false
        trapReleaseAt = Date.distantPast
        robotKeys.removeAll()
        robotTarget = .zero
        robotNextTurnAt = Date.distantPast
        treatSpeechUntil = Date.distantPast
        boomboxPlaying = false
        popcornTrip = false
        popcornOffscreen = false
        popcornWalkingOut = false
        popcornFlavorPromptPending = false
        popcornFlavor = nil
        popcornCookUntil = Date.distantPast
        popcornBucketWindow?.orderOut(nil)
        popcornBucketWindow = nil
        catView.showPopcornMachine = false
        for clone in clonePets {
            clone.window.orderOut(nil)
        }
        clonePets.removeAll()
        clonePlayUntil = Date.distantPast
        nextClonePlayAt = Date.distantPast
        cloneMachineWindow?.close()
        cloneMachineWindow = nil
        cloneMachineView = nil
        cloneInProgress = false
        wallSegments.removeAll()
        mazeTreatPoint = nil
        pathPoints.removeAll()
        pathIndex = 0
        wallOverlayView?.walls = []
        wallOverlayView?.treatPoint = nil
        mazeBuilderWindow?.close()
        mazeBuilderWindow = nil
        mazeBuilderView = nil
        mazeBuilderAccepted = false
        mazeRunning = false
        catView.displayScale = noodleSizeScale
        restingUntil = Date.distantPast
        nextWindowRestAt = Date().addingTimeInterval(20)
        catView.isInLaunchBox = false
        openingGreetingActive = false
        noodleManuallyOffscreen = true
        resetBoxDropAt = Date().addingTimeInterval(5)
        catView.setWalking(false)
        petWindow.orderOut(nil)
        controls.setStatus("Noodle went off-screen — his box arrives in 5 seconds")
    }

    @objc func wave(_ sender: Any?) { runTrick("Wave") }
    @objc func zoomies(_ sender: Any?) { runTrick("Zoomies") }
    @objc func nap(_ sender: Any?) { runTrick("Nap") }
    @objc func dance(_ sender: Any?) { runTrick("Dance") }
    @objc func jump(_ sender: Any?) { runTrick("Jump") }
    @objc func rollOver(_ sender: Any?) { runTrick("Roll over") }
    @objc func beg(_ sender: Any?) { runTrick("Beg") }
    @objc func playDead(_ sender: Any?) { runTrick("Play dead") }
    @objc func stretch(_ sender: Any?) { runTrick("Stretch") }

    @objc func toggleSpinMode(_ sender: Any?) {
        guard !noodleIsDead else {
            controls.setStatus("Noodle is gone — use Care > Reset Noodle")
            return
        }
        spinMode.toggle()
        activeTrick = ""
        trickEndsAt = Date.distantPast
        if spinMode {
            moving = false
            followingMouse = false
            catView.trick = "Spin"
            controls.setStatus("Noodle is spinning until you stop him")
        } else {
            catView.trick = discoOverlayWindow == nil ? "" : "Dance"
            moving = true
            nextWindowRestAt = Date().addingTimeInterval(Double.random(in: 20 ... 40))
            chooseNewTarget()
            controls.setStatus("Noodle stopped spinning")
        }
    }

    private func spendNoodleEnergy(_ amount: CGFloat) {
        guard !goldenBoneFed else {
            noodleHunger = 100
            catView.hunger = noodleHunger
            return
        }
        noodleHunger = max(0, noodleHunger - amount)
        lastHungerUpdate = Date()
        catView.hunger = noodleHunger
    }

    private func starveNoodle() {
        if discoOverlayWindow != nil {
            stopDiscoMode()
        }
        noodleIsDead = true
        moving = false
        noodleVelocity = .zero
        noodleIsBouncing = false
        followingMouse = false
        noodleManuallyOffscreen = false
        popcornTrip = false
        popcornOffscreen = false
        popcornWalkingOut = false
        catView.showPopcornMachine = false
        spinMode = false
        activeTrick = ""
        catView.isDead = true
        catView.setWalking(false)
        catView.trick = "Dead"
        catView.speechText = "I'm too hungry..."
        treatSpeechUntil = Date.distantFuture
        petWindow.orderFrontRegardless()
        controls.setStatus("Noodle died of hunger — use Care > Reset Noodle")
    }

    private func runTrick(_ name: String, costsEnergy: Bool = true) {
        guard !noodleIsDead else {
            controls.setStatus("Noodle is gone — use Care > Reset Noodle")
            return
        }
        if costsEnergy {
            spendNoodleEnergy(4)
        }
        if name != "Spin" {
            spinMode = false
        }
        activeTrick = name
        catView.trick = name
        trickEndsAt = Date().addingTimeInterval(3.0)
        controls.setStatus("Noodle is doing: \(name)")
    }

    @objc func importPhoto(_ sender: Any?) {
        let open = NSOpenPanel()
        open.allowedContentTypes = [.image]
        open.allowsMultipleSelection = false
        open.message = "Choose a photo to turn into Noodle's avatar"
        guard open.runModal() == .OK, let url = open.url, let image = NSImage(contentsOf: url) else { return }
        importedImage = image
        catView.avatarImage = image
        controls.setPhoto(image)
        controls.setStatus("Noodle learned a new look from your photo")
    }

    @objc func stylePhoto(_ sender: Any?) {
        guard let image = importedImage, let data = image.tiffRepresentation else { return }
        controls.setStatus("Adding a little Noodle magic…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let styled = makeNoodleStyle(from: data)
            DispatchQueue.main.async {
                guard let self, let styled else {
                    self?.controls.setStatus("That photo could not be styled")
                    return
                }
                self.importedImage = styled
                self.catView.avatarImage = styled
                self.controls.setPhoto(styled)
                self.controls.setStatus("Noodle's custom look is ready")
            }
        }
    }

    @objc func teachTrick(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Teach Noodle a trick"
        alert.informativeText = "Give the trick a name. For now, Noodle will perform it with a playful custom pose."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "e.g. High five"
        alert.accessoryView = field
        alert.addButton(withTitle: "Teach")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        runTrick(name)
        controls.setStatus("New trick learned: \(name)")
    }

    @objc func organizeWindows(_ sender: Any?) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            controls.setStatus("Allow Accessibility access so Noodle can tidy windows")
            return
        }

        let screen = activeVisibleFrame()
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let applications = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != currentPID && $0.activationPolicy == .regular && !$0.isHidden
        }

        var windows: [AXUIElement] = []
        for application in applications {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            var rawWindows: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &rawWindows) == .success,
                  let appWindows = rawWindows as? [AXUIElement] else { continue }

            for window in appWindows {
                var minimized: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let isMinimized = minimized as? Bool, isMinimized { continue }

                var role: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role) == .success,
                   let role = role as? String, role != kAXWindowRole { continue }

                var subrole: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole) == .success,
                   let subrole = subrole as? String, subrole == "AXFullScreenWindow" { continue }

                windows.append(window)
            }
        }

        let visibleWindows = Array(windows.prefix(12))
        guard !visibleWindows.isEmpty else {
            controls.setStatus("Noodle could not find any open windows to tidy")
            return
        }

        let columns = max(1, Int(ceil(sqrt(Double(visibleWindows.count)))))
        let rows = Int(ceil(Double(visibleWindows.count) / Double(columns)))
        let padding: CGFloat = 18
        let gap: CGFloat = 14
        let cellWidth = (screen.width - padding * 2 - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let cellHeight = (screen.height - padding * 2 - CGFloat(rows - 1) * gap) / CGFloat(rows)

        var arranged = 0
        for (index, window) in visibleWindows.enumerated() {
            let column = index % columns
            let row = index / columns
            let bottomY = screen.maxY - padding - CGFloat(row + 1) * cellHeight - CGFloat(row) * gap
            var size = CGSize(width: cellWidth, height: cellHeight)
            var position = CGPoint(
                x: screen.minX + padding + CGFloat(column) * (cellWidth + gap),
                y: screen.maxY - (bottomY + cellHeight)
            )

            guard let sizeValue = AXValueCreate(.cgSize, &size),
                  let positionValue = AXValueCreate(.cgPoint, &position) else { continue }

            let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            if sizeResult == .success || positionResult == .success { arranged += 1 }
        }

        runTrick("Dance")
        controls.setStatus(arranged == visibleWindows.count ? "Noodle tidied \(arranged) windows" : "Noodle tidied \(arranged) of \(visibleWindows.count) windows")
    }

    @objc func nudgeWindow(_ sender: Any?) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            controls.setStatus("Allow Accessibility access to let Noodle nudge windows")
            return
        }
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            controls.setStatus("Bring another app forward, then try again")
            return
        }
        let app = AXUIElementCreateApplication(frontmost.processIdentifier)
        var rawWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &rawWindow)
        guard result == .success, let rawWindow else {
            controls.setStatus("That window cannot be nudged")
            return
        }
        let window = rawWindow as! AXUIElement
        var position = CGPoint(x: petWindow.frame.minX + 120, y: petWindow.frame.minY + 16)
        guard let value = AXValueCreate(.cgPoint, &position) else { return }
        let setResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        if setResult == .success {
            runTrick("Wave")
            controls.setStatus("Noodle tugged the front window")
        } else {
            controls.setStatus("That window did not allow Noodle to move it")
        }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
