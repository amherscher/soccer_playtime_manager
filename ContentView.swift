import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject var manager = GameManager()
    @Environment(\.scenePhase) private var scenePhase
    
    // Setup (was Edit)
    @State private var isEditing = false
    @State private var newFirstName = ""
    @State private var isModifyingPositions = false
    
    // Delete
    @State private var showDeletePicker = false
    @State private var playerToDelete: UUID? = nil
    
    // Rename
    @State private var showRenamePicker = false
    @State private var playerToRename: UUID? = nil
    @State private var renameFirst = ""
    @State private var renameLast = ""
    
    // Drag for reordering (Setup mode only)
    @State private var draggingID: UUID? = nil
    
    // Clock setup
    @State private var gameLengthInput = "0"
    
    // Grid sizing (adaptive) — roomier defaults for iPad
    private let cardMinWidth: CGFloat  = 110
    private let cardMinHeight: CGFloat = 200   // base height; card can still grow
    
    var body: some View {
        VStack(spacing: 12) {
            
            // ===================== TOP BAR =====================
            HStack(alignment: .top) {
                // LEFT: Setup + clock-length editor (in Setup or when clock is 0 & not running)
                VStack(alignment: .leading, spacing: 6) {
                    Button(isEditing ? "Save Setup" : "Setup") {
                        isEditing.toggle()
                        if isEditing {
                            manager.pauseGame()
                        } else {
                            // leaving Setup
                            isModifyingPositions = false
                            manager.saveState()
                            draggingID = nil
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    
                    if isEditing || (!manager.isGameRunning && manager.gameTimeRemaining == 0) {
                        ClockSetter(input: $gameLengthInput) { mins in
                            manager.gameDuration = mins * 60
                            manager.gameTimeRemaining = manager.gameDuration
                            manager.saveState()
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // CENTER: Clock + Start/Pause
                VStack(spacing: 6) {
                    Text(manager.formattedTime())
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                    Button(manager.isGameRunning ? "Pause Clock" : "Start Clock") {
                        guard !isEditing else { return } // block while in Setup
                        manager.isGameRunning ? manager.pauseGame() : manager.startGame()
                    }
                    .font(.title2)
                    .disabled(isEditing || (manager.gameTimeRemaining == 0 && manager.gameDuration == 0))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // RIGHT: Setup controls OR Swap Queue (mutually exclusive)
                VStack(alignment: .trailing, spacing: 6) {
                    if isEditing {
                        // === SETUP MODE: tools ===
                        Button("Reset Clock") {
                            manager.resetClockOnly()
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: { manager.resetPositions() }) {
                            Text("Reset\nPositions Played")
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        // Modify positions (Setup-only)
                        HStack(spacing: 8) {
                            Button(isModifyingPositions ? "Done Modifying" : "Modify Positions") {
                                isModifyingPositions.toggle()
                                manager.pauseGame()
                                manager.saveState()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Menu("Add Position") {
                                ForEach(Position.addableCommon.filter { !manager.activePositions.contains($0) }, id: \.self) { pos in
                                    Button(pos.rawValue) { manager.addPosition(pos) }
                                }
                            }
                            .disabled(!isModifyingPositions)
                            .font(.caption)
                            .controlSize(.small)
                        }
                    } else if manager.isGameRunning {
                        // === LIVE MODE: swap queue ===
                        SwapQueueView(items: manager.swapQueue, players: manager.players)
                        // NEW: Clear Queue (tiny text, zero new APIs)
                        Button("Clear Queue") {
                            manager.swapQueue.removeAll()
                            manager.saveState()
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                        .disabled(manager.swapQueue.isEmpty)

                        Button("Swap Players") {
                            manager.applySwapQueue()
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(8)
                        .padding(.top, 4)
                        
                        
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)
            // =================== END TOP BAR ===================
            
            // ===================== SETUP PANEL =====================
            if isEditing {
                VStack(spacing: 10) {
                    // Add Player
                    HStack {
                        TextField("First Name", text: $newFirstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 220, alignment: .leading)
                        
                        Button("Add Player") {
                            guard !newFirstName.isEmpty else { return }
                            manager.players.append(Player(firstName: newFirstName))
                            manager.saveState()
                            newFirstName = ""
                        }
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal)
                    
                    // Delete Player
                    VStack(spacing: 6) {
                        Button("Delete Player") {
                            if playerToDelete == nil { playerToDelete = manager.players.first?.id }
                            showDeletePicker.toggle()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        if showDeletePicker {
                            Picker("Select Player to Delete", selection: Binding(
                                get: { playerToDelete ?? manager.players.first?.id ?? UUID() },
                                set: { playerToDelete = $0 }
                            )) {
                                ForEach(manager.players) { player in
                                    Text(displayName(for: player)).tag(player.id)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Button("Confirm Delete") {
                                guard let id = playerToDelete,
                                      let index = manager.players.firstIndex(where: { $0.id == id }) else { return }
                                manager.players.remove(at: index)
                                manager.saveState()
                                playerToDelete = nil
                                showDeletePicker = false
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    // Rename Player
                    VStack(spacing: 6) {
                        Button("Rename Player") {
                            if playerToRename == nil { playerToRename = manager.players.first?.id }
                            if let id = playerToRename,
                               let p = manager.players.first(where: { $0.id == id }) {
                                renameFirst = p.firstName
                                renameLast = p.lastName ?? ""
                            }
                            showRenamePicker.toggle()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        if showRenamePicker {
                            Picker("Select Player to Rename", selection: Binding(
                                get: { playerToRename ?? manager.players.first?.id ?? UUID() },
                                set: { newID in
                                    playerToRename = newID
                                    if let p = manager.players.first(where: { $0.id == newID }) {
                                        renameFirst = p.firstName
                                        renameLast = p.lastName ?? ""
                                    }
                                }
                            )) {
                                ForEach(manager.players) { player in
                                    Text(displayName(for: player)).tag(player.id)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            HStack(spacing: 8) {
                                TextField("New First Name", text: $renameFirst)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("New Last Name (optional)", text: $renameLast)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .frame(maxWidth: 420)
                            
                            Button("Confirm Rename") {
                                guard let id = playerToRename,
                                      let idx = manager.players.firstIndex(where: { $0.id == id }),
                                      !renameFirst.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                manager.players[idx].firstName = renameFirst.trimmingCharacters(in: .whitespaces)
                                let trimmedLast = renameLast.trimmingCharacters(in: .whitespaces)
                                manager.players[idx].lastName = trimmedLast.isEmpty ? nil : trimmedLast
                                manager.saveState()
                                showRenamePicker = false
                                playerToRename = nil
                                renameFirst = ""
                                renameLast = ""
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            // =================== END SETUP PANEL ===================
            
            // Field with live markers (editable only in Setup when modifying)
            SoccerFieldView(
                players: manager.players,
                isModifying: isEditing && isModifyingPositions,
                activePositions: $manager.activePositions,
                layout: $manager.fieldLayout,
                onMove: { pos, normPoint in
                    manager.movePosition(pos, to: normPoint)
                },
                onDelete: { pos in
                    manager.removePosition(pos)
                }
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // ===================== PLAYERS GRID (adaptive) =====================
            GeometryReader { geo in
                let spacing: CGFloat = 12
                let horizontalPadding: CGFloat = 16
                let usableWidth = max(0, geo.size.width - horizontalPadding * 2)
                let columnsCount = max(1, Int((usableWidth + spacing) / (cardMinWidth + spacing)))
                let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnsCount)
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(manager.players) { player in
                            PlayerCardView(
                                player: player,
                                isEditing: isEditing,
                                pickerPositions: manager.pickerPositions,
                                onQueueOrSet: { id, newPos, isRunning in
                                    if isRunning {
                                        manager.queueSwap(for: id, to: newPos)
                                    } else {
                                        manager.setPosition(for: id, to: newPos)
                                    }
                                },
                                isGameRunning: manager.isGameRunning
                            )
                            .frame(minWidth: cardMinWidth, minHeight: cardMinHeight) // base size; can grow
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(draggingID == player.id ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 3)
                            )
                            .cornerRadius(10)
                            .opacity(draggingID == player.id ? 0.5 : 1.0)
                            .contentShape(Rectangle())
                            .modifier(ReorderableModifier(
                                enabled: isEditing,
                                player: player,
                                players: $manager.players,
                                draggingID: $draggingID
                            ))
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 8)
        .onChange(of: manager.players) { _, _ in
            manager.saveState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                manager.prepareForBackground()
            case .active:
                manager.resumeFromBackground()
            @unknown default:
                break
            }
        }
        .onChange(of: manager.isGameRunning) { _, running in
#if canImport(UIKit)
            // Keep screen awake while running
            UIApplication.shared.isIdleTimerDisabled = running
#endif
        }
    }
    
    // MARK: - Helpers
    private func displayName(for player: Player) -> String {
        if let last = player.lastName, !last.isEmpty {
            return "\(player.firstName) \(last)"
        }
        return player.firstName
    }
}

// ==================== Player Card (extracted) ====================

private struct PlayerCardView: View {
    let player: Player
    let isEditing: Bool
    let pickerPositions: [Position]
    let onQueueOrSet: (_ playerID: UUID, _ newPos: Position, _ isGameRunning: Bool) -> Void
    let isGameRunning: Bool
    
    var body: some View {
        let positionsPlayed = player.positions.filter { $0 != .bench }
        
        VStack(alignment: .leading, spacing: 8) {
            // Centered name
            Text("\(player.firstName) \(player.lastName ?? "")")
                .font(.headline)
                .foregroundColor(player.isPlaying ? .blue : .red)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            
            Text("Play: \(player.formattedTime())")
                .font(.subheadline)
                .foregroundColor(player.isPlaying ? .yellow : .gray)
            
            Text("Bench: \(player.formattedBenchTime())")
                .font(.caption2)
                .foregroundColor(player.isPlaying ? .gray : .yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Positions:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if positionsPlayed.isEmpty {
                    Text("—")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text(positionsPlayed.map { $0.short }.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Picker("", selection: .init(
                get: { player.currentPosition },
                set: { newPos in
                    guard !isEditing else { return }
                    onQueueOrSet(player.id, newPos, isGameRunning)
                }
            )) {
                Group {
                    Text(Position.bench.rawValue).tag(Position.bench)
                    ForEach(pickerPositions, id: \.self) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }
            }
            .pickerStyle(MenuPickerStyle())
            .disabled(isEditing)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// ==================== Reorder support (unchanged) ====================

private struct ReorderableModifier: ViewModifier {
    let enabled: Bool
    let player: Player
    @Binding var players: [Player]
    @Binding var draggingID: UUID?
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    draggingID = player.id
                    return NSItemProvider(object: player.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: ReorderDropDelegate(
                    current: player,
                    players: $players,
                    draggingID: $draggingID
                ))
        } else {
            content
        }
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let current: Player
    @Binding var players: [Player]
    @Binding var draggingID: UUID?
    
    func validateDrop(info: DropInfo) -> Bool { true }
    
    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != current.id,
              let from = players.firstIndex(where: { $0.id == draggingID }),
              let to = players.firstIndex(where: { $0.id == current.id }) else { return }
        withAnimation(.easeInOut(duration: 0.12)) {
            let item = players.remove(at: from)
            players.insert(item, at: to)
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// ==================== Field view ====================

struct SoccerFieldView: View {
    let players: [Player]
    
    // Editing hooks
    let isModifying: Bool
    @Binding var activePositions: Set<Position>
    @Binding var layout: [Position: CGPoint]
    var onMove: (Position, CGPoint) -> Void
    var onDelete: (Position) -> Void
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(Color.green.opacity(0.45))
                    .overlay(fieldLines(in: geo.size).stroke(Color.white, lineWidth: 2))
                    .cornerRadius(12)
                
                // Position labels (based on activePositions only)
                ForEach(Array(activePositions), id: \.self) { pos in
                    let pt = point(for: pos, in: geo.size)
                    if isModifying {
                        EditableTag(text: shortLabel(for: pos))
                            .position(pt)
                            .gesture(dragGesture(for: pos, in: geo.size))
                            .onTapGesture { onDelete(pos) } // delete on tap while modifying
                    } else {
                        FieldTag(text: shortLabel(for: pos))
                            .position(x: pt.x, y: pt.y - 16)
                            .zIndex(1)
                    }
                }
                
                // Player badges (respecting active positions only)
                let grouped: [Position: [Player]] = Dictionary(grouping: players) { $0.currentPosition }
                ForEach(Array(activePositions), id: \.self) { pos in
                    let playersAtPos = grouped[pos] ?? []
                    ForEach(Array(playersAtPos.enumerated()), id: \.element.id) { (i, p) in
                        let base = point(for: pos, in: geo.size)
                        let offset = fanOffset(index: i)
                        PlayerBadge(name: p.firstName, color: .blue, size: 28)
                            .position(x: base.x + offset.width, y: base.y + offset.height)
                    }
                }
                
                // Bench badges
                let benchPlayers = players.filter { $0.currentPosition == .bench }
                ForEach(Array(benchPlayers.enumerated()), id: \.element.id) { (i, p) in
                    let pt = anchor(for: .bench, in: geo.size, benchIndex: i, benchCount: benchPlayers.count)
                    PlayerBadge(name: p.firstName, color: .red, size: 24).position(pt)
                }
            }
        }
        .aspectRatio(3/2, contentMode: .fit)
    }
    
    // MARK: - Helpers (inside SoccerFieldView)
    private func shortLabel(for pos: Position) -> String {
        switch pos {
        case .goalkeeper:        return "GK"
        case .leftDefense:       return "L DEF"
        case .rightDefense:      return "R DEF"
        case .centerBack:        return "CB"
        case .sweeper:           return "SWP"
        case .stopper:           return "STP"
        case .midfielder:        return "MID"
        case .leftMid:           return "L MID"
        case .rightMid:          return "R MID"
        case .centerMid:         return "C MID"
        case .attackingMid:      return "ATT MID"
        case .defensiveMid:      return "DEF MID"
        case .leftWing:          return "L WING"
        case .rightWing:         return "R WING"
        case .striker:           return "ST"
        case .centerFullback:    return "CFB"
        case .offense:           return "OFF"
        case .defense:           return "DEF"
        case .bench:             return "BENCH"
        default:
            return pos.rawValue.uppercased()
        }
    }
    
    private func point(for pos: Position, in size: CGSize) -> CGPoint {
        if let norm = layout[pos] {
            return CGPoint(x: norm.x * size.width, y: norm.y * size.height)
        }
        return anchor(for: pos, in: size)
    }
    
    private func dragGesture(for pos: Position, in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let nx = max(0.04, min((value.location.x / size.width), 0.96))
                let ny = max(0.06, min((value.location.y / size.height), 0.94))
                layout[pos] = CGPoint(x: nx, y: ny)
            }
            .onEnded { _ in
                if let p = layout[pos] { onMove(pos, p) }
            }
    }
}

// Editable tag (bigger hit target while modifying)
private struct EditableTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.sRGB, red: 0.02, green: 0.32, blue: 0.08, opacity: 0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(radius: 1, y: 1)
    }
}

// ---- helpers for field drawing (global, OK) ----
private func centerOutMultiplier(_ i: Int) -> Int { i == 0 ? 0 : (i % 2 == 0 ? (i/2) : -(i/2 + 1)) }
private func fanOffset(index: Int) -> CGSize { let step: CGFloat = 12; let pattern = [0,-1,1,-2,2,-3,3]; let r = index < pattern.count ? pattern[index] : 0; return CGSize(width: CGFloat(r)*step, height: 0) }
private func anchor(for pos: Position, in size: CGSize, benchIndex: Int = 0, benchCount: Int = 0) -> CGPoint {
    let w = size.width, h = size.height
    let anchors: [Position: CGPoint] = [
        .goalkeeper:   .init(x: 0.08*w, y: 0.50*h),
        .leftDefense:  .init(x: 0.22*w, y: 0.28*h),
        .rightDefense: .init(x: 0.22*w, y: 0.72*h),
        .midfielder:   .init(x: 0.50*w, y: 0.50*h),
        .leftWing:     .init(x: 0.78*w, y: 0.28*h),
        .rightWing:    .init(x: 0.78*w, y: 0.72*h),
        .striker:      .init(x: 0.90*w, y: 0.50*h),
        .bench:        .init(x: 0.25*w, y: 0.95*h)
    ]
    if pos == .bench {
        let centerX = 0.50*w, y = 0.95*h, maxSpan = 0.80*w
        let spacing: CGFloat = (benchCount <= 1) ? 0 : min(0.11*w, maxSpan/CGFloat(benchCount-1))
        let m = centerOutMultiplier(benchIndex)
        return .init(x: centerX + CGFloat(m)*spacing, y: y)
    }
    return anchors[pos] ?? .init(x: 0.5*w, y: 0.5*h)
}
private func fieldLines(in size: CGSize) -> Path {
    let w = size.width, h = size.height
    let boxDepth = 0.18*w, boxHeight = 0.60*h, smallDepth = 0.06*w, smallHeight = 0.30*h, centerR = 0.10*h
    var p = Path()
    p.addRoundedRect(in: CGRect(x: 4, y: 4, width: w-8, height: h-8), cornerSize: CGSize(width: 10, height: 10))
    p.move(to: CGPoint(x: w/2, y: 4)); p.addLine(to: CGPoint(x: w/2, y: h-4))
    p.addEllipse(in: CGRect(x: (w-2*centerR)/2, y: (h-2*centerR)/2, width: 2*centerR, height: 2*centerR))
    p.addRect(CGRect(x: 4, y: (h-boxHeight)/2, width: boxDepth, height: boxHeight))
    p.addRect(CGRect(x: 4, y: (h-smallHeight)/2, width: smallDepth, height: smallHeight))
    p.addRect(CGRect(x: 4-0.02*w, y: (h-0.20*h)/2, width: 0.02*w, height: 0.20*h))
    p.addRect(CGRect(x: w-4-boxDepth, y: (h-boxHeight)/2, width: boxDepth, height: boxHeight))
    p.addRect(CGRect(x: w-4-smallDepth, y: (h-smallHeight)/2, width: smallDepth, height: smallHeight))
    p.addRect(CGRect(x: w-4, y: (h-0.20*h)/2, width: 0.02*w, height: 0.20*h))
    return p
}
struct PlayerBadge: View { let name: String; let color: Color; let size: CGFloat
    var body: some View {
        Text(name).font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.85)).cornerRadius(6).shadow(radius: 2, x: 0, y: 1)
    }
}
private struct FieldTag: View { let text: String
    var body: some View {
        Text(text).font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(.sRGB, red: 0.02, green: 0.32, blue: 0.08, opacity: 0.92)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.6), lineWidth: 1))
            .shadow(radius: 1, y: 1)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDisplayName("Soccer Player Timer")
    }
}

// ==================== Small subviews ====================

private struct ClockSetter: View {
    @Binding var input: String
    let onSet: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("min", text: $input)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 56)
                .multilineTextAlignment(.trailing)
                .onChange(of: input) { newValue in
                    var filtered = newValue.filter(\.isNumber)
                    if filtered.count > 3 { filtered = String(filtered.prefix(3)) }
                    input = filtered
                }
            
            Button("Set Clock") {
                if let mins = Int(input), mins > 0 {
                    onSet(mins)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct SwapQueueView: View {
    let items: [GameManager.QueuedSwap]
    let players: [Player]
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Swap Queue:")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if items.isEmpty {
                Text("—")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(items) { item in
                    if let p = players.first(where: { $0.id == item.playerID }) {
                        let fromLabel = item.from?.rawValue ?? "—"
                        Text("\(p.firstName): \(fromLabel) → \(item.target.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
