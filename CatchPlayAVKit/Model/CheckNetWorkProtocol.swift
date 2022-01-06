//
//  CheckNetWorkProtocol.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import Network

class NetworkManager {
    let monitor = NWPathMonitor()
}

protocol CheckNetWorkProtocol {
    var networkManager: NetworkManager { get }
}

extension CheckNetWorkProtocol {
    
    func checkNetwork(connectionHandler: @escaping ()->Void,
                      noConnectionHandler: @escaping ()->Void) {
        networkManager.monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                connectionHandler()
            } else {
                noConnectionHandler()
            }
        }
        networkManager.monitor.start(queue: DispatchQueue.global())
    }
    
}

