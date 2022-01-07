//
//  PlayerControlView.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import UIKit

enum JumpTimeType {
    case forward(_ seconds: Float64)
    case backward(_ seconds: Float64)
}

enum PlayButtonType {
    case play
    case pause
    case indicatorView
    
    var systemName: String {
        switch self {
        case .pause: return Constant.pause
        case .play: return Constant.play
        case .indicatorView: return  ""
        }
    }
}

enum PlayerControlViewTapType {
    case togglePlay
    case jumpToTime(JumpTimeType)
    case adjustSpeed(SpeedButtonType)
    case proceedNextItem
    case hidePlayerControl
    case lockScreen
    case showAudioSubtitlePage
    case dismissCustomPlayerViewController
}

enum PlayerControlViewSliderEventType {
    case progressValueChange(_ sliderValue: Float)
    case progressTouchEnd(_ sliderValue: Float)
    case brightnessValueChange(_ sliderValue: Float)
}

enum SpeedButtonType {
    case slow
    case normal
    case fast
    
    var speedRate: Float {
        switch self {
        case .slow:
            return 0.5
            
        case .normal:
            return 1
            
        case .fast:
            return 1.5
        }
    }
}

protocol PlayerControlViewDelegate: AnyObject {
    
    func handleTap(_ playerControlview: PlayerControlView,
                   tapType: PlayerControlViewTapType)
    
    func handleSliderEvent(_ playerControlview: PlayerControlView,
                           sliderEventType: PlayerControlViewSliderEventType)
    
    func pauseToSeek(_ playerControlview: PlayerControlView)
}

class PlayerControlView: UIView {
    
    var screenWidth: CGFloat {
        if let window = window {
            let leftPadding = window.safeAreaInsets.left
            let rightPadding = window.safeAreaInsets.right
            return UIScreen.main.bounds.width - leftPadding - rightPadding
        } else {
            return UIScreen.main.bounds.width
        }
    }
    
    var screenHeight: CGFloat {
        if let window = window {
            let topPadding = window.safeAreaInsets.top
            let bottomPadding = window.safeAreaInsets.bottom
            return UIScreen.main.bounds.height - topPadding - bottomPadding
        } else {
            return UIScreen.main.bounds.height
        }
    }
    
    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        configUI()
        addGestureRecognizer(tapGesture)
    }
    
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    weak var delegate: PlayerControlViewDelegate?
    
    // MARK: - UI properties
    
    private lazy var backgroundDimView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0.65
        return view
    }()
    
    private lazy var brightnessIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: Constant.sunMax)
        imageView.tintColor = .white
        return imageView
    }()
    
    private lazy var dismissButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 32)
        let bigImage = UIImage(systemName: Constant.xmarkCircle, withConfiguration: config)
        button.setImage(bigImage, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(dismissCustomPlayerViewController), for: .touchUpInside)
        button.accessibilityIdentifier = Constant.dismissButton
        return button
    }()
    
    private lazy var brightnessSlider: UISlider = {
        let slider = UISlider()
        slider.maximumTrackTintColor = .gray
        slider.minimumTrackTintColor = .orange
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = Float(UIScreen.main.brightness)
        slider.isEnabled = true
        slider.isContinuous = true
        let imagee = UIImage(systemName: Constant.circleFill)
        let colorImage = imagee?.withTintColor(.orange, renderingMode: .alwaysOriginal)
        slider.setThumbImage((colorImage), for: .normal)
        slider.setThumbImage((colorImage), for: .highlighted)
        slider.addTarget(self, action: #selector(adjustBrightness), for: UIControl.Event.valueChanged)
        return slider
    }()
    
    private lazy var playButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 32)
        let bigImage = UIImage(systemName: Constant.play, withConfiguration: config)
        button.setImage(bigImage, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)
        button.accessibilityIdentifier = Constant.playImageButton
        return button
    }()
    
    private lazy var goForwardButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 32)
        let bigImage = UIImage(systemName: Constant.goforward, withConfiguration: config)
        button.setImage(bigImage, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(goforward), for: .touchUpInside)
        return button
    }()
    
    private lazy var goBackwardButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 32)
        let bigImage = UIImage(systemName: Constant.gobackward, withConfiguration: config)
        button.setImage(bigImage, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(gobackward), for: .touchUpInside)
        return button
    }()
    
    private lazy var progressSlider: UISlider = {
        let slider = UISlider()
        slider.maximumTrackTintColor = .gray
        slider.minimumTrackTintColor = .orange
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        slider.isEnabled = true
        slider.isContinuous = true
        slider.addTarget(self, action: #selector(progressSliderValueChanged), for: UIControl.Event.valueChanged)
        slider.addTarget(self, action: #selector(progressSliderTouchBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(progressSliderTouchEnded), for: [.touchUpInside, .touchCancel, .touchUpOutside])
        return slider
    }()
    
    private lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        label.textColor = .white
        label.textAlignment = .center
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    private lazy var currentTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00 /"
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        label.textColor = .white
        label.textAlignment = .center
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    private(set) lazy var slowSpeedButton: UIButton = {
        let speedImage = UIImage(systemName: Constant.speedometer)
        let button = UIButton()
        button.setImage(speedImage, for: .normal)
        button.setTitle(Constant.speedRate05, for: .normal)
        button.setTitleColor(.orange, for: .selected)
        button.titleLabel?.font = UIFont(name: Constant.font, size: 12)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        button.tintColor = .white
        button.addTarget(self, action: #selector(adjustSpeed(button:)), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var normalSpeedButton: UIButton = {
        let speedImage = UIImage(systemName: Constant.speedometer)
        let button = UIButton()
        button.setImage(speedImage, for: .normal)
        button.setTitle(Constant.speedRate1, for: .normal)
        button.setTitleColor(.orange, for: .normal)
        button.titleLabel?.font = UIFont(name: Constant.font, size: 12)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        button.tintColor = .orange
        button.addTarget(self, action: #selector(adjustSpeed(button:)), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var fastSpeedButton: UIButton = {
        let speedImage = UIImage(systemName: Constant.speedometer)
        let button = UIButton()
        button.setImage(speedImage, for: .normal)
        button.setTitle(Constant.speedRate15, for: .normal)
        button.titleLabel?.font = UIFont(name: Constant.font, size: 12)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        button.tintColor = .white
        button.addTarget(self, action: #selector(adjustSpeed(button:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var speedButtons = [slowSpeedButton, normalSpeedButton, fastSpeedButton]
    
    private lazy var lockButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: Constant.lockOpen), for: .normal)
        button.setTitle(Constant.lock, for: .normal)
        button.titleLabel?.font = UIFont(name: Constant.font, size: 12)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        button.tintColor = .white
        button.addTarget(self, action: #selector(lockScreen), for: .touchUpInside)
        return button
    }()
    
    private lazy var audioSubtitleButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: Constant.textBubble), for: .normal)
        button.setTitle(Constant.subtitleAndAudio, for: .normal)
        button.titleLabel?.font = UIFont(name: Constant.font, size: 12)
        button.titleLabel?.minimumScaleFactor = .leastNonzeroMagnitude
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        button.tintColor = .white
        button.addTarget(self, action: #selector(setAudioSubtitle), for: .touchUpInside)
        return button
    }()
    
    private lazy var nextEpisodeButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: Constant.forwardEnd), for: .normal)
        button.setTitle(Constant.nextEpisode, for: .normal)
        button.titleLabel?.font = UIFont(name: Constant.font, size: 12)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        button.tintColor = .white
        button.addTarget(self, action: #selector(goNextEpisode), for: .touchUpInside)
        return button
    }()
    
    private lazy var moreSettingStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.distribution = .fillProportionally
        return stackView
    }()
    
    private lazy var progressStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.distribution = .fillProportionally
        return stackView
    }()
    
    private lazy var indicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large )
        view.color = .white
        view.hidesWhenStopped = true
        view.isHidden = true
        return view
    }()
    
    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(hidePlayerControl))
        return gesture
    }()
    
    // MARK: - sender method
    
    @objc func togglePlay() {
        delegate?.handleTap(self, tapType: .togglePlay)
    }
    
    @objc func goforward() {
        delegate?.handleTap(self, tapType: .jumpToTime(.forward(15)))
    }
    
    @objc func gobackward() {
        delegate?.handleTap(self, tapType: .jumpToTime(.backward(15)))
    }
    
    @objc func adjustSpeed(button: UIButton) {
        switch button {
        
        case slowSpeedButton:
            delegate?.handleTap(self, tapType: .adjustSpeed(.slow))
        
        case normalSpeedButton:
            delegate?.handleTap(self, tapType: .adjustSpeed(.normal))
        
        case fastSpeedButton:
            delegate?.handleTap(self, tapType: .adjustSpeed(.fast))
        
        default:
            break
        }
    }
    
    @objc func lockScreen() {
        delegate?.handleTap(self, tapType: .lockScreen)
    }
    
    @objc func setAudioSubtitle() {
        delegate?.handleTap(self, tapType: .showAudioSubtitlePage)
    }
    
    @objc func goNextEpisode() {
        delegate?.handleTap(self, tapType: .proceedNextItem)
    }
    
    @objc func progressSliderValueChanged() {
        delegate?.handleSliderEvent(self, sliderEventType: .progressValueChange(progressSlider.value))
    }
    
    @objc func progressSliderTouchBegan() {
        delegate?.pauseToSeek(self)
    }
    
    @objc func progressSliderTouchEnded() {
        delegate?.handleSliderEvent(self, sliderEventType: .progressTouchEnd(progressSlider.value))
    }
    
    @objc func adjustBrightness() {
        delegate?.handleSliderEvent(self, sliderEventType: .brightnessValueChange(brightnessSlider.value))
    }
    
    @objc func hidePlayerControl() {
        delegate?.handleTap(self, tapType: .hidePlayerControl)
    }
    
    @objc func dismissCustomPlayerViewController() {
        delegate?.handleTap(self, tapType: .dismissCustomPlayerViewController)
    }
    
    // MARK: - UI method
    
    private func configUI() {
        setBackgroundDimView()
        setBrightnessIcon()
        setDismissButton()
        setPlayButton()
        setIndicatorView()
        setGoForwardButton()
        setGoBackwardButton()
        setMoreSettingStackView()
        setProgressStackView()
        setBrightnessSlider()
    }
    
    private func setBackgroundDimView() {
        addSubview(backgroundDimView)
        backgroundDimView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundDimView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            backgroundDimView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            backgroundDimView.topAnchor.constraint(equalTo: self.topAnchor),
            backgroundDimView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    private func setBrightnessIcon() {
        addSubview(brightnessIcon)
        brightnessIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            brightnessIcon.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 32),
            brightnessIcon.topAnchor.constraint(equalTo: self.topAnchor, constant: 40)
        ])
    }
    
    private func setDismissButton() {
        addSubview(dismissButton)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dismissButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -32),
            dismissButton.topAnchor.constraint(equalTo: self.topAnchor, constant: 32)
        ])
    }
    
    private func setPlayButton() {
        addSubview(playButton)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            playButton.heightAnchor.constraint(equalToConstant: 50),
            playButton.widthAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setGoForwardButton() {
        addSubview(goForwardButton)
        goForwardButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            goForwardButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            goForwardButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: (screenWidth - 16) / 4)
        ])
    }
    
    private func setGoBackwardButton() {
        addSubview(goBackwardButton)
        goBackwardButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            goBackwardButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            goBackwardButton.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -(screenWidth - 16) / 4)
        ])
    }
    
    private func setMoreSettingStackView() {
        addSubview(moreSettingStackView)
        moreSettingStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            moreSettingStackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            moreSettingStackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16),
            moreSettingStackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
        ])
        moreSettingStackView.addArrangedSubview(slowSpeedButton)
        moreSettingStackView.addArrangedSubview(normalSpeedButton)
        moreSettingStackView.addArrangedSubview(fastSpeedButton)
        moreSettingStackView.addArrangedSubview(lockButton)
        moreSettingStackView.addArrangedSubview(audioSubtitleButton)
        moreSettingStackView.addArrangedSubview(nextEpisodeButton)
    }
    
    private func setProgressStackView() {
        addSubview(progressStackView)
        progressStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressStackView.bottomAnchor.constraint(equalTo: moreSettingStackView.topAnchor, constant:  -16),
            progressStackView.widthAnchor.constraint(equalTo: moreSettingStackView.widthAnchor, constant: -16),
            progressStackView.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        ])
        progressStackView.addArrangedSubview(progressSlider)
        progressStackView.addArrangedSubview(currentTimeLabel)
        progressStackView.addArrangedSubview(durationLabel)
    }
    
    private func setBrightnessSlider() {
        addSubview(brightnessSlider)
        brightnessSlider.transform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi / 2))
        brightnessSlider.translatesAutoresizingMaskIntoConstraints = true
        brightnessSlider.frame = CGRect(x: 40, y: 85, width: 5, height: screenHeight * 2 / 5)
    }
    
    private func setIndicatorView() {
        addSubview(indicatorView)
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicatorView.centerXAnchor.constraint(equalTo: playButton.centerXAnchor),
            indicatorView.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
        ])
    }
    
    private func setProgressSliderValue(_ progress: Float) {
        progressSlider.value = progress
    }
    
    private func setCurrentTimeLabel(_ currentTime: Float) {
        currentTimeLabel.text = TimeManager.floatToTimecodeString(seconds: currentTime) + " /"
    }
    
    private func setDrationLabel(_ duration: Float) {
        durationLabel.text = TimeManager.floatToTimecodeString(seconds: duration)
    }
    
    // MARK: - method for CustomPlayViewController
    
    func updateBrightnessSliderValue() {
        brightnessSlider.value = Float(UIScreen.main.brightness)
    }
    
    func showIdicatorView() {
        playButton.isHidden = true
        indicatorView.startAnimating()
    }
    
    func removeIndicatorView() {
        playButton.isHidden = false
        indicatorView.stopAnimating()
    }
    
    func togglePlayButtonImage(_ playButtonType:PlayButtonType) {
        if playButtonType == .indicatorView {
            playButton.isHidden = true
            indicatorView.startAnimating()
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 32)
            let bigImage = UIImage(systemName: playButtonType.systemName, withConfiguration: config)
            playButton.setImage(bigImage, for: .normal)
            playButton.isHidden = false
            indicatorView.stopAnimating()
        }
    }
    
    func updateProgress(currentTime: Float, duration: Float) {
        setProgressSliderValue(currentTime / duration)
        setCurrentTimeLabel(currentTime)
        setDrationLabel(duration)
    }
    
    func setSpeedButtonColor(selecedSpeedButton: UIButton?) {
        guard let selectedButton = selecedSpeedButton else { return }
        speedButtons.forEach { button in
            button.tintColor = .white
            button.setTitleColor(.white, for: .normal)
            if button == selectedButton {
                button.tintColor = .orange
                button.setTitleColor(.orange, for: .normal)
            }
        }
    }

}
