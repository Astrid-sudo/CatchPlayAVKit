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
    
    var sut: CustomPlayerViewController!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = CustomPlayerViewController()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    func testJumpToTimeBackward() throws {
        // arrange
        sut.currentTime = .zero
        let playControlView = PlayerControlView()
        let jumpToType = JumpTimeType.backward(100)
        
        // act
        sut.jumpToTime(playControlView, jumpToType)
       
        // assert 
        XCTAssertTrue(sut.currentTime == .zero)
    }
    
}
