//
//  NetworkMonitor.swift
//  VerseFinderApp  
//
//  Created by Maphari Vincent on 2026/03/03.
//

import Foundation
import Network
import Combine

@MainActor
public final class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published public private(set) var isConnected = true
    @Published public private(set) var connectionType: ConnectionType = .wifi
    
    public enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case other
        case none
    }
    
    public init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { @MainActor in
                self.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else if path.status == .satisfied {
                    self.connectionType = .other
                } else {
                    self.connectionType = .none
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
