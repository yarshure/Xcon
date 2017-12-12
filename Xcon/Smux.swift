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
import Foundation
import NetworkExtension
import AxLogger
import kcp
//应该是shared
// 可以先不实行adapter，加密,用kun 加密
// 测试先是不加密，aes 加密， adapter 加密
// 重新链接 需要？
enum SmuxError:Error {
   
    case noHead
    case VerError
    case bodyNotFull
    case internalError
    case recvFin
    
}

class Smux: RAWUDPSocket ,SFKcpTunDelegate{
    
    //var adapter:Adapter! //ss/socks5/http obfs
    var proxy:SFProxy?
    
    var streams:[UInt32:TCPSession] = [:]
    
    static let SMuxTimeOut = 13.0 //没数据就timeout
    
    var tun:SFKcpTun?
    var snappy:SnappyHelper?
    //var channels:[Channel] = []
    var config:TunConfig = TunConfig()
    //var block:BlockCrypt!
    var smuxConfig:Config = Config()
    var ready:Bool = false
    var readBuffer:Data = Data()
    var dispatchTimer:DispatchSourceTimer?
    var dispatchQueue :DispatchQueue?
    var lastFrame:Frame? // not full frame ,需要快速把已经收到的data 给应用
    func shutdown(){
        if let t = dispatchTimer {
            t.cancel()
        }
        self.destoryTun()
    }
    //tun delegate
    func localAddress() ->String {
        if let tun = tun {
            return tun.localAddress()
        }
        return "local"
    }
    public func connected(_ tun: SFKcpTun!){
        
    }
    
    public func disConnected(_ tun: SFKcpTun!){
        
    }
    
    public func tunError(_ tun: SFKcpTun!, error: Error!){
        
    }
    
    func readFrame() -> (Frame?,SmuxError?) {
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
                SKit.log("Session :\(frame.sid) left:\(left)", level: .Debug)
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
    public func didRecevied(_ data: Data!){
        self.lastActive = Date()
        if let _ = proxy {
            if let  s = snappy {
                if let newData = s.decompress(data) {
                     self.readBuffer.append(newData)
                }
              
            }else {
                self.readBuffer.append(data)
            }
        }
        
        //SKit.log("mux recv data: \(data.count) \(data as NSData)",level: .Debug)
        let _ = streams.flatMap{ k,v in
            return k
        }
        //cpu high
        //SKit.log("\(ss.sorted()) all active stream", level: .Debug)
        while self.readBuffer.count >= headerSize {
            let r = readFrame()
            if let f = r.0 {
                if f.sid == 0 {
                     SKit.log("Nop Event recv", level: .Debug)
                }else {
                    if let stream =  streams[f.sid] {
                        
                        
                        
                        
                        
                        if let d = f.data {
                            if r.1 == nil {
                                //full packet
                                stream.didReadData(d, withTag: 0, from: self)
                                self.lastFrame = nil
                            }else {
                                //no full
                                if !d.isEmpty {
                                    stream.didReadData(d, withTag: 0, from: self)
                                }
                                
                                
                                
                                self.lastFrame = f
                                //reset data
                                self.lastFrame?.data = nil
                            }
                            
                        }else {
                            if f.cmd == cmdFIN {
                                stream.didDisconnect(self, error: SmuxError.recvFin)
                            }else  {
                                if r.1 == SmuxError.bodyNotFull {
                                    SKit.log("frame \(f.desc) packet not full",level: .Error)
                                    
                                    break
                                }
                            }
                            
                        }
                        
                    }else {
                       SKit.log("frame \(f.desc) not found stream drop packet",level: .Error)
                        
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
                SKit.log("buffer \(self.readBuffer as NSData) parser error",level: .Debug)
            }
        }
       
        
        
    }
    static var sharedTunnel: Smux = Smux()
    
    func updateProxy(_ proxy:SFProxy,queue:DispatchQueue){
        
        if ready {
            return
           // fatalError()
        }
        self.proxy = proxy
        if proxy.config.noComp {
            snappy = SnappyHelper()
        }
        dispatchQueue = queue
        let c = createTunConfig( proxy)
        
        self.tun = SFKcpTun.init(config: c, ipaddr: proxy.serverIP, port: Int32(proxy.serverPort)!, queue: queue)
        self.tun?.delegate = self as SFKcpTunDelegate
        self.keepAlive(timeOut: 10);
        self.ready = true
    }
    
    func keepAlive(timeOut:Int)  {
       //  q = DispatchQueue(label:"com.yarshure.keepalive")
        let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags.init(rawValue: 0), queue:dispatchQueue )
        queue.async{
            let interval: Double = Double(timeOut)
            
            let delay = DispatchTime.now()
            
            //timer.schedule(deadline: delay, repeating: interval, leeway: .nanoseconds(0))
            timer.schedule(deadline: delay, repeating: interval, leeway: .nanoseconds(0))
            timer.setEventHandler {[unowned self] in
                
                if Date().timeIntervalSince(self.lastActive) > Smux.SMuxTimeOut{
                    self.shutdown()
                }else {
                    self.sendNop()
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
    func sendNop(){
        SKit.log("send Nop", level: .Debug)
        let frame = Frame(cmdNOP,sid:0)
        let data = frame.frameData()
        //self.streams[0] = session
        if let p = proxy {
            if let s = snappy {
                let newData = s.compress(data)
                self.writeData(newData, withTag: 0)
            }else {
                self.writeData(data, withTag: 0)
            }
        }
        

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
        SKit.log("KCPTUN: #######################", level: .Info)
        SKit.log("KCPTUN: Crypto = \(p.config.crypt)", level: .Info)
        SKit.log("KCPTUN: key = \(c.key as NSData)", level: .Debug)

        if p.config.noComp {
            SKit.log("KCPTUN: compress = true", level: .Info)
        }else {
            SKit.log("KCPTUN: compress = false", level: .Info)
        }
        SKit.log("KCPTUN: mode = \(p.config.mode)", level: .Info)
        SKit.log("KCPTUN: datashard = \(p.config.datashard)", level: .Info)
        SKit.log("KCPTUN: parityshard = \(p.config.parityshard)", level: .Info)
        SKit.log("KCPTUN: #######################", level: .Info)
        return c
    }
    //new tcp stream income
    func incomingStream(_ sid:UInt32,session:TCPSession) {
        
        self.streams[sid] = session
//        if let dispatchQueue = dispatchQueue {
//            dispatchQueue.asyncAfter(deadline: .now() + .milliseconds(100)) {
//                session.didConnect(self)
//            }
//        }
       session.didConnect(self)
    }
    override var useCell:Bool{
        get {
            if let t = tun {
                t.useCell()
            }
            return false
        }
    }
    //when network changed,should call this
    func destoryTun() {
        if let tun = tun {
            tun.shutdownUDPSession()
            self.tun = nil
            ready = false
        }
    }
    //MARK: - socket
    override func socketConnectd(){
        // ss /kcptun don't need shakehand
        //tun ready
        //delegate?.didConnect(self)
        self.ready = true
    }
    
    func readCallback(data: Data?, tag: Int) {
        //sSelf.delegate?.didReadData(data, withTag: 0, from: sSelf)
        //tun.inputDataSocket(data!)
        //callback
    }
    
    
    public override func writeData(_ data: Data, withTag: Int) {
        //先经过ss
        //fatalError()
        //        guard let  adapter = Adapter else { return  }
        //        let newdata = adapter.send(data)
        //        tun.inputDataAdapter(newdata)
        // api
        self.lastActive = Date()
        SKit.log("write \(data as NSData)",level: .Debug)
        if let tun = tun {
            tun.input(data)
        }else {
            SKit.log("kcptun not ready ", level: .Error)
        }
    }
    func outputCallBackApapter(_ data:Data){
        super.writeData(data, withTag: 0)
    }
    func outputCallBackSocket(_ data:Data){
        delegate?.didReadData(data, withTag: 0, from: self)
    }
    // Remote server need close event?
    //MARK: -- tod close channel
    //only for kcptun
    //close ,remove tcp session
    public override func forceDisconnect(_ sessionID:UInt32){
        SKit.log("\(sessionID) forceDisconnect", level: .Debug)
        
        self.streams.removeValue(forKey: sessionID)
        sendFin(sessionID)
       
    }

    func sendFin(_ sessionID:UInt32){
        let frame = Frame(cmdFIN,sid:sessionID)
        let data = frame.frameData()
        if let tun = tun {
            if let _ = proxy {
                if let s = snappy {
                    let newData = s.compress(data)
                    tun.input(newData)
                }else {
                    tun.input(data)
                }
            }
            
        }
    }
    /**
     Connect to remote host.
     
     - parameter host:        Remote host.
     - parameter port:        Remote port.
     - parameter enableTLS:   Should TLS be enabled.
     - parameter tlsSettings: The settings of TLS.
     
     - throws: The error occured when connecting to host.
     */
    public override func connectTo(_ host: String, port: UInt16, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws{
        fatalError()
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        fatalError()
    }
    public func readDataWithTag( tag:Int){
        if let tun = tun {
            //tun.upDate()
        }
    }
}
