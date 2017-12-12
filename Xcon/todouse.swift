//
//  todouse.swift
//  Xcon
//
//  Created by yarshure on 2017/12/12.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Foundation

func xx(){
    if policy == .Direct {
        //基本上网需求
        guard let chain = proxy else {
            s.socket =  DirectConnector.connectTo(targetHost, port: Port, delegate: s , queue:queue )
            
            return s
        }
        switch chain.type {
        case .HTTP,.HTTPS:
            let connector = HTTPProxyConnector.connectorWithSelectorPolicy(targetHostname: targetHost, targetPort: Port, p: chain,delegate: s , queue:queue)
            let data = SFHTTPRequestHeader.buildCONNECTHead(targetHost, port: String(Port),proxy: chain)
            let message = String.init(format:"http proxy %@ %d", targetHost,Port )
            SKit.log(message,level: .Trace)
            //let c = connector as! HTTPProxyConnector
            connector.reqHeader = SFHTTPRequestHeader(data: data)
            if connector.reqHeader == nil {
                fatalError("HTTP Request Header nil")
            }
            s.socket = connector
        case .SOCKS5:
            s.socket =  Socks5Connector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: chain,delegate: s , queue:queue)
            
        default:
            return nil
        }
    }else {
        if let chain = proxy {
            guard let p = p else { return nil}
            guard let adapter = Adapter.createAdapter(p, host: targetHost, port: Port) else  {
                return nil
            }
            switch chain.type {
            case .HTTP:
                let connector = CHTTPProxConnector.create(targetHostname: adapter.targetHost, targetPort: adapter.targetPort, p: chain,adapter:adapter, delegate: s, queue: queue)
                let data = SFHTTPRequestHeader.buildCONNECTHead(adapter.targetHost, port: String(adapter.targetPort),proxy: chain)
                let message = String.init(format:"http proxy %@ %d", adapter.targetHost,adapter.targetPort )
                SKit.log(message,level: .Trace)
                //let c = connector as! HTTPProxyConnector
                connector.reqHeader = SFHTTPRequestHeader(data: data)
                if connector.reqHeader == nil {
                    fatalError("HTTP Request Header nil")
                }
                
                s.socket =  connector
            case .SOCKS5:
                s.socket =   CSocks5Connector.create(policy, targetHostname: adapter.targetHost, targetPort: adapter.targetPort, p: chain,adapter: adapter,delegate: s , queue:queue)
            default:
                return nil
            }
            
            
            
        }else {
            guard let p = p else { return nil}
            let message = String.init(format:"proxy server %@:%@", p.serverAddress,p.serverPort)
            SKit.log(message,level: .Trace)
            if !p.kcptun {
                switch p.type {
                case .HTTP,.HTTPS:
                    let connector = HTTPProxyConnector.connectorWithSelectorPolicy(targetHostname: targetHost, targetPort: Port, p: p, delegate: s, queue: queue)
                    let data = SFHTTPRequestHeader.buildCONNECTHead(targetHost, port: String(Port),proxy: p)
                    let message = String.init(format:"http proxy %@ %d", targetHost,Port )
                    SKit.log(message,level: .Trace)
                    //let c = connector as! HTTPProxyConnector
                    connector.reqHeader = SFHTTPRequestHeader(data: data)
                    if connector.reqHeader == nil {
                        fatalError("HTTP Request Header nil")
                    }
                    s.socket =  connector
                case .SS:
                    
                    s.socket =    TCPSSConnector.connectTo(targetHost, port: Int(Port), proxy: p, delegate: s, queue: queue)
                //connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: p)
                case .SS3:
                    s.socket =    TCPSS3Connector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: p)
                    
                    
                case .SOCKS5:
                    s.socket =   Socks5Connector.connectorWithSelectorPolicy(policy, targetHostname: targetHost, targetPort: Port, p: p, delegate: s, queue: queue)
                    
                default:
                    SKit.log("Config not support", level: .Error)
                    return nil
                }
            }else {
                guard let adapter = Adapter.createAdapter(p, host: targetHost, port: Port) else  {
                    return nil
                }
                SKit.log("TCP incoming :\(streamID)", level: .Debug)
                s.adapter = adapter
                s.queue = queue
                s.socket = Smux.sharedTunnel
                Smux.sharedTunnel.updateProxy(p,queue: queue)
                Smux.sharedTunnel.incomingStream(UInt32(streamID), session: s)
                
                //.create(policy, targetHostname: targetHost, targetPort: Port, p: p, sessionID: Int(sID))
                
                
            }
            
        }
        
    }
    return s
}
