//
//  Adapter.swift
//  Xcon
//
//  Created by yarshure on 2017/11/22.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Foundation
protocol AdapterProtocol:Hashable {
    var streaming:Bool{ get }
    func send(_ data:Data) ->(data:Data,tag:Int)//tag info
    func recv(_ data:Data) throws ->(result:Bool,value:Data)
    var hashValue: Int { get }
}
enum SFAdapterError: Error {
    case invalidHTTPWaitRespond
    case invalidHTTPWaitHeader
    case invalidHTTPCode
    case invalidSocksAuth
    case invalidSocksResp
    case otherError
}
class Adapter:AdapterProtocol {
    func recv(_ data: Data) throws -> (result:Bool,value:Data) {
        return (false, Data())
    }
    
    func send(_ data: Data) -> (data:Data,tag:Int) {
        return (Data(),-1)
    }
    
    //控制是否进入streaming 模式
    var streaming:Bool{
        get {
            return false
        }
    }
    var proxy:SFProxy
    var realHost:String
    var realPort:UInt16
    init(p:SFProxy,h:String,port:UInt16) {
        proxy = p
        realHost = h
        realPort = port
    }
    func isKcp() ->Bool {
        return proxy.kcptun
    }
    var targetHost:String {
        return proxy.serverAddress
    }
    var targetPort:UInt16{
        return UInt16(proxy.serverPort)!
    }
    static func createAdapter(_ proxy:SFProxy,host:String,port:UInt16) -> Adapter? {
        switch proxy.type {
        case .HTTP:
            return HTTPAdapter(p: proxy, h: host, port: port)
        case .SOCKS5:
            return Socks5Adapter(p: proxy, h: host, port: port)
        case .SS:
            return SSAdapter(p: proxy, h: host, port: port)
        case .SS3:
            return  SS3Adapter(p: proxy, h: host, port: port)
        default:
            return nil
        }
    }
    var hashValue: Int {
        get {
            return (realHost + "\(realPort)").hash
        }
    }
    func hash(into hasher: inout Hasher) {
        return hasher.combine((realHost + "\(realPort)").hash)
    }
    static func ==(lhs: Adapter, rhs: Adapter) -> Bool {
        // 这里不对吧？
        //return lhs.realHost == rhs.realHost && lhs.realPort == rhs.realPort
        return lhs.proxy == rhs.proxy //&& lhs.realPort == rhs.realPort
    }
}
