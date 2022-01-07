//
//  DisplayOrientationRotatable.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/7.
//

import UIKit

protocol DisplayOrientationRotatable {}

extension DisplayOrientationRotatable {
    
    
    /// Call to set UIDevice UIInterfaceOrientation.
    /// - Parameter orientation: The orientation you wish the device to be.
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

