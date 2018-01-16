//
//  SecurtXcon.swift
//  Xcon
//
//  Created by yarshure on 15/01/2018.
//  Copyright © 2018 yarshure. All rights reserved.
//

import Foundation
import Security
public class SecurtXcon: Xcon {
    var ctx:SSLContext!
    var certState:SSLClientCertificateState!
    var negCipher:SSLCipherSuite!
    var negVersion:SSLProtocol!
    let handShakeTag:Int = -3000
    var handShanked:Bool = false
    
    
    var readBuffer:Data = Data() //recv from socket
    var writeBuffer:Data = Data() //prepare write to  socket
    let tempq = DispatchQueue.init(label: "tls.queue")
    init(q: DispatchQueue ,host:String,port:Int) {
        super.init(q: q)
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
        
        tempq.async {
            self.configTLS()
        }
        
        //
        //self.delegate?.didConnect(self)
    }
    public override func didRead(data: Data, from: SocketProtocol) {
        Xcon.log("read didRead", level: .Info)
        
        readBuffer.append(data)
        
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
        
        Xcon.log("didwrite ", level: .Info)
        
        //self.delegate?.didWriteData(data, withTag: 0, from: self)
        
    }
    func configTLS(){
        ctx = SSLCreateContext(kCFAllocatorDefault, .clientSide, .streamType)
        var status: OSStatus
        //var
        // Now prepare it...
        //    - Setup our read and write callbacks...
        status = SSLSetIOFuncs(ctx, sslReadCallback, sslWriteCallback)
        checkStatus(status: status)
        let x = Unmanaged.passUnretained(self)
        
        //SSLSetConnection(ctx, UnsafePointer(.toOpaque()))
        status = SSLSetConnection(ctx, x.toOpaque())
        checkStatus(status: status)
        status = SSLSetSessionOption(ctx, SSLSessionOption.breakOnClientAuth, true)
        checkStatus(status: status)
        
        //SSLSetCertificate
        repeat {status = SSLHandshake(ctx);}
            while(status == errSSLWouldBlock);
        handShanked = true
    }
    
    override public func writeData(_ data: Data, withTag: Int) {
        //call TLS write
        var result:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            result.deallocate(capacity: 1)
        }
        //给外部API 使用
        if handShanked {
            SSLWrite(self.ctx, (data as NSData).bytes, data.count,result )
        }else {
            fatalError("error")
        }
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
    
   // memcpy(UnsafeMutableRawPointer!, UnsafeRawPointer!, <#T##__n: Int##Int#>)
    //socketfd.writeBuffer.append(temp)
//    socketfd.queue.async {
//       
//    }
    
    socketfd.writeBuffer.append(responseDatagram as Data)
     //socketfd.sslOutPut(data: responseDatagram  as Data, len: bytesToWrite)
    
    return noErr
    

}
