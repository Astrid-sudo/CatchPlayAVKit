//
//  TimeManager.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/7.
//

import Foundation

struct TimeManager {
    
    static func floatToTimecodeString(seconds: Float) -> String {
        guard !(seconds.isNaN || seconds.isInfinite) else {
            return "00:00"
        }
        let time = Int(ceil(seconds))
        let hours = time / 3600
        let minutes = time / 60
        let seconds = time % 60
        let timecodeString = hours == .zero ? String(format: "%02ld:%02ld", minutes, seconds) : String(format: "%02ld:%02ld:%02ld", hours, minutes, seconds)
        return timecodeString
    }

}
