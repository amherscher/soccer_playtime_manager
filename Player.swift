import Foundation

struct Player: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var firstName: String
    var lastName: String?
    var number: Int?
    
    var secondsPlayed: Int
    var secondsOnBench: Int
    
    var isPlaying: Bool
    var positions: [Position]
    
    init(id: UUID = UUID(),
         firstName: String,
         lastName: String? = nil,
         number: Int? = nil,
         secondsPlayed: Int = 0,
         secondsOnBench: Int = 0,
         isPlaying: Bool = false,
         positions: [Position] = [.bench]) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.number = number
        self.secondsPlayed = secondsPlayed
        self.secondsOnBench = secondsOnBench
        self.isPlaying = isPlaying
        self.positions = positions
    }
    
    var currentPosition: Position { positions.last ?? .bench }
    
    func formattedTime() -> String {
        let m = secondsPlayed / 60
        let s = secondsPlayed % 60
        return String(format: "%02d:%02d", m, s)
    }
    func formattedBenchTime() -> String {
        let m = secondsOnBench / 60
        let s = secondsOnBench % 60
        return String(format: "%02d:%02d", m, s)
    }
}

enum Position: String, CaseIterable, Identifiable, Codable {
    case bench = "Bench"
    case goalkeeper = "Goalkeeper"
    case leftDefense = "L Defense"
    case rightDefense = "R Defense"
    case centerBack = "Center Back"
    case sweeper = "Sweeper"
    case stopper = "Stopper"
    case midfielder = "Midfielder"
    case leftMid = "L Mid"
    case rightMid = "R Mid"
    case centerMid = "Center Mid"
    case attackingMid = "Attacking Mid"
    case defensiveMid = "Defensive Mid"
    case leftWing = "L Wing"
    case rightWing = "R Wing"
    case striker = "Striker"
    case centerFullback = "Center Fullback"
    case offense = "Offense"
    case defense = "Defense"
    
    var id: String { rawValue }
    
    var short: String {
        switch self {
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
        }
    }
}


