//
//  CatchPlayAVKitTests.swift
//  CatchPlayAVKitTests
//
//  Created by Astrid on 2022/1/4.
//

import XCTest
@testable import CatchPlayAVKit
import CoreMedia

class CatchPlayAVKitTests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    // seek time is longer than duration.
    func testGetValidSeekTimeForward() {
        // arrange
        let duration = CMTime(seconds: 120, preferredTimescale: 1)
        let currentTime = CMTime(seconds: 119, preferredTimescale: 1)
        let jumpTimeType = JumpTimeType.forward(15)
        
        // act
        let validSeekTime = TimeManager.getValidSeekTime(duration: duration, currentTime: currentTime, jumpTimeType: jumpTimeType)
        
        // assert
        XCTAssertTrue(validSeekTime == duration)
    }
    
    // seek time is shorter than duration.
    func testGetValidSeekTimeBackward() {
        // arrange
        let duration = CMTime(seconds: 120, preferredTimescale: 1)
        let currentTime = CMTime(seconds: 0, preferredTimescale: 1)
        let jumpTimeType = JumpTimeType.backward(15)
        
        // act
        let validSeekTime = TimeManager.getValidSeekTime(duration: duration, currentTime: currentTime, jumpTimeType: jumpTimeType)
        
        // assert
        XCTAssertTrue(validSeekTime == .zero)
    }
    
    // seek time is within duration.
    func testGetValidSeekTime() {
        // arrange
        let duration = CMTime(seconds: 120, preferredTimescale: 1)
        let currentTime = CMTime(seconds: 0, preferredTimescale: 1)
        let jumpTimeType = JumpTimeType.forward(15)
        
        // act
        let validSeekTime = TimeManager.getValidSeekTime(duration: duration, currentTime: currentTime, jumpTimeType: jumpTimeType)
        
        // assert
        XCTAssertTrue(validSeekTime == CMTime(seconds: 15, preferredTimescale: 1))
    }
    
    func testGetCMTime() {
        // arrange
        let sliderValue = 0.5
        let duration = CMTime(seconds: 120, preferredTimescale: 1)
        
        // act
        let returnTime = TimeManager.getCMTime(from: sliderValue, duration: duration)
        
        // assert
        XCTAssertTrue(returnTime == CMTime(seconds: 60, preferredTimescale: 1))
    }

}
