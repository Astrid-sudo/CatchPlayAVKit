//
//  AlertPresentable.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import UIKit

protocol AlertPresentable where Self: UIViewController {}

extension AlertPresentable {
    
    
    /// Present alert.
    /// - Parameters:
    ///   - title: The title of this UIAlertController
    ///   - message: The message of this UIAlertController
    ///   - actionText: The text on alert's left button.
    ///   - cancelText: The text on alert's right button.
    ///   - actionCompletion: The closure will be executed when action button tapped.
    /// - Returns: The presented UIAlertController.
    func popAlert(title: String,
                  message: String,
                  actionText: String? = nil,
                  cancelText: String? = nil,
                  actionCompletion:(()->Void)? = nil) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert )
        
        if let actionText = actionText {
            let actionButton = UIAlertAction(title: actionText, style: .default)
            alert.addAction(actionButton)
        }
        
        if let cancelText = cancelText {
            let cancelButton = UIAlertAction(title: cancelText, style: .cancel)
            alert.addAction(cancelButton)
        }
        
        present(alert, animated: true, completion: actionCompletion)

        return alert
    }
    
    
    /// Dissmiss the alert passed in.
    /// - Parameters:
    ///   - alert: The UIAlertController will be dismissed.
    ///   - completion: The closure will be executed after dismiss UIAlertController.
    func dismissAlert(_ alert: UIAlertController, completion: (() -> Void)? = nil) {
        alert.dismiss(animated: true, completion: completion)
    }
    
}
