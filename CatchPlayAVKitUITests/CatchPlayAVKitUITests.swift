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
        app = nil
    }

    func test_tapPlayOnLaunchPage_playerPagePlayButtonShouldExist() throws {
        LaunchPage(app).presentPlayerPage()
        XCTAssertTrue(PlayerPage(app).playerPlayButton.exists)
    }
    
    func test_tapDismissButtonOnPlayerPage_launchPagePlayButtonShouldExist() throws {
        LaunchPage(app).presentPlayerPage()
        PlayerPage(app).dismissButton.tap()
        XCTAssertTrue(LaunchPage(app).playButton.exists)
    }
    
    func test_lockScreen_playerPagePlayButtonShouldNotExist() throws {
        LaunchPage(app).presentPlayerPage()
        PlayerPage(app).lockButton.tap()
        XCTAssertFalse(PlayerPage(app).playerPlayButton.exists)
    }
    
    func test_unlockScreen_playerPagePlayButtonShouldExist() {
        LaunchPage(app).presentPlayerPage()
        PlayerPage(app).lockButton.tap()
        PlayerPage(app).unlockButton.tap()
        XCTAssertTrue(PlayerPage(app).playerPlayButton.exists)
    }
    
    func test_playerControlAutoHide_playerPagePlayButtonShouldNotExistAfter5Secs() {
        LaunchPage(app).presentPlayerPage()
        PlayerPage(app).playerPlayButton.tap()
        sleep(5)
        XCTAssertFalse(PlayerPage(app).playerPlayButton.exists)
    }
    
    func test_tapAudioSubtitleButton_subtitleAudioPageTableViewShouldExist() {
        LaunchPage(app).presentPlayerPage()
        PlayerPage(app).subtitleAudioButton.tap()
        XCTAssertTrue(SubtitleAudioPage(app).audioTableView.exists)
    }

}

class Page {
    var app: XCUIApplication
    required init(_ app: XCUIApplication) {
        self.app = app
    }
}

class LaunchPage: Page {
    lazy var playButton = app.buttons["play"].firstMatch
    func presentPlayerPage() {
        playButton.tap()
    }
}

class PlayerPage: Page {
    lazy var playerPlayButton = app.buttons["playImageButton"].firstMatch
    lazy var lockButton = app.buttons["lock"].firstMatch
    lazy var unlockButton = app.buttons["unlockButton"].firstMatch
    lazy var dismissButton = app.buttons["dismissButton"].firstMatch
    lazy var subtitleAudioButton = app.buttons["Subtitle/Audio"].firstMatch
}

class SubtitleAudioPage: Page {
    lazy var audioTableView = app.tables["audioTableView"].firstMatch
}

