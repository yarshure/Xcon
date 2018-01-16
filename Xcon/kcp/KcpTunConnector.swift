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
class KcpTunConnector: ProxyConnector{
    static let shared:KcpTunConnector = {
        
        if let p = SFProxy.createProxyWithLine(line: "SS,0.0.0.0,6000,,", pname: "CN2"){
            return KcpTunConnector.init(p: p)
        }
        fatalError()
    }()
   
    //adapter key-v
    var adapters:[UInt32:Adapter] = [:]
    var tunSocket:KcpStocket!
    
    static let SMuxTimeOut = 13.0 //没数据就timeout

    
    //new tcp stream income
    func incomingStream(_ sid:UInt32,session:Xcon,host:String,port:UInt16) {
        
        guard let a = Adapter.createAdapter(self.proxy, host: host  , port: port) else  {
            fatalError()
        }
        adapters[sid] = a
        
    
        if tunSocket == nil {
            let config = createTunConfig(self.proxy)
            tunSocket = KcpStocket.init(proxy: self.proxy, config: config, queue: queue)
        }
        
        
        guard let socket = tunSocket else {return}
        socket.incomingStream(sid, session: session)
       
        
    }
    //开始发送
    //MARK: for socket use
    public func didDisconnect(_ stream:Xcon, error: Error?) {
        adapters.removeValue(forKey: stream.sessionID)
        stream.didDisconnectWith(socket: self)
        
    }
    public func didConnect(_ stream:Xcon) {
        
        guard let a = adapters[stream.sessionID] else {return}
        //adapter handshake data
        let result = a.send(Data())
        tunSocket.writeData(result.data, withTag: result.tag)
    }
    
    func didReadData(_ data: Data,withTag:Int, stream: Xcon) {
        guard let a = adapters[stream.sessionID] else {return}
        do {
            let result = try a.recv(data)
            stream.didWrite(data: result.value, by: self)
        }catch let e  {
            Xcon.log("recv error \(e.localizedDescription)", level: .Error)
        }
        
    }
    
    //MARK: --------
    
    //MARK for Xcon use
    //需要协议转换和处理
    func writeData(_ data: Data, withTag: Int,session:UInt32) {
        //todo
        guard let a = adapters[session] else {return}
        let result = a.send(data)
        tunSocket.writeData(result.data, withTag: result.tag)
    }
    public override func readDataWithTag(_ tag: Int) {
        guard let s = tunSocket else {
            return
        }
        s.readDataWithTag(tag)
    }
   
    public func didWriteData(_ data: Data?, withTag: Int, stream:Xcon) {
        
        stream.didWrite(data: data, by: self)
    }
    
    

    

}


extension KcpTunConnector{
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
