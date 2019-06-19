//
//  AdapterSocket.swift
//  Xcon
//
//  Created by yarshure on 2017/11/24.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Foundation
import XSocket
import NetworkExtension
public class AdapterSocket:SocketProtocol,RawSocketDelegate {
    
    var adapter:Adapter? //代理协议处理器 ss over http /ss over tls,ss over kcp,ss over socks5
    public var sourcePort: XPort?{
        get {
            return nil
        }
    }
    
    public var destinationPort: XPort?{
        get {
            return nil
        }
    }
    public var local:NWHostEndpoint?{
        get {
            return socket.local
        }
    }
    public var remote: NWHostEndpoint? {
        get {
         
            return socket.remote
        }
    }
    public func didDisconnect(_ socket: RawSocketProtocol, error: Error?) {
        
        fatalError("AdapterSocket didDisconnect need imp in subClass")
       
    }
    
    public func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol) {
        
        fatalError("AdapterSocket didReadData  need imp in subClass")
    }
    
    public func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol) {
        fatalError("AdapterSocket didWriteData  need imp in subClass")
        
    }
    
    public func didConnect(_ socket: RawSocketProtocol) {
        fatalError("AdapterSocket didConnect  need imp in subClass")
      
    }
    
   
    deinit {
        Xcon.log("Adapter Deinit", level: .Debug)
    }
    public var socket: RawSocketProtocol!
    
    public weak var socketdelegate: SocketDelegate?
    
    public var status: SocketStatus =   .invalid
    
    public func readData() {
        
    }
    init() {
        
    }
    func start(){
        
    }
    public func write(data: Data) {
        
    }
    
    public func disconnect(becauseOf error: Error?) {
        //close ring
        self.socketdelegate?.didDisconnectWith(socket: self)
    }
    
    public func forceDisconnect(becauseOf error: Error?) {
        if socket != nil  {
            socket.disconnect(becauseOf: error)
            socket  = nil
        }
        self.socketdelegate?.didDisconnectWith(socket: self)
    }
    
    public func forceDisconnect(_ sessionID: UInt32) {
        if socket != nil  {
            socket.forceDisconnect(sessionID)
        }
        
    }
    
    public var queue: DispatchQueue!
    
    public var isConnected: Bool = false
    
    public var writePending: Bool = false
    
    public var readPending: Bool = false
    
    public var sourceIPAddress: XSocket.IPv4Address?
    
    
    
    public var destinationIPAddress: XSocket.IPv4Address?
    
    
    public var useCell: Bool = false
    
    public var tcp: Bool = true
    
    public func connectTo(_ host: String, port: UInt16, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws {
        socket = RawSocketFactory.getRawSocket(type: SocketBaseType.NW, tcp: true)
        socket.queue = self.queue //dispatch queue
        socket.delegate = self
       
        Xcon.log("connect to \(host):\(port)", level: .Info)
     
        try socket.connectTo(host, port: port, enableTLS: enableTLS, tlsSettings: tlsSettings)
        
    }
    
    public func writeData(_ data: Data, withTag: Int) {
        socket.writeData(data, withTag: withTag)
    }
    
    public func readDataWithTag(_ tag: Int) {
        Xcon.log("readDataWithTag \(tag)", level: .Debug)
        socket.readDataWithTag(tag)
    }
    
    public func readDataToLength(_ length: Int, withTag tag: Int) {
        Xcon.log("shoud not go here", level: .Info)
    }
    
    public func readDataToData(_ data: Data, withTag tag: Int) {
        Xcon.log("shoud not go here", level: .Info)
    }
    
    public func readDataToData(_ data: Data, withTag tag: Int, maxLength: Int) {
        Xcon.log("shoud not go here", level: .Info)
    }
    
    
}
