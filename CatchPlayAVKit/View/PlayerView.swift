//
//  PlayerView.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

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
    
    var playerState: PlayerState = .unknow
    
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    
}

