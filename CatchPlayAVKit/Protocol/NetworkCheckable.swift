//
//  NetworkCheckable.swift
//  CatchPlayAVKit
//
//  Created by Astrid on 2022/1/4.
//

import Network

class NetworkManager {
    let monitor = NWPathMonitor()
}

protocol NetworkCheckable {
    var networkManager: NetworkManager { get }
}

extension NetworkCheckable {
    
    
    /// Check whether there is network connection.
    /// - Parameters:
    ///   - connectionHandler: The closure will be executed when connection resume .
    ///   - noConnectionHandler: The closure will be executed if there is no network connection.
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

