//
//  ProxyConnector.swift
//  Surf
//
//  Created by yarshure on 16/1/7.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import AxLogger
import NetworkExtension
import Security
import XSocket
public class ProxyConnector: AdapterSocket {

    
    public var description: String {
        return ""
    }
    var cIDString:String {
        get {
            return "cIDString"
        }
    }
    var proxy:SFProxy
    var tlsSupport:Bool = false
    var targetHost:String = ""
    var targetPort:UInt16 = 0
 
 
    init(p:SFProxy) {
        proxy = p
        
        super.init()
        
        //cIDFunc()
    }
     init(_ target: String, port: UInt16,p:SFProxy, delegate: SocketDelegate, queue: DispatchQueue)  {
        self.proxy = p
        super.init()
        self.targetPort = port
        self.targetHost = target
        self.queue = queue
        self.socketdelegate = delegate
       
    }
    static func connectTo(_ host: String, port: UInt16,p:SFProxy,delegate:SocketDelegate, queue: DispatchQueue) ->ProxyConnector{
        if !p.kcptun {
            switch p.type{
                
            case .HTTP,.HTTPS:
                return  HTTPProxyConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
                
            case .SS:
                return TCPSSConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
                
            case .SS3:
                return TCPSSConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
                
            case .SOCKS5:
                return Socks5Connector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
                
            case .HTTPAES:
                return   TCPSSConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
                
            case .LANTERN:
                return TCPSSConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
                
            }
        }else {
            if  KcpTunConnector.shared.queue == nil {
                KcpTunConnector.shared.queue = queue
            }
            KcpTunConnector.shared.proxy = p
            return KcpTunConnector.shared
        }
        
        
    }
    public override func start() {
        guard let port = UInt16(proxy.serverPort) else {
            return
        }
        if proxy.type == .SS {
            //Don't suport over TLS
            var dest = proxy.serverAddress
            if !proxy.serverIP.isEmpty{
                dest = proxy.serverIP
              
            }
            try! super.connectTo(dest, port: port, enableTLS: false, tlsSettings: nil)
        }else {
            try! super.connectTo(proxy.serverAddress, port: port, enableTLS: proxy.tlsEnable, tlsSettings: nil)
        }
        
    }
}
