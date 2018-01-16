//
//  File.swift
//  SFSocket
//
//  Created by 孔祥波 on 27/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import AxLogger
class HTTPAdapter: Adapter {
    var connected:Bool = false
    public var reqHeader:SFHTTPRequestHeader?
    public var respHeader:SFHTTPResponseHeader?
    var headerData:Data = Data()
    override var streaming:Bool{
        get {
            return connected
        }
    }
    override init(p: SFProxy, h: String, port: UInt16) {
        
        
        super.init(p: p, h: h, port: port)
    }

    func buildRequestHeader() ->Data {
        var header = "CONNECT " + realHost + ":" + String(realPort) + " HTTP/1.1\r\n"
        header += "Host: " + realHost + "\r\n"
        if !proxy.method.isEmpty && !proxy.password.isEmpty  {
            //http basic auth
            let temp = proxy.method + ":" + proxy.password
            
            let utf8str = temp.data(using: .utf8)
            
            if let base64Encoded = utf8str?.base64EncodedString(options: .endLineWithLineFeed) {
                header += "Proxy-Authorization: Basic " + base64Encoded + "\r\n"
            }
        }
        header += "USER-AGENT: kcptun\r\nAccept: */*\r\nProxy-Connection: Keep-Alive\r\n\r\n"
        let data = header.data(using: .utf8)!
        return data
    }
    override func recv(_ data: Data) throws -> (Bool,Data) {
        if streaming {
            return (true,data)
        }else {
            if let r = data.range(of:hData, options: Data.SearchOptions.init(rawValue: 0)){
                // 解析CONNECT response
                // body found
                if headerData.count == 0 {
                    headerData = data
                }else {
                    headerData.append( data)
                }
                //headerData.append( data.subdata(in: r))
                
                respHeader = SFHTTPResponseHeader(data: headerData)
                if let r = respHeader, r.sCode != 200 {
                    Xcon.log("HTTP CONNECT status:",items:r.sCode,level: .Error)
                    //有bug
                    
                    //let e = NSError(domain:errDomain , code: 10,userInfo:["reason":"http auth failure!!!"])
                    Xcon.log("HTTP socketDidCloseReadStream",items: data,level:.Error)
                    throw SFAdapterError.invalidHTTPCode
                    //sendReq()
                    //NSLog("CONNECT status\(r.sCode) ")
                }else {
                    Xcon.log("Got HTTP CONNECT Respond", level: .Debug)
                }
                
                connected = true
                
                
                let len =  r.upperBound // https need delete CONNECT respond
                if len < data.count {
                    //copy and reset buffer
                    let dataX = headerData.subdata(in: Range(len ..< headerData.count ))
                    headerData.resetBytes(in: Range(0 ..< headerData.count))
                    return (true,dataX)
                }else {
                    return (true,Data())// SFAdapterError.invalidHTTPWaitRespond
                }
            }else {
                headerData.append(data)
                throw SFAdapterError.invalidHTTPWaitHeader
            }
        }
        
    }
    
    override func send(_ tdata: Data) -> (data: Data, tag: Int) {
        
        if tdata.count == 0 {
            //send connect data
           return (buildRequestHeader(),-1000)
        }else {
            if streaming {
                 return (tdata,0)
            }else {
                fatalError()
            }
           
        }
        
    }
}
