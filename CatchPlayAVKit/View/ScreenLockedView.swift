//
//  ScreenLockedView.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/5.
//

import UIKit

protocol ScreenLockedViewDelegate: AnyObject {
    func handleTapGesture(from screenLockedView: ScreenLockedView)
    func unlockScreen(from screenLockedView: ScreenLockedView)
}

class ScreenLockedView: UIView {
    
    // MARK: - properties
    
    weak var delegate: ScreenLockedViewDelegate?

    // MARK: - UI properties
    
    private lazy var unlockButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 40)
        let bigImage = UIImage(systemName: Constant.lockCircleFill, withConfiguration: config)
        button.setImage(bigImage, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(unlock), for: .touchUpInside)
        return button
    }()
    
    private lazy var screenLockLabel: UILabel = {
        let label = UILabel()
        label.text = Constant.screenLocked
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 22.0)
        return label
    }()
    
    private lazy var unlockHintLabel: UILabel = {
        let label = UILabel()
        label.text = Constant.tapLockerToUnlock
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12.0)
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.distribution = .fillProportionally
        return stackView
    }()

    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        return gesture
    }()
    
    // MARK: - init

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        setStackView()
        addGestureRecognizer(tapGesture)
    }
    
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - action

    @objc func unlock() {
        delegate?.unlockScreen(from: self)
    }
    
    @objc func tapAction() {
        delegate?.handleTapGesture(from: self)
    }
    
    // MARK: - method for customPlayerViewController
    
    func uiPropertiesAlpha(_ alpha: CGFloat ) {
        stackView.alpha = alpha
    }
    
    func uiPropertiesIsHidden(isHidden: Bool) {
        stackView.isHidden = isHidden
    }
    
    // MARK: - UI method
    
    private func setStackView() {
//        stackView.isHidden = true
        stackView.alpha = 0
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
        stackView.addArrangedSubview(unlockButton)
        stackView.addArrangedSubview(screenLockLabel)
        stackView.addArrangedSubview(unlockHintLabel)
    }
    
}
