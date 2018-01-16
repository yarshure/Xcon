//
//  Xcon.swift
//  Xcon
//
//  Created by yarshure on 2017/11/22.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Foundation
import XSocket
import NetworkExtension
import os.log
public protocol XconDelegate: class {
    /**
     The socket did disconnect.
     
     This should only be called once in the entire lifetime of a socket. After this is called, the delegate will not receive any other events from that socket and the socket should be released.
     
     - parameter socket: The socket which did disconnect.
     */
    func didDisconnect(_ socket: Xcon,  error:Error?)
    
    /**
     The socket did read some data.
     
     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    func didReadData(_ data: Data, withTag: Int, from: Xcon)
    
    /**
     The socket did send some data.
     
     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    func didWriteData(_ data: Data?, withTag: Int, from: Xcon)
    
    /**
     The socket did connect to remote.
     
     - parameter socket: The connected socket.
     */
    func didConnect(_ socket: Xcon)
}
public class Xcon:SocketDelegate{
    public func didConnectWith(adapterSocket: SocketProtocol) {
        Xcon.log("didConnectWith", level: .Info)
        
        self.delegate?.didConnect(self)
        
    }
    
    
    public func didDisconnectWith(socket: SocketProtocol) {
        Xcon.log("didDisconnectWith", level: .Info)
        
        self.delegate?.didDisconnect(self, error: nil)
        
        
    }
    
    public func didRead(data: Data, from: SocketProtocol) {
        Xcon.log("read didRead", level: .Info)
        
        self.delegate?.didReadData(data, withTag: 0, from: self)
        
    }
    
    public func didWrite(data: Data?, by: SocketProtocol) {
        Xcon.log("didwrite ", level: .Info)
        
        self.delegate?.didWriteData(data, withTag: 0, from: self)
        
    }
    
    public func didBecomeReadyToForwardWith(socket: SocketProtocol) {
        
    }
    
    public func updateAdapterWith(newAdapter: AdapterSocket) {
        
    }
    

    public weak var delegate: XconDelegate?
   // public var delegate: RawSocketDelegate?
    var adapter:Adapter?
    var connector:AdapterSocket?
    
    init(q:DispatchQueue) {
        self.queue = q
    }
    public func forceDisconnect(_ sessionID: UInt32) {
        connector?.forceDisconnect(sessionID)
    }
    public var remote:NWHostEndpoint? {
        get {
            return connector?.remote
        }
    }
    public var local:NWHostEndpoint? {
        get {
            return connector?.local
        }
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
    
    public var tcp: Bool = false
    
    deinit {
        Xcon.log("Xcon deinit", level: .Debug)
    }
   
    
    public func disconnect(becauseOf error: Error?) {
        connector?.disconnect(becauseOf: error)
    }
    
    public func forceDisconnect(becauseOf error: Error?) {
        connector?.disconnect(becauseOf: error)
    }
    
    public func writeData(_ data: Data, withTag: Int) {
        connector?.writeData(data, withTag: withTag)
    }
    
    public func readDataWithTag(_ tag: Int) {
        connector?.readDataWithTag(tag)
    }
    
    public func readDataToLength(_ length: Int, withTag tag: Int) {
        
    }
    
    public func readDataToData(_ data: Data, withTag tag: Int) {
        
    }
    
    public func readDataToData(_ data: Data, withTag tag: Int, maxLength: Int) {
        
    }
    public func forceDisconnect(){
        
    }
    public static var debugEnable = false
    static public func socketFromProxy(_ p: SFProxy?,targetHost:String,Port:UInt16,sID:UInt,delegate:XconDelegate,queue:DispatchQueue,sessionID:Int = 0,enableTLS:Bool = false) ->Xcon?{
        var con:Xcon
        if !enableTLS {
            con =  Xcon.init(q: queue)
        }else {
            con = SecurtXcon.init(q: queue, host: targetHost, port: Int(Port))
        }
        con.delegate = delegate
        if let p = p {
            //proxy mode
            if !p.kcptun  {
                let c = ProxyConnector.connectTo(targetHost, port: Port, p: p, delegate: con, queue: queue)
                con.connector = c
            }else {
                fatalError()
            }
            
        }else {
            let c = DirectConnector.connectTo(targetHost, port: Port, delegate: con, queue: queue)
           
            con.connector = c
        }
        
        return con
    }
    
}
import AxLogger
extension Xcon{
    static func log(_ msg:String,items: Any...,level:AxLoggerLevel , category:String="default",file:String=#file,line:Int=#line,ud:[String:String]=[:],tags:[String]=[],time:Date=Date()){
        
        if level != AxLoggerLevel.Debug {
            AxLogger.log(msg,level:level)
        }
        
    }
    static func log(_ msg:String,level:AxLoggerLevel , category:String="default",file:String=#file,line:Int=#line,ud:[String:String]=[:],tags:[String]=[],time:Date=Date()){
        //MARK: todo fix //AxLogger Crash
        
        
        if level != AxLoggerLevel.Debug {
            AxLogger.log(msg,level:level)
        }
        if debugEnable {
            #if os(iOS)
                if #available(iOSApplicationExtension 10.0, *) {
                    os_log("Xcon: %@", log: .default, type: .debug, msg)
                } else {
                    print(msg)
                    // Fallback on earlier versions
                }
            #elseif os(OSX)
                if #available(OSXApplicationExtension 10.12, *) {
                    os_log("Xcon: %@", log: .default, type: .debug, msg)
                } else {
                    print(msg)
                    // Fallback on earlier versions
                }
            
            #endif
            
            
        }
        
    }
}
