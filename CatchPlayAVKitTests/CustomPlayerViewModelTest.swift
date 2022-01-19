//
//  CustomPlayerViewModelTest.swift
//  CatchPlayAVKitTests
//
//  Created by Astrid on 2022/1/18.
//

import XCTest
@testable import CatchPlayAVKit
import CoreMedia


class CustomPlayerViewModelTest: XCTestCase {
    
    var sut: CustomPlayerViewModel!
    
    override func setUpWithError() throws {
        sut = CustomPlayerViewModel()
    }
    
    override func tearDownWithError() throws {
        sut = nil
    }
    
    func test_changeSpeedRate_normalCase() throws {
        // arrange
        let speedRate: Float = 0.8
        // action
        sut.changeSpeedRate(speedRate: speedRate)
        // assert
        XCTAssertTrue(sut.playSpeedRate.value == 0.8)
    }
    
    func test_changeSpeedRate_lessThanZeroCase() throws {
        // arrange
        let speedRate: Float = -0.8
        // action
        sut.changeSpeedRate(speedRate: speedRate)
        // assert
        XCTAssertTrue(sut.playSpeedRate.value == 1)
    }
    
    func test_changeCurrentTime_zeroCase() throws {
        // arrange
        let currentTime = CMTime(value: 0, timescale: 1)
        // action
        sut.changeCurrentTime(currentTime: currentTime)
        // assert
        XCTAssertTrue(sut.currentTime.value == "00:00 /")
    }
    
    func test_changeCurrentTime_secondsCase() throws {
        // arrange
        let currentTime = CMTime(value: 3, timescale: 1)
        // action
        sut.changeCurrentTime(currentTime: currentTime)
        // assert
        XCTAssertTrue(sut.currentTime.value == "00:03 /")
    }
    
    func test_changeCurrentTime_minutesCase() throws {
        // arrange
        let currentTime = CMTime(value: 180, timescale: 1)
        // action
        sut.changeCurrentTime(currentTime: currentTime)
        // assert
        XCTAssertTrue(sut.currentTime.value == "03:00 /")
    }
    
    func test_changeCurrentTime_hoursCase() throws {
        // arrange
        let currentTime = CMTime(value: 7261, timescale: 1)
        // action
        sut.changeCurrentTime(currentTime: currentTime)
        // assert
        XCTAssertTrue(sut.currentTime.value == "02:01:01 /")
    }
    
    func test_changeDuration_zeroCase() throws {
        // arrange
        let duration = CMTime(value: 0, timescale: 1)
        // action
        sut.changeDuration(duration: duration)
        // assert
        XCTAssertTrue(sut.duration.value == "00:00")
    }
    
    func test_changeDuration_secondsCase() throws {
        // arrange
        let duration = CMTime(value: 3, timescale: 1)
        // action
        sut.changeDuration(duration: duration)
        // assert
        XCTAssertTrue(sut.duration.value == "00:03")
    }
    
    func test_changeDuration_minutesCase() throws {
        // arrange
        let duration = CMTime(value: 179, timescale: 1)
        // action
        sut.changeDuration(duration: duration)
        // assert
        XCTAssertTrue(sut.duration.value == "02:59")
    }
    
    func test_changeDuration_hoursCase() throws {
        // arrange
        let duration = CMTime(value: 7261, timescale: 1)
        // action
        sut.changeDuration(duration: duration)
        // assert
        XCTAssertTrue(sut.duration.value == "02:01:01")
    }
    
    func test_changeProgress_normalCase() throws {
        // arrange
        let currentTime = CMTime(value: 50, timescale: 1)
        let duration = CMTime(value: 100, timescale: 1)
        // action
        sut.changeProgress(currentTime: currentTime, duration: duration)
        // assert
        XCTAssertTrue(sut.playProgress.value == 0.5)
    }
    
    func test_changeProgress_currentLongerThanDurationCase() throws {
        // arrange
        let currentTime = CMTime(value: 500, timescale: 1)
        let duration = CMTime(value: 100, timescale: 1)
        // action
        sut.changeProgress(currentTime: currentTime, duration: duration)
        // assert
        XCTAssertTrue(sut.playProgress.value.isNaN)
    }
    
    func test_didPlaybackEnd_notLastItem() throws {
        // arrange
        let videoPlayhelper = sut.videoPlayHelper
        // action
        sut.didPlaybackEnd(videoPlayhelper)
        // assert
        XCTAssertTrue(sut.playBackEnd.value == true)
        XCTAssertTrue(sut.isTheLastItem.value == false)
    }
    
    func test_didPlaybackEnd_isLastItem() throws {
        // arrange
        let videoPlayhelper = sut.videoPlayHelper
        videoPlayhelper.proceedNextPlayerItem()
        // action
        sut.didPlaybackEnd(videoPlayhelper)
        // assert
        XCTAssertTrue(sut.playBackEnd.value == true)
        XCTAssertTrue(sut.isTheLastItem.value == true)
    }

    func test_toggleIndicatorView_show() throws {
        // arrange
        let videoPlayhelper = sut.videoPlayHelper
        // action
        sut.toggleIndicatorView(videoPlayhelper, show: true)
        // assert
        XCTAssertTrue(sut.showIndicator.value == true)
    }
    
    func test_toggleIndicatorView_hide() throws {
        // arrange
        let videoPlayhelper = sut.videoPlayHelper
        // action
        sut.toggleIndicatorView(videoPlayhelper, show: false)
        // assert
        XCTAssertTrue(sut.showIndicator.value == false)
    }

    func test_updateDuration() throws {
        // arrange
        let videoPlayhelper = sut.videoPlayHelper
        let duration = CMTime(value: 120, timescale: 1)
        // action
        sut.updateDuration(videoPlayhelper, duration: duration)
        // assert
        XCTAssertTrue(sut.duration.value == "02:00")
    }
    
}
