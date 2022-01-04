//
//  UIViewController+Extension.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import UIKit

extension UIViewController: AlertProtocol {}
extension UIViewController: StoryboardID {}

protocol ReuseID {}
protocol StoryboardID: ReuseID {}

extension ReuseID {
    static var reuseIdentifier: String {
            String(describing: self)
    }
}

