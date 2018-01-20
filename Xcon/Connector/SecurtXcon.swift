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
    func checkStatus(status:OSStatus) {
        if status != 0{
            print("\(status)")
        }
    }
    public override func didConnectWith(adapterSocket: SocketProtocol) {
        Xcon.log("didConnectWith", level: .Info)
        
        //
        connector?.readDataWithTag(handShakeTag)
        //异步的
        
//        tempq.async {
//            self.configTLS()
//        }
        
        //
        //self.delegate?.didConnect(self)
    }
    public override func didRead(data: Data, from: SocketProtocol) {
        Xcon.log("read didRead \(data as NSData)", level: .Info)
        
        readBuffer.append(data)
        var buffer:Data = Data.init(capacity: 4096)
        var result:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            result.deallocate(capacity: 1)
        }
        _ = buffer.withUnsafeMutableBytes { ptr  in
            SSLRead(ctx, ptr , 4096,   result)
        }
        if result.pointee > 0 {
            buffer.count = result.pointee
            self.delegate?.didReadData(data, withTag: 0, from: self)
        }else {
            Xcon.log("ssl read no data,continue read", level: .Notify)
            connector?.readDataWithTag(0)
        }
//        var result:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
//        defer {
//            result.deallocate(capacity: 1)
//        }
//        let buffer:UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(bytes: 8096, alignedTo: 1)
//        SSLRead(ctx, buffer, 8096, result)
//
//        if result.pointee > 0 {
//            let d = NSData.init(bytesNoCopy: buffer, length: result.pointee)
//            self.delegate?.didReadData((d as Data), withTag: 0, from: self)
//        }
        
        
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
            let sid:UInt32 = c.assumingMemoryBound(to: UInt32.self).pointee
            let socketfd = SecurtXconHelper.helper.list[sid]!
            
            
            let bytesRequested = len.pointee
            
            // Read the data from the socket...
            if socketfd.readBuffer.isEmpty {
                //无数据
                Xcon.log("no data", level: .Info)
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
            let socketfd:UInt32 = c.assumingMemoryBound(to: UInt32.self).pointee
            let con = SecurtXconHelper.helper.list[socketfd]
            let responseDatagram = NSData(bytes: data, length: len.pointee)
            con!.writeRawData(responseDatagram as Data, tag: 0)
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
        status = SSLSetSessionOption(ctx, SSLSessionOption.breakOnClientAuth, true)
        checkStatus(status: status)
        
        //SSLSetCertificate
        
        repeat {
            status = SSLHandshake(self.ctx);
            Xcon.log("SSLHandshake...", level: .Info)
        }while(status == errSSLWouldBlock)
        self.handShanked = true
        self.queue.async {
            self.delegate?.didConnect(self)
        }
        
        Xcon.log("SSLHandshake...Finished ", level: .Info)
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
        super.writeData(data, withTag: tag)
    }
    func readRawData(_ data:Data, tag:Int){
        
    }
    
    
    
    
    
    func sslOutPut(data: Data,len:Int){
        //let temp = Data.init(bytes: data, count: len)
        connector?.writeData(data, withTag: handShakeTag)
        //self.writeBuffer.removeAll(keepingCapacity: true)
    }
    func sslIntPut(){
        
    }
    
    
    
}



///
/// SSL Read Callback
///
/// - Parameters:
///        - connection:    The connection to read from (contains pointer to active Socket object).
///        - data:            The area for the returned data.
///        - dataLength:    The amount of data to read.
///
/// - Returns:            The `OSStatus` reflecting the result of the call.
///
private func sslReadCallback(connection: SSLConnectionRef, data: UnsafeMutableRawPointer, dataLength: UnsafeMutablePointer<Int>) -> OSStatus {
    
    // Extract the socket file descriptor from the context...
    let socketfd:SecurtXcon = connection.assumingMemoryBound(to: SecurtXcon.self).pointee
    
    // Now the bytes to read...
    let bytesRequested = dataLength.pointee
    
    // Read the data from the socket...
    if socketfd.readBuffer.isEmpty {
        //无数据
        dataLength.initialize(to: 0)
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
        
        dataLength.initialize(to: toRead)
        
        
        if bytesRequested > toRead {
            
            return OSStatus(errSSLWouldBlock)
            
        } else {
            
            return noErr
        }
    }

}

///
/// SSL Write Callback
///
/// - Parameters:
///        - connection:    The connection to write to (contains pointer to active Socket object).
///        - data:            The data to be written.
///        - dataLength:    The amount of data to be written.
///
/// - Returns:            The `OSStatus` reflecting the result of the call.
///
private func sslWriteCallback(connection: SSLConnectionRef, data: UnsafeRawPointer, dataLength: UnsafeMutablePointer<Int>) -> OSStatus {
    
    // Extract the socket file descriptor from the context...
    let socketfd:SecurtXcon = connection.assumingMemoryBound(to: SecurtXcon.self).pointee
    
    // Now the bytes to read...
    let bytesToWrite = dataLength.pointee
    
    //let temp = Data.init(bytes: data, count: bytesToWrite)
//    var temp = Data.init(count: bytesToWrite)
//    temp.withUnsafeMutableBytes { (ptr:UnsafeMutableRawPointer)  in
//        memcpy(ptr, data, bytesToWrite)
//    }
//    var pointer = UnsafeMutableRawPointer.allocate(bytes: bytesToWrite, alignedTo: MemoryLayout<UInt8>.alignment)
//    memcpy(pointer, data, bytesToWrite)
//
//    let typedPointer1 = pointer.bindMemory(to: UInt8.self, capacity: bytesToWrite)
//
//    let temp  = Data.init(buffer: <#T##UnsafeBufferPointer<SourceType>#>)
    let responseDatagram = NSData(bytes: data, length: bytesToWrite)
    
    socketfd.test("")
   // memcpy(UnsafeMutableRawPointer!, UnsafeRawPointer!, <#T##__n: Int##Int#>)
    //socketfd.writeBuffer.append(temp)
//    socketfd.queue.async {
//       
//    }
    
    //socketfd.writeBuffer.append(responseDatagram as Data)
     //socketfd.sslOutPut(data: responseDatagram  as Data, len: bytesToWrite)
    
    return noErr
    

}
