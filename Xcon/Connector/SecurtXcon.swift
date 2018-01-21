//
//  SecurtXcon.swift
//  Xcon
//
//  Created by yarshure on 15/01/2018.
//  Copyright © 2018 yarshure. All rights reserved.
//

import Foundation
import Security
class SecurtXconHelper {
    static let helper = SecurtXconHelper()
    var list:[UInt32:SecurtXcon] = [:]
    func getXcon(_ key:UInt32) ->SecurtXcon {
        return list[3]!
    }
}
public class SecurtXcon: Xcon {
    var ctx:SSLContext!
    var certState:SSLClientCertificateState!
    var negCipher:SSLCipherSuite!
    var negVersion:SSLProtocol!
    let handShakeTag:Int = -3000
    var handShanked:Bool = false
    
    var readBuffer:Data = Data() //recv from socket
    var writeBuffer:Data = Data() //prepare write to  socket
    public let tempq = DispatchQueue.init(label: "tls.queue")
    
    func test(_ msg:String){
        print(msg)
    }
    public override func didDisconnectWith(socket: SocketProtocol) {
        Xcon.log("didDisconnectWith", level: .Info)
        if readBuffer.isEmpty {
            self.delegate?.didDisconnect(self, error: nil)
        }else {
            Xcon.log("didDisconnectWith wait write data to ....", level: .Info)
        }
        
        
        
    }
    func checkStatus(status:OSStatus) {
        if status != 0{
            if let str =  SecCopyErrorMessageString(status, nil) {
                 Xcon.log("\(status):" +  (str as String),level: .Info)
            }
        }
    }
    func showState() ->SSLSessionState  {
        var state:SSLSessionState = SSLSessionState.init(rawValue: 0)!
        SSLGetSessionState(self.ctx, &state)
        Xcon.log("SSLHandshake...state:" + state.description, level: .Info)
        return state
       
    }
    public override func didConnectWith(adapterSocket: SocketProtocol) {
        Xcon.log("didConnectWith", level: .Info)

        if !handShanked{
            testTLS()
        }
        //connector?.readDataWithTag(handShakeTag)
    }
    public override func didRead(data: Data, from: SocketProtocol) {
        Xcon.log("socket didRead count:\(data.count) \(data as NSData)", level: .Info)
        //handshake auto read/write
        if handShanked {
             self.readBuffer.append(data)
            
            var result:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
            defer {
                result.deallocate(capacity: 1)
            }
            
            var rtx:OSStatus = SSLGetBufferedReadSize(ctx, result)
            if rtx == 0 {
                var buffer:Data = Data.init(capacity: result.pointee)
                _ = buffer.withUnsafeMutableBytes { ptr  in
                    SSLRead(self.ctx, ptr , result.pointee,   result)
                }
                if result.pointee > 0 {
                    Xcon.log("TLS didRead \(buffer as NSData)", level: .Info)
                    buffer.count = result.pointee
                    
                    self.delegate?.didReadData(buffer, withTag: 0, from: self)
                }else {
                    Xcon.log("ssl read no data,continue read", level: .Notify)
                    
                }
                
            }
           connector?.readDataWithTag(10)
        }else {
            tempq.suspend()
            self.readBuffer.append(data)
            tempq.resume()
        }
        
//        //after handshake, normal read
//        connector?.readDataWithTag(handShakeTag)
//        if handShanked {
//            //dispatch
//            tempq.async {
//                
//            }
//            
//        }else {
//            Xcon.log("#########", level: .Notify)
//        }
//        
        
    }
    
    public override func didWrite(data: Data?, by: SocketProtocol) {
        
        
        if !handShanked {
            Xcon.log("didwrite reading...", level: .Info)
            connector?.readDataWithTag(handShakeTag);
        }else {
            
            delegate?.didWriteData(data, withTag: 0, from: self)
        }
       
        
    }
    public func testTLS(){
        tempq.async {
            self.configTLS()
        }
    }
    func readFunc() ->SSLReadFunc {
        return { c,data,len in
            Xcon.log("ReadFunc...\(len.pointee)", level: .Info)
            let sid:UInt32 = c.assumingMemoryBound(to: UInt32.self).pointee
            let  socketfd = SecurtXconHelper.helper.getXcon(sid)
            
            
            
            let bytesRequested = len.pointee
            
            // Read the data from the socket...
            if socketfd.readBuffer.isEmpty {
                //无数据
                Xcon.log("readFunc no data", level: .Debug)
                len.initialize(to: 0)
                return OSStatus(errSSLWouldBlock)
            }else {
                //
                var toRead:Int = 0
                if socketfd.readBuffer.count >= bytesRequested {
                    toRead = bytesRequested
                }else {
                    toRead = socketfd.readBuffer.count
                    
                }
                memcpy(data, (socketfd.readBuffer as NSData).bytes,toRead)
                socketfd.readBuffer.removeSubrange( 0..<toRead)
                Xcon.log("readbuffer left:\(socketfd.readBuffer.count)", level: .Info)
                len.initialize(to: toRead)
                
                
                if bytesRequested > toRead {
                    
                    return OSStatus(errSSLWouldBlock)
                    
                } else {
                    
                    return noErr
                }
            }
        }
    }
    func writeFunc() ->SSLWriteFunc {
        return { c,data,len in
            //            let socketfd:SecurtXcon = c.assumingMemoryBound(to: SecurtXcon.self).pointee
            //            socketfd.test()
            Xcon.log("writeFunc...", level: .Info)
            let socketfd:UInt32 = c.assumingMemoryBound(to: UInt32.self).pointee
            let con = SecurtXconHelper.helper.getXcon(socketfd)
            let responseDatagram = NSData(bytes: data, length: len.pointee)
            con.writeRawData(responseDatagram as Data, tag: 0)
            //con!.test("write")
            return 0
            
        }
    }
    public func configTLS(){
        
        SecurtXconHelper.helper.list[self.sessionID] = self
        ctx = SSLCreateContext(kCFAllocatorDefault, .clientSide, .streamType)
        var status: OSStatus
        //var
        // Now prepare it...
        //    - Setup our read and write callbacks...
        
        status = SSLSetIOFuncs(ctx, readFunc(), writeFunc())
        
        checkStatus(status: status)
        
        //SSLSetConnection(ctx, UnsafePointer(.toOpaque()))
        //UnsafePointer(Unmanaged.passUnretained(self).toOpaque())
        status = SSLSetConnection(ctx, &sessionID)
        checkStatus(status: status)
        status = SSLSetPeerDomainName(ctx, remoteAddress, remoteAddress.count)
        //status = SSLSetSessionOption(ctx, SSLSessionOption.breakOnClientAuth, true)
        checkStatus(status: status)
        status = SSLSetProtocolVersionMin(ctx, SSLProtocol.tlsProtocol1)
        status = SSLSetProtocolVersionMax(ctx, SSLProtocol.tlsProtocol13)
        var numSupported:Int = 0
        status = SSLGetNumberEnabledCiphers(ctx, &numSupported)
        print("enabled ciphers count \(numSupported)")
        checkStatus(status: status)
//        let supported:UnsafeMutablePointer<SSLCipherSuite> = UnsafeMutablePointer<SSLCipherSuite>.allocate(capacity: numSupported)
//        status = SSLGetSupportedCiphers(ctx, supported, &numSupported)
//        checkStatus(status: status)
//
//        let enabled:UnsafeMutablePointer<SSLCipherSuite> = UnsafeMutablePointer<SSLCipherSuite>.allocate(capacity: numSupported)
//        enabled.initialize(from: supported, count: numSupported)
////        for x in 0..<numSupported {
////           tmp.pointee = supported.pointee
////           supported = supported.advanced(by: 1)
////        }
//        status =  SSLSetEnabledCiphers(ctx, enabled, numSupported)
//        checkStatus(status: status)
       
        status = SSLSetSessionOption(ctx, SSLSessionOption.breakOnClientAuth, true)
        checkStatus(status: status)
        Xcon.log("begin SSLHandshake...", level: .Info)
        repeat {
            status = SSLHandshake(self.ctx);
            //_ = showState()
            //checkStatus(status: status)
            //Xcon.log("readbuffer left:\(self.readBuffer.count)", level: .Info)
            
            usleep(500)
        }while(status == errSSLWouldBlock)
    
        //Handshake complete, ready for normal I/O
        if showState() == .connected {
            self.handShanked = true
            self.queue.async {
                self.delegate?.didConnect(self)
            }
            
        }else {
            Xcon.log("SSLHandshake...Finished  failure", level: .Info)
        }
        
        
        
    }
    
    override public func writeData(_ data: Data, withTag: Int) {
        //call TLS write
        Xcon.log("write data to tls \(data as NSData)", level: .Info)
        var result:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            result.deallocate(capacity: 1)
        }
        SSLWrite(self.ctx, (data as NSData).bytes, data.count,result )
        print(result.pointee)
        
    }
 
    ///for TLS
    
    func writeRawData(_ data:Data, tag:Int){
        //给外部API 使用
        Xcon.log("write data to remote \(data as NSData)", level: .Info)
        super.writeData(data, withTag: tag)
    }
    func readRawData(_ data:Data, tag:Int){
        
    }
    deinit {
        SSLClose(ctx)
    }

}




