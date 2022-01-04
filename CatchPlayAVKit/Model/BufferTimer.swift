//
//  BufferTimer.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import Foundation

class BufferTimer {
    typealias actionBlock = ((Int) -> Void)
    private var interval: TimeInterval
    private var delaySecs: TimeInterval
    private var serialQueue: DispatchQueue
    private var repeats: Bool = true
    private var action: actionBlock?
    private var timer: DispatchSourceTimer
    private var isRuning: Bool = false
    var actionTimes: Int = 0

    init(interval: TimeInterval, delaySecs: TimeInterval = 0, queue: DispatchQueue = .main, repeats: Bool = true, action: actionBlock?) {
        self.interval = interval
        self.delaySecs = delaySecs
        self.repeats = repeats
        self.serialQueue = queue
        self.action = action
        self.timer = DispatchSource.makeTimerSource(queue: serialQueue)
    }

    func replaceOldAction(action: actionBlock?) {
        guard let action = action else {
            return
        }
        self.action = action
    }

    deinit {
        cancel()
    }
}

extension BufferTimer {

    func start() {
        timer.schedule(deadline: .now() + delaySecs, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.actionTimes += 1
            strongSelf.action?(strongSelf.actionTimes)
            if !strongSelf.repeats {
                strongSelf.cancel()
                strongSelf.action = nil
            }
        }
        resume()
    }

    func suspend() {
        if isRuning {
            timer.suspend()
            isRuning = false
        }
    }

    func resume() {
        if !isRuning {
            timer.resume()
            isRuning = true
        }
    }

    func cancel() {
        if !isRuning {
            resume()
        }
        timer.cancel()
    }
}
