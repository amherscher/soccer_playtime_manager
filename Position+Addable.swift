// Position+Addable.swift
import Foundation

extension Position {
    /// Positions you can add as field tags (Bench is implicit and excluded)
    static let addableCommon: [Position] = [
        .goalkeeper,
        .leftDefense, .rightDefense,
        .centerBack, .sweeper, .stopper,
        
            .midfielder, .leftMid, .rightMid, .centerMid, .attackingMid, .defensiveMid,
        
            .leftWing, .rightWing,
        .striker,
        .centerFullback,
        
        // general groups you added
        .offense, .defense
    ]
}
