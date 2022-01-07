//
//  AlertProtocol.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import UIKit

protocol AlertProtocol where Self: UIViewController {}

extension AlertProtocol {
    
    func popAlert(title: String,
                  message: String,
                  actionText: String? = nil,
                  cancelText:String? = nil,
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
    
    func dismissAlert(_ alert: UIAlertController, completion: (() -> Void)? = nil) {
        alert.dismiss(animated: true, completion: completion)
    }
    
}
