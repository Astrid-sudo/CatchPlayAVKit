//
//  CatchPlayAVKitUITests.swift
//  CatchPlayAVKitUITests
//
//  Created by Astrid on 2022/1/4.
//

import XCTest

class CatchPlayAVKitUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTapPlayOnLaunchPage() throws {
        let app = XCUIApplication()
        app.launch()
        LaunchPage(app).presentPlayerPage()
        XCTAssertTrue(PlayerPage(app).playerPlayButton.exists)
    }
    
    func testTapDismissButtonBackToLaunchPage() throws {
        let app = XCUIApplication()
        app.launch()
        LaunchPage(app).presentPlayerPage()
        PlayerPage(app).dismissButton.tap()
        XCTAssertTrue(LaunchPage(app).playButton.exists)
    }
    
    func testLockScreen() throws {
        let app = XCUIApplication()
        app.launch()
        LaunchPage(app).presentPlayerPage()
        PlayerPage(app).lockButton.tap()
        XCTAssertFalse(PlayerPage(app).playerPlayButton.exists)
    }
    
    func testUnlockScreen() {
        let app = XCUIApplication()
        app.launch()
        LaunchPage(app).presentPlayerPage()
        PlayerPage(app).lockButton.tap()
        PlayerPage(app).unlockButton.tap()
        XCTAssertTrue(PlayerPage(app).playerPlayButton.exists)
    }
    
    func testPlayerControlAutoHide() {
        let app = XCUIApplication()
        app.launch()
        LaunchPage(app).presentPlayerPage()
        PlayerPage(app).playerPlayButton.tap()
        sleep(5)
        XCTAssertFalse(PlayerPage(app).playerPlayButton.exists)
    }
    
    func testTapAudioSubtitleButton() {
        let app = XCUIApplication()
        app.launch()
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

