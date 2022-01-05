//
//  MediaOption.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/5.
//

import Foundation

struct MediaOption {
    var aVMediaCharacteristicAudible: [DisplayNameLocale]
    var aVMediaCharacteristicLegible: [DisplayNameLocale]
}

struct DisplayNameLocale {
    var displayName: String
    var locale: Locale?
}
