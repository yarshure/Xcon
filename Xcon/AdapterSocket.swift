//
//  AdapterSocket.swift
//  Xcon
//
//  Created by yarshure on 2017/11/24.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Foundation
import XSocket
public class AdapterSocket:SocketProtocol,RawSocketProtocol,RawSocketDelegate {
    public func didDisconnect(_ socket: RawSocketProtocol, error: Error?) {
        print("")
    }
    
    public func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol) {
        
    }
    
    public func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol) {
        
    }
    
    public func didConnect(_ socket: RawSocketProtocol) {
         print("didConnect")
    }
    
    public var delegate: RawSocketDelegate?
    
    public var socket: RawSocketProtocol!
    
    public var socketdelegate: SocketDelegate?
    
    public var status: SocketStatus =   .invalid
    
    public func readData() {
        
    }
    init() {
        
    }
    public func write(data: Data) {
        
    }
    
    public func disconnect(becauseOf error: Error?) {
        
    }
    
    public func forceDisconnect(becauseOf error: Error?) {
        
    }
    
   // public var delegate: RawSocketDelegate?
    
    public func forceDisconnect(_ sessionID: UInt32) {
        
    }
    
    public var queue: DispatchQueue!
    
    public var isConnected: Bool = false
    
    public var writePending: Bool = false
    
    public var readPending: Bool = false
    
    public var sourceIPAddress: IPv4Address?
    
    public var sourcePort: Port?
    
    public var destinationIPAddress: IPv4Address?
    
    public var destinationPort: Port?
    
    public var useCell: Bool = false
    
    public var tcp: Bool = true
    
    public func connectTo(_ host: String, port: UInt16, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws {
        var s = RawSocketFactory.getRawSocket()
        s.delegate = self
        s.queue = DispatchQueue.init(label: "socket")
        Xcon.log("connect to \(host):\(port)", level: .Info)
        try s.connectTo(host, port: port, enableTLS: enableTLS, tlsSettings: [:])
        
    }
    
//    public func disconnect(becauseOf error: Error?) {
//
//    }
//
//    public func forceDisconnect(becauseOf error: Error?) {
//
//    }
    
    public func writeData(_ data: Data, withTag: Int) {
        
    }
    
    public func readDataWithTag(_ tag: Int) {
        
    }
    
    public func readDataToLength(_ length: Int, withTag tag: Int) {
        
    }
    
    public func readDataToData(_ data: Data, withTag tag: Int) {
        
    }
    
    public func readDataToData(_ data: Data, withTag tag: Int, maxLength: Int) {
        
    }
    
    
}
