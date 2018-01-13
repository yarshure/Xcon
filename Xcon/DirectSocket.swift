//
//  DirectConnector.swift
//  SimpleTunnel
//
//  Created by yarshure on 15/11/11.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import AxLogger
import XSocket
//import CocoaAsyncSocket

public class DirectConnector:AdapterSocket{
    var interfaceName:String?
    var targetHost:String = ""
    var targetPort:UInt16 = 0
    //var ipAddress:String?
    deinit {
        Xcon.log("DirectConnector \(targetHost):\(targetPort) deint",level:.Debug)
    }
    public override func start() {
        do {
            
            try  super.connectTo(self.targetHost, port: self.targetPort, enableTLS: false, tlsSettings: nil)
        }catch let e as NSError {
            //throw e
            Xcon.log("DirectConnector connectTo error",items:targetHost,e.localizedDescription, level: .Error)
        }
        
    }
   
    static func connectTo(_ host: String, port: UInt16, delegate: SocketDelegate, queue: DispatchQueue)  -> DirectConnector {
        let c = DirectConnector()
        c.targetPort = port
        c.targetHost = host
        c.queue = queue
        c.socketdelegate = delegate
        Xcon.log("DirectConnector  start \(host):\(port)", level: .Info)
        c.start()
        return c
    }
    
    public override func didDisconnect(_ socket: RawSocketProtocol, error: Error?) {
       
        Xcon.log("DirectConnector didDisconnect", level: .Info)
        self.socketdelegate?.didDisconnectWith(socket: self)
    }
    
    public override func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol) {
       
        Xcon.log("read length:\(data.count):\(withTag)", level: .Info)
        self.socketdelegate?.didRead(data: data, from: self)
    }
    
    public override func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol) {
        Xcon.log("didWriteData", level: .Info)
        self.socketdelegate?.didWrite(data: data, by: self)
    }
    
    public override func didConnect(_ socket: RawSocketProtocol) {
        Xcon.log("didConnect", level: .Info)
        self.socketdelegate?.didConnectWith(adapterSocket: self)
    }
    
}


