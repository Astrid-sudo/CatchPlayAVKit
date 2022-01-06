//
//  UIViewController+Extension.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import UIKit

extension UIViewController: AlertProtocol {}
extension UIViewController: StoryboardID {}
extension UIViewController: DisplayOrientationProtocol {}

protocol StoryboardID: ReuseID {}

protocol ReuseID {}
extension ReuseID {
    static var reuseIdentifier: String {
            String(describing: self)
    }
}

protocol DisplayOrientationProtocol {}
extension DisplayOrientationProtocol {
    
    func rotateDisplay(to orientation: UIInterfaceOrientationMask) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.orientation = orientation
            
            if orientation != .portrait {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: Constant.orientation)
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: Constant.orientation)
            }
        }
    }
}


