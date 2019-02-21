//
//  KcpTunConnector.swift
//  Xcon
//
//  Created by yarshure on 2018/1/12.
//  Copyright © 2018年 yarshure. All rights reserved.

// provide KCP for other layer use
// iOS app can't fork process
// so use socket
//应该是shared
// 可以先不实行adapter，加密,用kun 加密
// 测试先是不加密，aes 加密， adapter 加密
// 重新链接 需要？

import NetworkExtension
import Foundation
import KCP
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
    let frameSize = 4096
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
        Xcon.log("\(stream.sessionID) socket disconnect,remove adapter", level: .Notify)
        adapters.removeValue(forKey: stream.sessionID)
        stream.didDisconnectWith(socket: self)
        
    }
    public func didConnect(_ stream:Xcon) {
        
        guard let a = adapters[stream.sessionID] else {return}
        //adapter handshake data
        
        let result = a.send(Data())
        //splite
       
        //socket connected
        self.sendRawData(result.data, session: stream.sessionID)
        Xcon.log("send \(result.data)", level: .Trace)
        if a.proxy.type == .SS {
            //socket connected
            stream.didConnectWith(adapterSocket: self)
        }

    }
    
    func didReadData(_ data: Data,withTag:Int, stream: Xcon) {
        
        guard let a = adapters[stream.sessionID] else {return}
        
        if a.streaming || a.proxy.type == .SS {
            do {
                let result = try a.recv(data)
                stream.didRead(data: result.value, from: self)
            }catch let e {
                Xcon.log("\(e.localizedDescription)", level: .Error)
            }
            
        }else {
            //handshake
            
            do {
                let cnnctFlag = a.streaming
                
                let result = try a.recv(data)
                if result.result {
                    //http socks5
                    // socks 5 todo ,mutil time send shake and data
                    let newcflag = a.streaming
                    if cnnctFlag != newcflag {
                        Xcon.log(" shake hand finished \(stream) result.value \(result.value as NSData)", level: .Debug)
                        //变动第一次才发这个event
                        stream.didConnectWith(adapterSocket: self)
                        
                    }else {
                        Xcon.log(" shake hand finished \(stream) not finished , todo fixed", level: .Debug)
                        fatalError()
                    }
                }else {
                    Xcon.log("recv failure ", level: .Error)
                }
                
            }catch let e  {
                Xcon.log("recv error \(e.localizedDescription)", level: .Error)
            }
        }

        
    }
    
    //MARK: --------
    
    //MARK for Xcon use
    //需要协议转换和处理
    func writeData(_ data: Data, withTag: Int,session:UInt32) {
        //todo
        guard let a = adapters[session] else {
            fatalError()
            return
            
        }
        
        if !a.streaming {
            fatalError()
        }
        if a.proxy.type == .SS {
            let result = a.send(data)
            self.sendRawData(result.data, session: session)
        }else {
             self.sendRawData(data, session: session)
        }
        
        
       
    }
    func sendRawData(_ data:Data,session:UInt32){
        var databuffer:Data = Data()
        let frames = split(data, cmd: cmdPSH, sid: session)
        for f in frames {
            databuffer.append(f.frameData())
            
        }
        tunSocket.writeData(databuffer, withTag: 0)
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
    
    

    //
    public override func forceDisconnect(_ sessionID: UInt32) {
        Xcon.log("send Fin \(sessionID)", level: .Notify)
        adapters.removeValue(forKey: sessionID)
        tunSocket.sendFin(sessionID)
    }
    public override var local:NWHostEndpoint?{
        get {
            return tunSocket.localAddress()
        }
    }
    public override var remote: NWHostEndpoint? {
        get {
            if !tunSocket.proxy.serverIP.isEmpty {
                 return NWHostEndpoint.init(hostname:tunSocket.proxy.serverIP,port:tunSocket.proxy.serverPort)
            }
            return NWHostEndpoint.init(hostname:tunSocket.proxy.serverAddress,port:tunSocket.proxy.serverPort)
            
        }
    }

}


extension KcpTunConnector{
    func createTunConfig(_ p:SFProxy) ->KcpConfig {
        var c = KcpConfig()
        if !p.config.crypt.isEmpty {
            c.crypt = KcpCryptoMethod.init(rawValue: p.config.crypt)!
            if  let d = p.pkbdf2Key() {
                c.key = d
            }
            
            
        }

        c.dataShards = p.config.datashard
        c.parityShards = p.config.parityshard
        //c.nodelay = p.config.
        c.sndwnd = p.config.sndwnd
        c.rcvwnd = p.config.rcvwnd
        c.mtu = p.config.mtu
        c.iptos = p.config.dscp
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
        
        Xcon.log("KCPTUN: #######################", level: .Info)
        Xcon.log("KCPTUN: Crypto = \(p.config.crypt)", level: .Info)
        Xcon.log("KCPTUN: key = \(c.key as NSData?)", level: .Debug)
        
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
    //对于打包需要split
    func split(_ data:Data, cmd:UInt8,sid:UInt32) ->[Frame]{
        //let fs = data.count/frameSize + 1
        var result:[Frame] = []
        var left:Int = data.count
        var index:Int = 0
        while left > frameSize {
            if index >= data.count {
                break
            }
            let subData = data.subdata(in: index ..< frameSize )
            let f = Frame.init(cmd, sid: sid, data: subData)
            index += frameSize
            left -= frameSize
            result.append(f)
        }
        
        if left > 0 {
            let subData = data.subdata(in: index ..< data.count )
            let f = Frame.init(cmd, sid: sid, data: subData)
            result.append(f)
        }
        
        return result
        
    }
    
}
