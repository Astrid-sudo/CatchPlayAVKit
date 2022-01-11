//
//  CustomPlayerViewController.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import UIKit

class CustomPlayerViewController: UIViewController {
    
    // MARK: - properties
    
    private(set) lazy var networkManager: NetworkManager = {
        return NetworkManager()
    }()
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    private var autoHideTimer: BufferTimer?
    
    private var audioSlectedIndex: Int?
    private var subTitleSlectedIndex: Int?
    
    private lazy var customPlayerViewModel: CustomPlayerViewModel = {
        return CustomPlayerViewModel()
    }()
    
    // MARK: - UI properties
    
    private lazy var playerView: PlayerView = {
        let playerView = PlayerView()
        playerView.delegate = self
        playerView.player = customPlayerViewModel.videoPlayHelper.queuePlayer
        return playerView
    }()
    
    private lazy var playerControlView: PlayerControlView = {
        let playerControlView = PlayerControlView()
        playerControlView.delegate = self
        return playerControlView
    }()
    
    private lazy var screenLockedView: ScreenLockedView = {
        let screenLockedView = ScreenLockedView()
        screenLockedView.delegate = self
        return screenLockedView
    }()
    
    var noNetworkAlert: UIAlertController?
    
    // MARK: - life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setPlayerView()
        setPlayerControlView()
        checkNetwork(connectionHandler: connectionHandler,
                     noConnectionHandler: noConnectionHandler)
        observeScreenBrightness()
        binding()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - view model binding
    
    private func binding() {
        customPlayerViewModel.currentTime.bind { [weak self] timeString in
            guard let self = self else { return }
            self.playerControlView.setCurrentTimeLabel(timeString)
        }
        
        customPlayerViewModel.duration.bind { [weak self] duration in
            guard let self = self else { return }
            self.playerControlView.setDurationLabel(duration)
        }
        
        customPlayerViewModel.playProgress.bind { [weak self] progress in
            guard let self = self else { return }
            self.playerControlView.setProgressSliderValue(progress)
        }
        
        customPlayerViewModel.playSpeedRate.bind { [weak self] playSpeedRate in
            guard let self = self else { return }
            self.setControlViewSpeedButton(playSpeedRate:playSpeedRate)
        }
        
        customPlayerViewModel.playButtonType.bind { [weak self] buttonType in
            guard let self = self else { return }
            self.playerControlView.togglePlayButtonImage(buttonType)
        }
        
        customPlayerViewModel.showIndicator.bind { [weak self] bool in
            guard let self = self else { return }
            if bool {
                self.playerControlView.showIdicatorView()
            } else {
                self.playerControlView.removeIndicatorView()
            }
        }
        
        customPlayerViewModel.autoHidePlayerControl.bind { [weak self] bool in
            guard let self = self else { return }
            if bool {
                self.autoHidePlayerControl()
            } else {
                self.cancelAutoHidePlayerControl()
            }
        }
        
        customPlayerViewModel.playBackEnd.bind { [weak self] bool in
            guard let self = self else { return }
            if bool {
                self.presentedViewController?.dismiss(animated: true, completion: nil)
                self.subTitleSlectedIndex = nil
                self.audioSlectedIndex = nil
            }
        }
        
        customPlayerViewModel.isTheLastItem.bind {[weak self] bool in
            if bool {
                guard let self = self else { return }
                self.rotateDisplay(to: .portrait)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    // MARK: - update UI method
    
    /// Hide player control.
    /// - Parameter animateDuration: The duration player control view fades out.
    private func hidePlayerControl(animateDuration: TimeInterval = 0.4) {
        UIView.animate(withDuration: animateDuration, delay: 0, options: .curveEaseIn) {
            self.playerControlView.alpha = 0
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            self.playerControlView.isHidden = true
        }
    }
    
    /// Show player control.
    /// - Parameter animateDuration: The duration player control view fades in.
    private func showPlayerControl(animateDuration: TimeInterval = 0.4) {
        self.playerControlView.isHidden = false
        UIView.animate(withDuration: animateDuration, delay: 0, options: .curveEaseOut) {
            self.playerControlView.alpha = 1
        }
    }
    
    private func autoHidePlayerControl() {
        autoHideTimer?.cancel()
        autoHideTimer = BufferTimer(interval: 0, delaySecs: 3, repeats: false, action: { [weak self] _ in
            guard let self = self else { return }
            self.hidePlayerControl()
        })
        autoHideTimer?.start()
    }
    
    private func cancelAutoHidePlayerControl() {
        autoHideTimer?.cancel()
    }
    
    /// Display screenLockedView.
    private func addScreenLockedView() {
        view.addSubview(screenLockedView)
        screenLockedView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            screenLockedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            screenLockedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            screenLockedView.topAnchor.constraint(equalTo: view.topAnchor),
            screenLockedView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    /// Remove screenLockedView.
    private func removeScreenLockedView() {
        screenLockedView.removeFromSuperview()
    }
    
    /// Display screen locked panel.
    /// - Parameters:
    ///   - delay: Show screen locked view after delay seconds.
    ///   - seconds: The duration screen locked view keep visible on screen.
    private func showScreenLockedPanel(delay: TimeInterval = 0, for seconds: TimeInterval = 3) {
        screenLockedView.uiPropertiesIsHidden(isHidden: false)
        
        Timer.scheduledTimer(withTimeInterval: delay + seconds + 0.6, repeats: false) {[weak self] _ in
            guard let self = self else { return }
            self.screenLockedView.uiPropertiesIsHidden(isHidden: true)
        }
    }
    
    /// Add observer UIScreen.brightnessDidChangeNotification
    private func observeScreenBrightness() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateBrightnessSlider), name: UIScreen.brightnessDidChangeNotification, object: nil)
    }
    
    /// Update brightness slider value when brightness did change.
    @objc func updateBrightnessSlider() {
        playerControlView.updateBrightnessSliderValue()
    }
    
    
    // MARK: - methods use with delegate methods
    
    /// Hide control panel and show locked screen view.
    private func lockScreen() {
        hidePlayerControl(animateDuration: 0.2)
        addScreenLockedView()
        showScreenLockedPanel()
    }
    
    /// Present subtitleAudioViewController.
    private func showAudioSubtitleSelection() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let subtitleAudioViewController = storyboard.instantiateViewController(withIdentifier: SubtitleAudioViewController.reuseIdentifier) as? SubtitleAudioViewController else { return }
        subtitleAudioViewController.mediaOption = customPlayerViewModel.videoPlayHelper.mediaOption
        subtitleAudioViewController.selectedAudioIndex = audioSlectedIndex
        subtitleAudioViewController.selectedSubtitleIndex = subTitleSlectedIndex
        subtitleAudioViewController.delegate = self
        present(subtitleAudioViewController, animated: true, completion: nil)
    }
    
    private func dismissCustomPlayerViewController() {
        rotateDisplay(to: .portrait)
        dismiss(animated: true, completion: nil)
    }
    
    private func adjustBrightness(_ sliderValue: Double) {
        UIScreen.main.brightness = CGFloat(sliderValue)
    }
    
    /// Toggle the slelcted button be orange.
    private func setControlViewSpeedButton(playSpeedRate:Float) {
        var button: UIButton? {
            switch playSpeedRate {
            case 0.5:
                return playerControlView.slowSpeedButton
            case 1:
                return playerControlView.normalSpeedButton
            case 1.5:
                return playerControlView.fastSpeedButton
            default:
                return nil
            }
        }
        playerControlView.setSpeedButtonColor(selecedSpeedButton: button)
    }

}

// MARK: - PlayerControlDelegate

extension CustomPlayerViewController: PlayerControlViewDelegate {
    
    func handleSliderEvent(_ playerControlview: PlayerControlView, sliderEventType: PlayerControlViewSliderEventType) {
        
        switch sliderEventType {
            
        case .progressValueChange(let sliderValue):
            customPlayerViewModel.slideToTime(Double(sliderValue))

        case .progressTouchEnd(let sliderValue):
            customPlayerViewModel.sliderTouchEnded(Double(sliderValue))
            
        case .brightnessValueChange(let sliderValue):
            adjustBrightness(Double(sliderValue))
        }
    }
    
    func handleTap(_ playerControlview: PlayerControlView, tapType: PlayerControlViewTapType) {
        
        switch tapType {
            
        case .togglePlay:
            customPlayerViewModel.togglePlay()
            
        case .jumpToTime(let jumpTimeType):
            customPlayerViewModel.jumpToTime(jumpTimeType)
            
        case .adjustSpeed(let speedButtonType):
            customPlayerViewModel.adjustSpeed(speedButtonType)

        case .proceedNextItem:
            customPlayerViewModel.changeCurrentTime(currentTime: .zero)
            customPlayerViewModel.proceedNextPlayerItem()
            
        case .hidePlayerControl:
            hidePlayerControl()
            
        case .lockScreen:
            lockScreen()
            
        case .showAudioSubtitlePage:
            showAudioSubtitleSelection()
            
        case .dismissCustomPlayerViewController:
            dismissCustomPlayerViewController()
        }
    }
    
    func pauseToSeek(_ playerControlview: PlayerControlView) {
        customPlayerViewModel.pausePlayer()
    }
    
}

// MARK: - NetworkCheckable

extension CustomPlayerViewController: NetworkCheckable {
    
    private func connectionHandler() {
        DispatchQueue.main.async {
            if let noNetworkAlert = self.noNetworkAlert {
                self.dismissAlert(noNetworkAlert, completion: nil)
            }
        }
    }
    
    private func noConnectionHandler() {
        DispatchQueue.main.async {
            self.noNetworkAlert = self.popAlert(title: Constant.networkAlertTitle, message: Constant.networkAlertMessage)
        }
    }
    
}

// MARK: - PlayerViewDelegate

extension CustomPlayerViewController: PlayerViewDelegate {
    
    /// Show player control when user tap playerView.
    func showPlayerControl(from playerView: PlayerView) {
        showPlayerControl()
        autoHidePlayerControl()
    }
    
}

// MARK: - ScreenLockedViewDelegate

extension CustomPlayerViewController: ScreenLockedViewDelegate {
    
    /// Show screen lock panel when user tap screenLockedView.
    func showScreenLockPanel(from screenLockedView: ScreenLockedView) {
        showScreenLockedPanel()
    }
    
    /// Remove screen locked view, and then show play control.
    func unlockScreen(from screenLockedView: ScreenLockedView) {
        removeScreenLockedView()
        showPlayerControl()
    }
    
}

// MARK: - SubtitleAudioSelectDelegate

extension CustomPlayerViewController: SubtitleAudioSelectDelegate {
    
    /// Recieve the subtitle index from subtitleAudioViewController, and set to current player item.
    func selectSubtitle(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int) {
        customPlayerViewModel.selectMediaOption(mediaOptionType: .subtitle, index: index)
        subTitleSlectedIndex = index
    }
    
    /// Recieve the audio index from subtitleAudioViewController, and set to current player item.
    func selectAudio(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int) {
        customPlayerViewModel.selectMediaOption(mediaOptionType: .audio, index: index)
        audioSlectedIndex = index
    }
    
}

// MARK: - Config UI method

extension CustomPlayerViewController {
    
    private func setBackgroundcolor() {
        view.backgroundColor = .black
    }
    
    private func setPlayerView() {
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setPlayerControlView() {
        view.addSubview(playerControlView)
        playerControlView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerControlView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerControlView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerControlView.topAnchor.constraint(equalTo: view.topAnchor),
            playerControlView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
}

