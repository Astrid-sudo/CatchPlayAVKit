//
//  SubtitleAudioViewController.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/5.
//

import UIKit

protocol SubtitleAudioSelectDelegate: AnyObject {
    func selectSubtitle(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int)
    func selectAudio(_ subtitleAudioViewController: SubtitleAudioViewController, index: Int)
}

class SubtitleAudioViewController: UIViewController {
    
    // MARK: - properties
    
    var mediaOption: MediaOption?
    
    private var audioOptions: [String]? {
        didSet {
            audioTableView.reloadData()
        }
    }
    
    private var subtitleOptions: [String]? {
        didSet {
            subtitleTableView.reloadData()
        }
    }
    
    private var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    private var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    private var selectedAudioIndex: Int?
    
    private var selectedSubtitleIndex: Int?
    
    weak var delegate: SubtitleAudioSelectDelegate?
    
    // MARK: - UI properties
    
    private lazy var audioTableView: UITableView = {
        let table = UITableView()
        table.dataSource = self
        table.delegate = self
        table.allowsSelection = true
        table.showsVerticalScrollIndicator = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: UITableViewCell.reuseIdentifier)
        table.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: UITableViewHeaderFooterView.reuseIdentifier)
        table.accessibilityIdentifier = Constant.audioTableView
        return table
    }()
    
    private lazy var subtitleTableView: UITableView = {
        let table = UITableView()
        table.dataSource = self
        table.delegate = self
        table.allowsSelection = true
        table.showsVerticalScrollIndicator = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: UITableViewCell.reuseIdentifier)
        table.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: UITableViewHeaderFooterView.reuseIdentifier)
        return table
    }()
    
    private lazy var dismissButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 32)
        let bigImage = UIImage(systemName: Constant.xmarkCircle, withConfiguration: config)
        button.setImage(bigImage, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(dismissSubtitleAudioViewController), for: .touchUpInside)
        return button
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    // MARK: - life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        parseMediaOption()
        setDismissButton()
        setAudioTableView()
        setSubtitleTableView()
        setStackView()
    }
    
    // MARK: - method
    
    private func parseMediaOption() {
        guard let mediaOption = mediaOption else { return }
        audioOptions = mediaOption.avMediaCharacteristicAudible.map({$0.displayName})
        subtitleOptions = mediaOption.avMediaCharacteristicLegible.map({$0.displayName})
    }
    
    @objc func dismissSubtitleAudioViewController() {
        dismiss(animated: true, completion: nil)
    }

}

// MARK: - UITableViewDataSource

extension SubtitleAudioViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if tableView == audioTableView {
            return audioOptions?.count ?? 0
        }
        
        if tableView == subtitleTableView {
            return subtitleOptions?.count ?? 0
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: UITableViewCell.reuseIdentifier, for: indexPath)
        cell.textLabel?.textColor = .white
        cell.selectionStyle = .none
        
        if tableView == audioTableView,
           let audioOptions = audioOptions {
            cell.textLabel?.text = audioOptions[indexPath.row]
            if indexPath.row == selectedAudioIndex {
                cell.textLabel?.textColor = .orange
            }
        }
        
        if tableView == subtitleTableView,
           let subtitleOptions = subtitleOptions {
            cell.textLabel?.text = subtitleOptions[indexPath.row]
            if indexPath.row == selectedSubtitleIndex {
                cell.textLabel?.textColor = .orange
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == audioTableView {
            return Constant.audio
        }
        
        if tableView == subtitleTableView {
            return Constant.subtitles
        }
        return nil
    }
    
}

// MARK: - UITableViewDelegate

extension SubtitleAudioViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == audioTableView {
            selectedAudioIndex = indexPath.row
            delegate?.selectAudio(self, index: indexPath.row)
            audioTableView.reloadData()
        }
        
        if tableView == subtitleTableView {
            selectedSubtitleIndex = indexPath.row
            delegate?.selectSubtitle(self, index: indexPath.row)
            subtitleTableView.reloadData()
        }
    }
    
}

// MARK: - UI method

extension SubtitleAudioViewController {
    
    private func setDismissButton() {
        view.addSubview(dismissButton)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dismissButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            dismissButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16)
        ])
    }
    
    private func setAudioTableView() {
        audioTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            audioTableView.heightAnchor.constraint(equalToConstant: screenHeight - 32),
            audioTableView.widthAnchor.constraint(equalToConstant: (screenWidth - 150)/2)
        ])
    }
    
    private func setSubtitleTableView() {
        subtitleTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subtitleTableView.heightAnchor.constraint(equalToConstant: screenHeight - 32),
            subtitleTableView.widthAnchor.constraint(equalToConstant: (screenWidth - 150)/2)
        ])
    }
    
    private func setStackView() {
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            stackView.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -16)
        ])
        stackView.addArrangedSubview(audioTableView)
        stackView.addArrangedSubview(subtitleTableView)
    }
    
}


