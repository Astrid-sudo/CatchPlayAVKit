//
//  ReuseID.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/7.
//

import Foundation

protocol ReuseID {}

extension ReuseID {
    static var reuseIdentifier: String {
        String(describing: self)
    }
}
