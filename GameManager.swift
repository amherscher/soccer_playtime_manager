import Foundation
import CoreGraphics

@MainActor
class GameManager: ObservableObject {
    // MARK: - Public state
    @Published var players: [Player] = []
    @Published var gameTimeRemaining: Int = 0       // seconds
    @Published var isGameRunning: Bool = false
    @Published var gameDuration: Int = 2400         // default = 40 min
    
    // Swap Queue
    struct QueuedSwap: Identifiable, Codable, Hashable {
        let id: UUID
        let playerID: UUID
        let target: Position
        let from: Position? // where they were when queued (optional for back-compat)
        
        init(id: UUID = UUID(), playerID: UUID, target: Position, from: Position? = nil) {
            self.id = id
            self.playerID = playerID
            self.target = target
            self.from = from
        }
    }
    @Published var swapQueue: [QueuedSwap] = []
    
    // Editable field positions
    @Published var activePositions: Set<Position> = [
        .goalkeeper, .leftDefense, .rightDefense, .midfielder, .leftWing, .rightWing, .striker
    ]
    
    // Layout: normalized coordinates (0...1) per position (bench handled separately)
    @Published var fieldLayout: [Position: CGPoint] = [
        .goalkeeper:   CGPoint(x: 0.08, y: 0.50),
        .leftDefense:  CGPoint(x: 0.22, y: 0.28),
        .rightDefense: CGPoint(x: 0.22, y: 0.72),
        .midfielder:   CGPoint(x: 0.50, y: 0.50),
        .leftWing:     CGPoint(x: 0.78, y: 0.28),
        .rightWing:    CGPoint(x: 0.78, y: 0.72),
        .striker:      CGPoint(x: 0.90, y: 0.50),
    ]
    
    // Derived list for pickers (Bench is added in the UI)
    var pickerPositions: [Position] {
        Array(activePositions).sorted { $0.rawValue < $1.rawValue }
    }
    
    // MARK: - Private
    private var timer: Timer?
    private var lastBackgroundDate: Date?   // ← remember when we went to background
    
    // Persistence keys
    private let playersKey         = "players.codable.v2"
    private let gameDurationKey    = "gameDuration"
    private let legacyNamesKey     = "playerNames"
    private let swapQueueKey       = "swapQueue.codable.v1"
    private let activePositionsKey = "activePositions.v1"
    private let fieldLayoutKey     = "fieldLayout.v1"
    
    // MARK: - Init
    init() {
        loadState()
    }
    
    // MARK: - Game Control
    func startGame() {
        if gameTimeRemaining == 0 { gameTimeRemaining = gameDuration }
        isGameRunning = true
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.gameTimeRemaining > 0 {
                    self.gameTimeRemaining -= 1
                    var updated = self.players
                    for i in updated.indices {
                        if updated[i].isPlaying {
                            updated[i].secondsPlayed += 1
                        } else {
                            updated[i].secondsOnBench += 1
                        }
                    }
                    self.players = updated
                } else {
                    self.stopGame()
                }
            }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }
    
    func pauseGame() {
        isGameRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func stopGame() {
        pauseGame()
    }
    
    func resetGame() {
        pauseGame()
        gameTimeRemaining = gameDuration
        var updated = players
        for i in updated.indices {
            updated[i].secondsPlayed = 0
            updated[i].secondsOnBench = 0
            updated[i].isPlaying = false
            updated[i].positions = [.bench]
        }
        players = updated
        swapQueue.removeAll()
        saveState()
    }
    
    /// Only reset the clock + per-player timers (leave positions untouched)
    func resetClockOnly() {
        pauseGame()
        gameTimeRemaining = gameDuration
        
        var updated = players
        for i in updated.indices {
            updated[i].secondsPlayed = 0
            updated[i].secondsOnBench = 0
            // leave `isPlaying` and `positions` unchanged
        }
        players = updated
        
        saveState()
    }
    
    // MARK: - Background handling (catch up after standby)
    /// Call this when the scene is moving to inactive/background.
    func prepareForBackground() {
        lastBackgroundDate = Date()
    }
    
    /// Call this when the scene becomes active again.
    func resumeFromBackground() {
        guard let last = lastBackgroundDate else { return }
        lastBackgroundDate = nil
        let delta = Int(Date().timeIntervalSince(last))
        guard delta > 0 else { return }
        advanceClockAndStats(by: delta)
    }
    
    /// Fast-forward the game clock and player stats by `seconds`.
    private func advanceClockAndStats(by seconds: Int) {
        guard seconds > 0 else { return }
        let applied = min(seconds, gameTimeRemaining)
        guard applied > 0 else { return }
        
        var updated = players
        for i in updated.indices {
            if updated[i].isPlaying {
                updated[i].secondsPlayed += applied
            } else {
                updated[i].secondsOnBench += applied
            }
        }
        players = updated
        
        gameTimeRemaining = max(0, gameTimeRemaining - applied)
        
        if gameTimeRemaining == 0 {
            stopGame()
        } else if isGameRunning && timer == nil {
            // If we were "running" when backgrounded, resume ticking.
            startGame()
        }
        saveState()
    }
    
    // MARK: - Position Management (players)
    func setPosition(for playerID: UUID, to position: Position) {
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else { return }
        guard position == .bench || activePositions.contains(position) else { return }
        
        var updated = players
        
        if position == .bench {
            if updated[idx].currentPosition != .bench {
                updated[idx].positions.append(.bench)
            }
            updated[idx].isPlaying = false
            players = updated
            saveState()
            return
        }
        
        for i in updated.indices where updated[i].id != playerID && updated[i].currentPosition == position {
            if updated[i].currentPosition != .bench {
                updated[i].positions.append(.bench)
            }
            updated[i].isPlaying = false
        }
        
        if updated[idx].currentPosition != position {
            updated[idx].positions.append(position)
        }
        updated[idx].isPlaying = true
        
        players = updated
        saveState()
    }
    
    func queueSwap(for playerID: UUID, to position: Position) {
        guard isGameRunning,
              let idx = players.firstIndex(where: { $0.id == playerID }) else { return }
        guard position == .bench || activePositions.contains(position) else { return }
        
        let current = players[idx].currentPosition
        guard position != current else { return }
        guard !(current == .bench && position == .bench) else { return }
        
        let item = QueuedSwap(playerID: playerID, target: position, from: current)
        if let qIdx = swapQueue.firstIndex(where: { $0.playerID == playerID }) {
            swapQueue[qIdx] = item
        } else {
            swapQueue.append(item)
        }
        saveState()
    }
    
    func applySwapQueue() {
        guard isGameRunning, !swapQueue.isEmpty else { return }
        var updated = players
        
        for item in swapQueue {
            guard item.target == .bench || activePositions.contains(item.target) else { continue }
            for i in updated.indices where updated[i].currentPosition == item.target && updated[i].id != item.playerID {
                if updated[i].currentPosition != .bench {
                    updated[i].positions.append(.bench)
                }
                updated[i].isPlaying = false
            }
        }
        
        for item in swapQueue {
            guard let pIdx = updated.firstIndex(where: { $0.id == item.playerID }) else { continue }
            guard item.target == .bench || activePositions.contains(item.target) else { continue }
            
            if updated[pIdx].currentPosition != item.target {
                updated[pIdx].positions.append(item.target)
            }
            updated[pIdx].isPlaying = (item.target != .bench)
        }
        
        players = updated
        swapQueue.removeAll()
        saveState()
    }
    
    func resetPositions() {
        pauseGame()
        var updated = players
        for i in updated.indices {
            updated[i].isPlaying = false
            updated[i].positions = [.bench]
        }
        players = updated
        swapQueue.removeAll()
        saveState()
    }
    
    // MARK: - Position Management (field tags)
    func addPosition(_ pos: Position) {
        guard pos != .bench else { return }
        activePositions.insert(pos)
        if fieldLayout[pos] == nil {
            fieldLayout[pos] = CGPoint(x: 0.55, y: 0.50) // default drop near center
        }
        saveState()
    }
    
    func removePosition(_ pos: Position) {
        guard pos != .bench else { return }
        activePositions.remove(pos)
        fieldLayout.removeValue(forKey: pos)
        
        var updated = players
        for i in updated.indices where updated[i].currentPosition == pos {
            if updated[i].currentPosition != .bench {
                updated[i].positions.append(.bench)
            }
            updated[i].isPlaying = false
        }
        players = updated
        
        swapQueue.removeAll { $0.target == pos }
        saveState()
    }
    
    func movePosition(_ pos: Position, to normalizedPoint: CGPoint) {
        guard pos != .bench else { return }
        let nx = max(0.02, min(normalizedPoint.x, 0.98))
        let ny = max(0.04, min(normalizedPoint.y, 0.96))
        fieldLayout[pos] = CGPoint(x: nx, y: ny)
    }
    
    // MARK: - Time Formatting
    func formattedTime() -> String {
        let minutes = gameTimeRemaining / 60
        let seconds = gameTimeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Persistence
    func saveState() {
        if let data = try? JSONEncoder().encode(players) {
            UserDefaults.standard.set(data, forKey: playersKey)
        } else {
            let names = players.map { $0.firstName }
            UserDefaults.standard.set(names, forKey: legacyNamesKey)
        }
        UserDefaults.standard.set(gameDuration, forKey: gameDurationKey)
        
        if let q = try? JSONEncoder().encode(swapQueue) {
            UserDefaults.standard.set(q, forKey: swapQueueKey)
        }
        
        if let ap = try? JSONEncoder().encode(Array(activePositions)) {
            UserDefaults.standard.set(ap, forKey: activePositionsKey)
        }
        
        let layoutPayload = fieldLayout.reduce(into: [String: [CGFloat]]()) { dict, kv in
            dict[kv.key.rawValue] = [kv.value.x, kv.value.y]
        }
        if let fl = try? JSONEncoder().encode(layoutPayload) {
            UserDefaults.standard.set(fl, forKey: fieldLayoutKey)
        }
    }
    
    func loadState() {
        if let data = UserDefaults.standard.data(forKey: playersKey),
           let decoded = try? JSONDecoder().decode([Player].self, from: data) {
            players = decoded
        } else if let legacy = UserDefaults.standard.array(forKey: legacyNamesKey) as? [String] {
            players = legacy.map { Player(firstName: $0) }
            saveState()
        }
        
        if let savedDuration = UserDefaults.standard.value(forKey: gameDurationKey) as? Int {
            gameDuration = savedDuration
        }
        
        if let qData = UserDefaults.standard.data(forKey: swapQueueKey),
           let qDecoded = try? JSONDecoder().decode([QueuedSwap].self, from: qData) {
            swapQueue = qDecoded
        }
        
        if let apData = UserDefaults.standard.data(forKey: activePositionsKey),
           let decoded = try? JSONDecoder().decode([Position].self, from: apData) {
            activePositions = Set(decoded)
        }
        
        if let flData = UserDefaults.standard.data(forKey: fieldLayoutKey),
           let raw = try? JSONDecoder().decode([String: [CGFloat]].self, from: flData) {
            var rebuilt: [Position: CGPoint] = [:]
            for (k, arr) in raw {
                if let pos = Position(rawValue: k), arr.count == 2 {
                    rebuilt[pos] = CGPoint(x: arr[0], y: arr[1])
                }
            }
            if !rebuilt.isEmpty { fieldLayout = rebuilt }
        }
        
        if gameTimeRemaining == 0 { gameTimeRemaining = gameDuration }
        
        // Safety: bench any players who are at positions that are no longer active
        if !activePositions.isEmpty {
            var updated = players
            var touched = false
            for i in updated.indices {
                let pos = updated[i].currentPosition
                if pos != .bench && !activePositions.contains(pos) {
                    updated[i].positions.append(.bench)
                    updated[i].isPlaying = false
                    touched = true
                }
            }
            if touched {
                players = updated
                saveState()
            }
        }
    }
}
