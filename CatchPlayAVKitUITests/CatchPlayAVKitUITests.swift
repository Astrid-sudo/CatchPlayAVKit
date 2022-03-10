//
//  CatchPlayAVKitUITests.swift
//  CatchPlayAVKitUITests
//
//  Created by Astrid on 2022/1/4.
//

import XCTest

class CatchPlayAVKitUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func test_tapPlayOnLaunchPage_playerPagePlayButtonShouldExist() throws {
        LaunchPage(app)
            .presentPlayerPage()
        XCTAssertTrue(PlayerPage(app).playerPlayButton.exists)
    }
    
    func test_tapDismissButtonOnPlayerPage_launchPagePlayButtonShouldExist() throws {
        LaunchPage(app)
            .presentPlayerPage()
            .dismissPlayerPage()
        XCTAssertTrue(LaunchPage(app).playButton.exists)
    }
    
    func test_lockScreen_playerPagePlayButtonShouldNotExist() throws {
        LaunchPage(app)
            .presentPlayerPage()
            .lockScreen()
        XCTAssertFalse(PlayerPage(app).playerPlayButton.exists)
    }
    
    func test_unlockScreen_playerPagePlayButtonShouldExist() {
        LaunchPage(app)
            .presentPlayerPage()
            .lockScreen()
            .unlockScreen()
        XCTAssertTrue(PlayerPage(app).playerPlayButton.exists)
    }
    
    func test_playerControlAutoHide_playerPagePlayButtonShouldNotExistAfter5Secs() {
        LaunchPage(app)
            .presentPlayerPage()
            .playVideo()
        sleep(5)
        XCTAssertFalse(PlayerPage(app).playerPlayButton.exists)
    }
    
    func test_tapAudioSubtitleButton_subtitleAudioPageTableViewShouldExist() {
        LaunchPage(app)
            .presentPlayerPage()
            .presentSubtitleAudioPage()
        XCTAssertTrue(SubtitleAudioPage(app).audioTableView.exists)
    }

}

// MARK: - Page Object Pattern

class Page {
    var app: XCUIApplication
    required init(_ app: XCUIApplication) {
        self.app = app
    }
}

class LaunchPage: Page {
    
    lazy var playButton = app.buttons["play"].firstMatch
    
    @discardableResult
    func presentPlayerPage() -> PlayerPage {
        playButton.tap()
        return PlayerPage(app)
    }
    
}

class PlayerPage: Page {
    
    lazy var playerPlayButton = app.buttons["playImageButton"].firstMatch
    lazy var lockButton = app.buttons["lock"].firstMatch
    lazy var unlockButton = app.buttons["unlockButton"].firstMatch
    lazy var dismissButton = app.buttons["dismissButton"].firstMatch
    lazy var subtitleAudioButton = app.buttons["Subtitle/Audio"].firstMatch
    
    @discardableResult
    func lockScreen() -> Self {
        lockButton.tap()
        return self
    }
    
    @discardableResult
    func unlockScreen() -> Self {
        unlockButton.tap()
        return self
    }
    
    @discardableResult
    func dismissPlayerPage() -> Self {
        dismissButton.tap()
        return self
    }
    
    @discardableResult
    func playVideo() -> Self {
        playerPlayButton.tap()
        return self
    }
    
    @discardableResult
    func presentSubtitleAudioPage() -> SubtitleAudioPage {
        subtitleAudioButton.tap()
        return SubtitleAudioPage(app)
    }
    
}

class SubtitleAudioPage: Page {
    lazy var audioTableView = app.tables["audioTableView"].firstMatch
}

