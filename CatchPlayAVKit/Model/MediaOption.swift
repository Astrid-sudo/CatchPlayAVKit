//
//  MediaOption.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/5.
//

import AVFoundation

enum MediaOptionType {
    case audio
    case subtitle
    
    var avMediaCharacteristic: AVMediaCharacteristic {
        switch self {
        case .audio:
            return AVMediaCharacteristic.audible
        case .subtitle:
            return AVMediaCharacteristic.legible
        }
    }
}

struct MediaOption {
    var avMediaCharacteristicAudible: [DisplayNameLocale]
    var avMediaCharacteristicLegible: [DisplayNameLocale]
}

struct DisplayNameLocale {
    var displayName: String
    var locale: Locale?
}
