//
//  KcpStocket.swift
//  Xcon
//
//  Created by yarshure on 2018/1/12.
//  Copyright © 2018年 yarshure. All rights reserved.
//

import Foundation
import kcp
import snappy
enum SmuxError:Error {
    
    case noHead
    case VerError
    case bodyNotFull
    case internalError
    case recvFin
    
}
class KcpStocket: NSObject {
    var tun:SFKcpTun?
    static let SMuxTimeOut = 13.0 //没数据就timeout
    var snappy:SnappyHelper?
    var config:TunConfig = TunConfig()
    var smuxConfig:Config = Config()
    var ready:Bool = false
    
    var dispatchTimer:DispatchSourceTimer?
    var dispatchQueue :DispatchQueue
    var readBuffer:Data = Data()
    var lastFrame:Frame? // not full frame ,需要快速把已经收到的data 给应用
    var lastActive:Date = Date()
    var proxy:SFProxy
    var sendbuffer:Data = Data()
    var streams:[UInt32:Xcon] = [:]
    func shutdown(){
        if let t = dispatchTimer {
            t.cancel()
        }
        self.destoryTun()
    }
    var useCell:Bool{
        get {
            if let t = tun {
                t.useCell()
            }
            return false
        }
    }

    
    init(proxy:SFProxy,config:TunConfig,queue:DispatchQueue) {
        self.proxy = proxy
        self.dispatchQueue = queue
        super.init()
        
        let type:SOCKS5HostType = proxy.serverAddress.validateIpAddr()
        if type != .DOMAIN {
            self.tun = SFKcpTun.init(config: config, ipaddr: proxy.serverAddress, port: Int32(proxy.serverPort)!, queue: self.dispatchQueue)
        }else {
            let ips = query(proxy.serverAddress)
            //解析
            if ips.isEmpty {
                self.tun = SFKcpTun.init(config: config, ipaddr: ips.first!, port: Int32(proxy.serverPort)!, queue: self.dispatchQueue)
            }
        }
        
        self.tun!.start({[unowned self] (tun) in
            self.ready = true
            Xcon.log("tun connected", level: .Info)
            self.sendNop(sid: 0)
        }, recv: { [unowned self] (tun, date) in
            self.didRecevied(date);
        }) { (tun) in
            self.ready = false
        }
        self.keepAlive(timeOut: 10);
        
        if proxy.config.noComp {
            snappy = SnappyHelper()
        }
        
    }
    
  
   
    
    func didRecevied(_ data: Data!) {
        self.lastActive = Date()
       
        if let  s = snappy {
            if let newData = s.decompress(data) {
                self.readBuffer.append(newData)
            }
            
        }else {
            self.readBuffer.append(data)
        }
        
        
        
        //SKit.log("mux recv data: \(data.count) \(data as NSData)",level: .Debug)
        let _ = streams.flatMap{ k,v in
            return k
        }
        //cpu high
        //SKit.log("\(ss.sorted()) all active stream", level: .Debug)
        while self.readBuffer.count >= headerSize {
            let r = readFrame()
            if let f = r.frame {
                Xcon.log("Nop Event recv sessionid:\(f.sid)", level: .Debug)
                if f.sid == 0 {
                    Xcon.log("main connection keep alive ok", level: .Debug)
                }else {
                    if let stream =  streams[f.sid] {
                        
                        
                        
                        
                        
                        if let d = f.data {
                            if r.error == nil {
                                //full packet
                               
                                KcpTunConnector.shared.didReadData(data, withTag: 0, stream: stream)
                                
                                self.lastFrame = nil
                            }else {
                                //no full
                                if !d.isEmpty {
                                   
                                    KcpTunConnector.shared.didReadData(d, withTag: 0, stream: stream)
                                }
                                
                                
                                
                                self.lastFrame = f
                                //reset data
                                self.lastFrame?.data = nil
                            }
                            
                        }else {
                            if f.cmd == cmdFIN {
                                
                                 KcpTunConnector.shared.didDisconnect(stream, error: nil)
                            }else  {
                                if r.1 == SmuxError.bodyNotFull {
                                    Xcon.log("frame \(f.desc) packet not full",level: .Error)
                                    
                                    break
                                }
                            }
                            
                        }
                        
                    }else {
                        Xcon.log("frame \(f.desc) not found stream drop packet",level: .Error)
                        
                        if let d = f.data {
                            if r.1 == nil {
                                //full packet
                                //stream.didReadData(d, withTag: 0, from: self)
                                self.lastFrame = nil
                            }else {
                                //no full
                                //stream.didReadData(d, withTag: 0, from: self)
                                
                                
                                self.lastFrame = f
                                //reset data
                                self.lastFrame?.data = nil
                            }
                            
                        }else {
                            if f.cmd == cmdFIN {
                                //stream.didDisconnect(self, error: SmuxError.recvFin)
                            }else  {
                                //                                if r.1 == SmuxError.bodyNotFull {
                                //                                    SKit.log("frame \(f.desc) packet not full",level: .Error)
                                //
                                //                                    break
                                //                                }
                            }
                            
                        }
                        //关闭链接
                        sendFin(f.sid)
                        
                    }
                    
                }
                
            }else {
                Xcon.log("buffer \(self.readBuffer as NSData) parser error",level: .Debug)
            }
        }
        
    }
    
    func readFrame() -> (frame:Frame?,error:SmuxError?) {
        if let _ = lastFrame {
            let l = lastFrame!.left
            var tocopy:Int = 0
            if l <= readBuffer.count {
                tocopy = l
            }else {
                tocopy = readBuffer.count
            }
            
            lastFrame!.data = readBuffer.subdata(in: 0 ..< tocopy)
            readBuffer.replaceSubrange(0 ..< tocopy, with: Data())
            //self.leastFrame!.left -= tocopy
            lastFrame!.left -= tocopy
            if lastFrame!.left == 0 {
                return (lastFrame,nil)
            }else {
                return (lastFrame,SmuxError.bodyNotFull)
            }
            
        }
        guard  readBuffer.count >= headerSize else {
            return (nil , SmuxError.noHead)
        }
        let h = readBuffer.subdata(in: 0 ..< headerSize) as rawHeader
        
        if h.Version() != kcp.version {
            return (nil , SmuxError.VerError)
        }
        
        var frame:Frame = Frame.init(h.cmd(), sid: h.StreamID())
        let length = h.Length()
        if length > 0 {
            if readBuffer.count >= headerSize + length {
                frame.data = readBuffer.subdata(in: headerSize ..< headerSize + length)
                
                //readBuffer.resetBytes(in: 0 ..< headerSize + length)
                readBuffer.replaceSubrange(0 ..< headerSize + length, with: Data())
                return (frame,nil)
            }else {
                //等待
                let left = headerSize + length - readBuffer.count
                Xcon.log("Session :\(frame.sid) left:\(left)", level: .Debug)
                frame.data = readBuffer.subdata(in: headerSize ..< readBuffer.count)
                readBuffer.replaceSubrange(0  ..< readBuffer.count, with: Data())
                frame.left = left
                return (frame, SmuxError.bodyNotFull)
            }
        }else {
            readBuffer.replaceSubrange(0 ..< headerSize,with:Data())
            return (frame, nil)
        }
        
    }
    
}

extension KcpStocket{
    //tun delegate
    func localAddress() ->String {
        if let tun = tun {
            return tun.localAddress()
        }
        return "local"
    }
    //when network changed,should call this
    func destoryTun() {
        if let tun = tun {
            tun.shutdownUDPSession()
            self.tun = nil
            ready = false
        }
    }
    func sendFin(_ sessionID:UInt32){
        let frame = Frame(cmdFIN,sid:sessionID)
        let data = frame.frameData()
        if let tun = tun {
            if let s = snappy {
                let newData = s.compress(data)
                tun.input(newData)
            }else {
                tun.input(data)
            }
            
        }
    }

    public  func writeData(_ data: Data, withTag: Int) {
        
        // api
        self.lastActive = Date()
        Xcon.log("write \(data as NSData)",level: .Debug)
        if let tun = tun ,ready == true{
            tun.input(data)
            
            if !sendbuffer.isEmpty {
                let buffer = sendbuffer
                tun.input(buffer)
                //可能浪费内存
                sendbuffer.removeAll(keepingCapacity: true)
            }
            
        }else {
            sendbuffer.append(data)
            Xcon.log("kcptun not ready ,data keep in send buffer", level: .Error)
        }
    }
    func keepAlive(timeOut:Int)  {
        //  q = DispatchQueue(label:"com.yarshure.keepalive")
        let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags.init(rawValue: 0), queue:dispatchQueue )
        dispatchQueue.async{
            let interval: Double = Double(timeOut)
            
            let delay = DispatchTime.now()
            
            //timer.schedule(deadline: delay, repeating: interval, leeway: .nanoseconds(0))
            timer.schedule(deadline: delay, repeating: interval, leeway: .nanoseconds(0))
            timer.setEventHandler {[unowned self] in
                
                if Date().timeIntervalSince(self.lastActive) > KcpStocket.SMuxTimeOut{
                    self.shutdown()
                }else {
                    self.sendNop(sid: 0)
                }
                //self.call(self.dispatch_timer)
            }
            timer.setCancelHandler {
                print("dispatch_timer cancel")
            }
            timer.resume()
            
        }
        self.dispatchTimer = timer
    }
    func sendNop(sid:UInt32){
        Xcon.log("send Nop \(sid)", level: .Debug)
        let frame = Frame(cmdNOP,sid:sid)
        let data = frame.frameData()
        //self.streams[0] = session
        if let s = snappy {
            let newData = s.compress(data)
            self.writeData(newData, withTag: 0)
        }else {
            self.writeData(data, withTag: 0)
        }
        
        
    }
    //tcp send read data need update?
    public func readDataWithTag( _ tag:Int){
        if let _ = tun {
            //tun.upDate()
        }
    }
    //new tcp stream income
    func incomingStream(_ sid:UInt32,session:Xcon) {
        guard let _ = tun else { return}
        Xcon.log("send SYN \(sid)", level: .Debug)
        self.streams[sid] = session
        //send SYN
        let frame = Frame(cmdSYN,sid:UInt32(sid))
        let fdata = frame.frameData()
        
        writeData(fdata, withTag: 0)
        
        KcpTunConnector.shared.didConnect(session)
        //        if let dispatchQueue = dispatchQueue {
        //            dispatchQueue.asyncAfter(deadline: .now() + .milliseconds(100)) {
        //                session.didConnect(self)
        //            }
        //        }
        
    }
   
}
