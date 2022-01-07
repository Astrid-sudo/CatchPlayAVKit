//
//  LaunchPageViewController.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/5.
//

import AVKit

class LaunchPageViewController: UIViewController {
    
    // MARK: - UI Properties
    
    private lazy var button: UIButton = {
        let button = UIButton()
        button.setTitle(Constant.play, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(playVideo), for: .touchUpInside)
        return button
    }()
    
    // MARK: - life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setViewBackgroundcolor()
        setButton()
    }
    
    // MARK: - UI method

    private func setViewBackgroundcolor() {
        view.backgroundColor = .black
    }
    
    private func setButton() {
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - method
    
    @objc private func playVideo() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let customPlayerViewController = storyboard.instantiateViewController(withIdentifier: CustomPlayerViewController.reuseIdentifier) as? CustomPlayerViewController else { return }
        rotateDisplay(to: .landscape)
        present(customPlayerViewController, animated: true, completion: nil)
    }
    
}


