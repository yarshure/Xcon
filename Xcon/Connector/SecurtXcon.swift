//
//  SecurtXcon.swift
//  Xcon
//
//  Created by yarshure on 15/01/2018.
//  Copyright © 2018 yarshure. All rights reserved.
//

import Foundation
import Security
import DarwinCore

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
            Xcon.log("didDisconnectWith wait write data to ....\(readBuffer as NSData)", level: .Info)
        }
        
        
        
    }
    func check(_ status:OSStatus) {
        if status != 0{
            #if os(macOS)
            if let str =  SecCopyErrorMessageString(status, nil) {
                 Xcon.log("\(status):" +  (str as String),level: .Info)
            }
            #else
                let error = NSError.init(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
                Xcon.log("tls ctx status:\(error.localizedDescription):",level: .Info)
            #endif
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
        Xcon.log("socket didRead count:\(data.count) \(data as NSData)", level: .Debug)
        //handshake auto read/write
        if handShanked {
            self.readBuffer.append(data)
            tlsRead()
           connector?.readDataWithTag(10)
        }else {
            tempq.suspend()
            self.readBuffer.append(data)
            tempq.resume()
            connector?.readDataWithTag(handShakeTag)
        }
 
    }
    func tlsRead(){
        var status:OSStatus
        repeat {
            var result:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
            defer {
                result.deallocate(capacity: 1)
            }
            let  buff:UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(bytes: 4096, alignedTo: 1)
            status = SSLRead(self.ctx, buff , 4096,   result)
            check(status)
            if status == errSSLClosedGraceful {
                
                break
            }
            if result.pointee > 0 {
                let responseDatagram = NSData(bytes: buff, length: result.pointee)
                Xcon.log("TLS didRead \(responseDatagram)", level: .Debug)
                
                
                self.delegate?.didReadData(responseDatagram as Data, withTag: 0, from: self)
            }else {
                Xcon.log("ssl read no data,continue read", level: .Error)
                
            }
        }while(status != errSSLWouldBlock)
    }
    override public func didWrite(data: Data?, by: SocketProtocol) {
        
        
        if !handShanked {
            Xcon.log("didwrite reading...", level: .Debug)
            connector?.readDataWithTag(handShakeTag);
        }else {
            
            delegate?.didWriteData(data, withTag: 0, from: self)
        }
       
        
    }
    func testTLS(){
        tempq.async {
            self.configTLS()
        }
    }
    func readFunc() ->SSLReadFunc {
        return { c,data,len in
            Xcon.log("ReadFunc...\(len.pointee)", level: .Info)
            let unmanaged:Unmanaged<SecurtXcon>  =   Unmanaged.fromOpaque(c)
            let socketfd:SecurtXcon = unmanaged.takeUnretainedValue()
            
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
            let unmanaged:Unmanaged<SecurtXcon>  =   Unmanaged.fromOpaque(c)
            let con:SecurtXcon = unmanaged.takeUnretainedValue()
            let responseDatagram = NSData(bytes: data, length: len.pointee)
            con.writeRawData(responseDatagram as Data, tag: 0)
            //con!.test("write")
            return 0
            
        }
    }
    public func configTLS(){
        
        
        ctx = SSLCreateContext(kCFAllocatorDefault, .clientSide, .streamType)
        var status: OSStatus
        //var
        // Now prepare it...
        //    - Setup our read and write callbacks...
        
        status = SSLSetIOFuncs(ctx, readFunc(), writeFunc())
        
        check(status)
        
        status = SSLSetConnection(ctx, Unmanaged.passUnretained(self).toOpaque())
        check(status)
        status = SSLSetPeerDomainName(ctx, remoteAddress, remoteAddress.count)
        //status = SSLSetSessionOption(ctx, SSLSessionOption.breakOnClientAuth, true)
        check(status)
        status = SSLSetProtocolVersionMin(ctx, SSLProtocol.tlsProtocol1)
        status = SSLSetProtocolVersionMax(ctx, SSLProtocol.tlsProtocol13)
        var numSupported:Int = 0
        status = SSLGetNumberEnabledCiphers(ctx, &numSupported)
        print("enabled ciphers count \(numSupported)")
        check(status)
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
        check(status)
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
            let cert:UnsafeMutablePointer<SSLClientCertificateState> = UnsafeMutablePointer<SSLClientCertificateState>.allocate(capacity: 1)
            defer {
                cert.deallocate(capacity: 1)
            }
            
            status = SSLGetClientCertificateState(ctx, cert)
            check(status)
            
//            let trusts:UnsafeMutablePointer<SecTrust?> = UnsafeMutablePointer<SecTrust?>.allocate(capacity: 1)
//
//            defer {
//                trusts.deallocate(capacity: 1)
//            }
            var t:SecTrust?
            status =  SSLCopyPeerTrust(ctx, &t)
            check(status)
            self.queue.async {
                self.delegate?.didConnect(self,cert:t)
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

    deinit {
        SSLClose(ctx)
    }

}




