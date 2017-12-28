//
//  HTTPProxyConnector.swift
//  SimpleTunnel
//
//  Created by yarshure on 15/11/11.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import AxLogger
import XSocket
public  class HTTPProxyConnector:ProxyConnector {
    
    var connectionMode:SFConnectionMode = .HTTP
    public var reqHeader:SFHTTPRequestHeader?
    public var respHeader:SFHTTPResponseHeader?
    var httpConnected:Bool = false
    var headerData:Data = Data()
    static let ReadTag:Int = -2000
    static let WriteTag:Int = -2001
    // https support current don't support
    static func connect(_ target: String, port: UInt16,p:SFProxy, delegate: SocketDelegate, queue: DispatchQueue)  -> HTTPProxyConnector {
        let c = HTTPProxyConnector(p: p)
        c.targetPort = port
        c.targetHost = target
        c.queue = queue
        c.socketdelegate = delegate
        Xcon.log("HTTP connector start", level: .Info)
        c.start()
        return c
    }
    deinit {
        //reqHeader = nil
        //respHeader = nil
        Xcon.log(cIDString + "deinit", level: .Debug)
    }
    func sendReq() {
        var data:Data
        
        if let req = reqHeader  {
            data = req.buildCONNECTHead(self.proxy)! 
             
        } else {
            data = SFHTTPRequestHeader.buildHead(self.proxy, host: targetHost, port: targetPort)!
        }
        self.writeData(data, withTag: HTTPProxyConnector.WriteTag)
    }
    func recvHeaderData(data:Data) ->Int{
        // only use display response status,recent request feature need
        if let r = data.range(of:hData, options: Data.SearchOptions.init(rawValue: 0)){
        
            // body found
            if headerData.count == 0 {
                headerData = data
            }else {
                headerData.append( data)
            }
            //headerData.append( data.subdata(in: r))
            
            respHeader = SFHTTPResponseHeader(data: headerData)
            if let r = respHeader, r.sCode != 200 {
                Xcon.log("HTTP PRoxy CONNECT status",items:r.sCode,level: .Error)
                //有bug
                
                //let e = NSError(domain:errDomain , code: 10,userInfo:["reason":"http auth failure!!!"])
                Xcon.log("socketDidCloseReadStream",items: data,level:.Error)
                //self.forceDisconnect()
                //sendReq()
                //NSLog("CONNECT status\(r.sCode) ")
            }
        
           
            
            return r.upperBound // https need delete CONNECT respond
        }else {
            headerData.append(data)
            
        }
        return 0
    }
 
 

    public static func connectorWithSelectorPolicy(targetHostname hostname:String, targetPort port:UInt16,p:SFProxy,delegate: SocketDelegate, queue: DispatchQueue) ->HTTPProxyConnector{
        let c:HTTPProxyConnector = HTTPProxyConnector(p: p)
        //c.manager = man
        //c.cIDFunc()
        c.socketdelegate = delegate
        c.queue = queue
        c.targetHost = hostname
        c.targetPort = port
        
        c.start()
        return c
    }
    public override func didDisconnect(_ socket: RawSocketProtocol, error: Error?) {
        
        self.socketdelegate?.didDisconnectWith(socket: self)
        
    }
    
    public override func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol) {
        if httpConnected == true {
            self.socketdelegate?.didRead(data: data, from: self)
        }else {
            if withTag == HTTPProxyConnector.ReadTag {
              
                    if self.respHeader == nil {
                        let len = self.recvHeaderData(data: data)
                        
                        if len == 0{
                            Xcon.log("http  don't found resp header",level: .Warning)
                        }else {
                            //找到resp header
                            self.httpConnected = true
                            if let d = self.socketdelegate {
                                d.didConnectWith(adapterSocket: self)
                            }
                            if len < data.count {
                                let dataX = data.subdata(in: Range(len ..< data.count ))
                               
                               self.socketdelegate?.didRead(data: dataX, from: self)
                                
                            }
                        }
                    }
                
                }
            
        }

    }
    
    public override func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol) {
        if httpConnected == true {
            self.socketdelegate?.didWrite(data: data, by: self)
        }else {
            if withTag == HTTPProxyConnector.WriteTag{
                self.socket.readDataWithTag(HTTPProxyConnector.ReadTag)
            }
        }
        
        
    }
    
    public override func didConnect(_ socket: RawSocketProtocol) {
        if httpConnected == false {
            self.sendReq()
        }else {
            self.socketdelegate?.didConnectWith(adapterSocket: self)
        }
        
    }
}
