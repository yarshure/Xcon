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

public class DirectConnector:NWTCPSocket{
    var interfaceName:String?
    var targetHost:String = ""
    var targetPort:UInt16 = 0
    //var ipAddress:String?
    override public func start() {
         autoreleasepool { do {
            
            try  super.connectTo(self.targetHost, port: self.targetPort, enableTLS: false, tlsSettings: nil)
        }catch let e as NSError {
            //throw e
            Xcon.log("DirectConnector connectTo error",items:targetHost,e.localizedDescription, level: .Error)
            }
        }
    }
    public override  func connectTo(_ host: String, port: UInt16, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws {
        do {
           try  super.connectTo(host, port: port, enableTLS: false, tlsSettings: nil)
        }catch let e  {
            throw e
        }
        
        
    }
    static func connectTo(_ host: String, port: UInt16, delegate: RawSocketDelegate, queue: DispatchQueue)  -> DirectConnector {
        let c = DirectConnector()
        c.targetPort = port
        c.targetHost = host
        c.queue = queue
        c.delegate = delegate
        
        c.start()
        return c
    }
    
}


