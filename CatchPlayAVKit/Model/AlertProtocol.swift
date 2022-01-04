//
//  AlertProtocol.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import UIKit

protocol AlertProtocol where Self: UIViewController {}

extension AlertProtocol {
    
    func popAlert(title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert )
        present(alert, animated: true, completion: nil)
        let okButton = UIAlertAction(title: Constant.ok, style: .cancel)
        alert.addAction(okButton)
        return alert
    }
    
    func dismissAlert(_ alert: UIAlertController, completion: (() -> Void)? = nil) {
        alert.dismiss(animated: true, completion: completion)
    }
    
}
