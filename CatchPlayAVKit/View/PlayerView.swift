//
//  PlayerView.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

protocol PlayerViewDelegate: AnyObject {
    func showPlayerControl(from playerView: PlayerView)
}

enum PlayerState {
    case unknow
    case readyToPlay
    case playing
    case buffering
    case failed
    case pause
    case ended
}

import AVKit

/// A view that displays the visual contents of a player object.
class PlayerView: UIView {

    // Override the property to make AVPlayerLayer the view's backing layer.
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    
    // The associated player object.
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    weak var delegate: PlayerViewDelegate?
    
    var playerState: PlayerState = .unknow
    
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    
    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(showPlayerControl))
        return gesture
    }()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        addGestureRecognizer(tapGesture)
    }
    
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func showPlayerControl() {
        delegate?.showPlayerControl(from: self)
    }

}

