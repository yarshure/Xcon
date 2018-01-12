//
//  KcpTunConnector.swift
//  Xcon
//
//  Created by yarshure on 2018/1/12.
//  Copyright © 2018年 yarshure. All rights reserved.
//
//
//  KCPTunSocket.swift
//  SFSocket
//
//  Created by 孔祥波 on 22/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//
// provide KCP for other layer use
// iOS app can't fork process
// so use socket
//应该是shared
// 可以先不实行adapter，加密,用kun 加密
// 测试先是不加密，aes 加密， adapter 加密
// 重新链接 需要？

import Foundation
import kcp
class KcpTunConnector: AdapterSocket{
    static let shared = KcpTunConnector()
    var proxy:SFProxy?
    //var streams:[UInt32:Xcon] = [:]
    var tunSocket:KcpStocket?
    var adapter:Adapter? //代理协议处理器
    static let SMuxTimeOut = 13.0 //没数据就timeout
    static func incomingSession(_ host: String, port: UInt16,p:SFProxy,delegate:SocketDelegate, queue: DispatchQueue) ->KcpTunConnector{
        let c = KcpTunConnector.shared
        if c.adapter == nil {
            guard let adapter = Adapter.createAdapter(p, host: host, port: port) else  {
                fatalError()
            }
            c.adapter = adapter
        }
        if c.tunSocket == nil {
            let config = c.createTunConfig(p)
            c.tunSocket = KcpStocket.init(proxy: p, config: config)
        }
        return c
    }
    
    //new tcp stream income
    func incomingStream(_ sid:UInt32,session:Xcon) {
        guard let socket = tunSocket else {return}
        socket.incomingStream(sid, session: session)
        session.didConnectWith(adapterSocket: self)
        //        if let dispatchQueue = dispatchQueue {
        //            dispatchQueue.asyncAfter(deadline: .now() + .milliseconds(100)) {
        //                session.didConnect(self)
        //            }
        //        }
        
    }
    
    //需要协议转换和处理
    public override func writeData(_ data: Data, withTag: Int) {
        //todo
    }
    
   
    public func didReadData(_ data: Data, withTag: Int, stream:Xcon) {
        stream.didRead(data: data, from: self)
        //todo
    }
    
    
    
    
    public override func readDataWithTag(_ tag: Int) {
        guard let s = tunSocket else {
            return
        }
        s.readDataWithTag(tag)
    }
    public func didDisconnect(_ stream:Xcon, error: Error?) {
        stream.didDisconnectWith(socket: self)
    }
    
    
    
    public func didWriteData(_ data: Data?, withTag: Int, stream:Xcon) {
        
        stream.didWrite(data: data, by: self)
    }
    
    public func didConnect(_ stream:Xcon) {
        fatalError("AdapterSocket didConnect")
        
    }
    func createTunConfig(_ p:SFProxy) ->TunConfig {
        let c = TunConfig()
        
        c.dataShards = Int32(p.config.datashard)
        c.parityShards = Int32(p.config.parityshard)
        //c.nodelay = p.config.
        c.sndwnd = Int32(p.config.sndwnd)
        c.rcvwnd = Int32(p.config.rcvwnd)
        c.mtu = Int32(p.config.mtu)
        c.iptos = Int32(p.config.dscp)
        switch p.config.mode {
        case "normal":
            c.nodelay = 0
            c.interval = 40
            c.resend = 2
            c.nc = 1
        case "fast":
            c.nodelay = 0
            c.interval = 30
            c.resend = 2
            c.nc = 1
        case "fast2":
            c.nodelay = 1
            c.interval = 20
            c.resend = 2
            c.nc = 1
        case "fast3":
            c.nodelay = 1
            c.interval = 10
            c.resend = 2
            c.nc = 1
        default:
            c.nodelay = 0
            c.interval = 30
            c.resend = 2
            c.nc = 1
            break
        }
        if !p.config.crypt.isEmpty {
            c.crypt = p.config.crypt
            if  let d = p.pkbdf2Key() {
                c.key = d
            }
            
            
        }
        Xcon.log("KCPTUN: #######################", level: .Info)
        Xcon.log("KCPTUN: Crypto = \(p.config.crypt)", level: .Info)
        Xcon.log("KCPTUN: key = \(c.key as NSData)", level: .Debug)
        
        if p.config.noComp {
            Xcon.log("KCPTUN: compress = true", level: .Info)
        }else {
            Xcon.log("KCPTUN: compress = false", level: .Info)
        }
        Xcon.log("KCPTUN: mode = \(p.config.mode)", level: .Info)
        Xcon.log("KCPTUN: datashard = \(p.config.datashard)", level: .Info)
        Xcon.log("KCPTUN: parityshard = \(p.config.parityshard)", level: .Info)
        Xcon.log("KCPTUN: #######################", level: .Info)
        return c
    }
}
