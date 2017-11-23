//
//  Socks5Adapter.swift
//  SFSocket
//
//  Created by 孔祥波 on 29/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import AxLogger
class Socks5Adapter: Adapter {
    var stage:SFSocks5Stage = .Auth
    var recvBuffer:Data?
    override func recv(_ data: Data) throws -> (Bool,Data) {
        
        Xcon.log("recv new data  \(data as NSData)",level: .Debug)
        if stage == .Auth {
            //ans 0500
            if recvBuffer == nil {
                recvBuffer = data
            }else {
                recvBuffer?.append(data)
            }
            
            
            guard var buffer = recvBuffer else {
                throw SFAdapterError.invalidSocksResp
            }
            Xcon.log(".Auth  respon buf \(buffer as NSData)",level: .Debug)
            let version : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: version, count: 1)
            
            let auth : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: auth, from: Range(1 ... 1))
            defer {
                version.deallocate(capacity: 1)
                auth.deallocate(capacity: 1)
            }
            if version.pointee == SOCKS_VERSION {
                
                //buffer
                if auth.pointee == 0x00 {
                    //no auth
                    if buffer.count > 2 {
                        buffer =  buffer.subdata(in: Range(2 ..< buffer.count))
                    }else {
                        recvBuffer = Data()
                    }
                    stage = .Bind
                    //Xcon.log("\(cIDString) recv .Auth respon and send Bind req",level: .Debug)
                    let sdata = sendBind()
                    return (false,sdata)
                }else if auth.pointee == 0x02 {
                    //user/password auth
                    if buffer.count > 2 {
                        buffer =  buffer.subdata(in: Range(2 ..< buffer.count))
                    }else {
                        recvBuffer = Data()
                    }
                    recvBuffer = nil
                    stage = .AuthSend
                    let sdata = sendUserAndPassword()
                    return (false,sdata)
                }else if auth.pointee == 0xff {
                    Xcon.log("socks5 client don't have auth type, need close",level: .Error)
                    throw SFAdapterError.invalidSocksAuth
                } else {
                    Xcon.log("socks5 auth type:\(auth.pointee) don't support, need close",level: .Error)
                    throw SFAdapterError.invalidSocksResp
                }
                
            }else {
                Xcon.log("socks5 client don't recv  respon ver error ver:\(version.pointee)",level: .Debug)
                throw SFAdapterError.invalidSocksResp
                
            }
            
        }else if stage == .AuthSend {
            
            if recvBuffer == nil {
                recvBuffer = Data()
            }
            recvBuffer?.append(data)
            //05020004 00000000 0000
            
            
            guard var buffer = recvBuffer else {
                throw SFAdapterError.invalidSocksResp
            }
            Xcon.log(" .AuthSend   respon buf \(buffer as NSData )",level: .Debug)
            /*
             recvBuffer = nil
             
             sendBind()
             
             stage = .Bind
             return //Data 为nil 是什么bug?,被系统reset 了吗？
             */
            let version : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: version, count: 1)
            
            let result : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: result, from: 1..<2)
            defer {
                version.deallocate(capacity: 1)
                result.deallocate(capacity: 1)
            }
            if version.pointee == SOCKS_AUTH_VERSION && result.pointee == SOCKS_AUTH_SUCCESS {
                if buffer.count > 2 {
                    buffer = buffer.subdata(in: Range(2 ..< buffer.count))
                }else {
                    recvBuffer = Data()
                }
                Xcon.log("  .Auth Success and send BIND CMD",level: .Warning)
                let sdata = sendBind()
                stage = .Bind
                return (false,sdata)
            }else {
                Xcon.log("socks5 client  .Auth failure",level: .Warning)
                throw SFAdapterError.invalidSocksResp
            }
            
        }else if stage == .Bind {
            if recvBuffer == nil {
                recvBuffer = Data()
            }
            recvBuffer?.append(data)
            
            //05000001 c0a80251 c4bf
            guard let buffer = recvBuffer else {
                throw SFAdapterError.invalidSocksResp
            }
            Xcon.log(".Bind  respon buf \(buffer as NSData)",level: .Debug)
            let version : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: version, count: 1)
            
            let result : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: result, from: Range(1 ... 1))
            defer {
                version.deallocate(capacity: 1)
                result.deallocate(capacity: 1)
            }
            if version.pointee == SOCKS_VERSION && result.pointee == 0x00 {
                
                //buffer
                let reserved: UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                buffer.copyBytes(to: reserved, from: Range(2 ... 2))
                
                let type: UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                buffer.copyBytes(to: type, from: Range(3...3))
                if type.pointee == 1 {
                    let ip: UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
                    buffer.copyBytes(to: ip, from: Range(4 ... 7))
                    
                    let port: UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
                    defer {
                        ip.deallocate(capacity: 4)
                        port.deallocate(capacity: 2)
                    }
                    buffer.copyBytes(to: port, from: Range(8 ..< 10))
                    //Xcon.log("\(cIDString) Bind respond \(ip.pointee):\(port.pointee)",level: .Debug)
                    if buffer.count > 10  {
                        recvBuffer = buffer.subdata(in: Range(10 ..<  buffer.count))
                    }else {
                        recvBuffer = nil
                    }
                   
                }else if type.pointee == SOCKS_DOMAIN  {
                    let length: UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                    buffer.copyBytes(to: length, from: Range(4 ..< 5))
                    _ = buffer.subdata(in: Range(5 ..< 5 +  Int(length.pointee)))
                    let port: UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
                    defer {
                        length.deallocate(capacity: 1)
                        port.deallocate(capacity: 1)
                    }
                    buffer.copyBytes(to: port, from: Range(5+Int(length.pointee) ..< 7+Int(length.pointee)))
                    //Xcon.log("\(cIDString) Bind respond domain name length:\(length.pointee) \(domainname):\(port.pointee)",level: .Debug)
                    let len = 5+Int(length.pointee) + 2
                    if buffer.count >  len {
                        recvBuffer = buffer.subdata(in: Range(len ..< buffer.count ))
                    }else {
                        recvBuffer = nil
                    }
                    
                }else if type.pointee == SOCKS_IPV6 {
                    
                    Xcon.log(" Bind respond ipv6 currnetly don't support",level:.Error)
                    throw SFAdapterError.invalidSocksResp
                }
                
                stage = .Connected
                
                
                
            }else {
                Xcon.log("don't recv .Bind respon",level: .Debug)
            }
          
        }else if stage == .Connected {
            
                if let buffer = self.recvBuffer  {
                    self.recvBuffer!.append(data)
                    //copy data
                    let result = buffer
                    self.recvBuffer = nil
                    return (true,result)
                }else {
                    return (true,data)
                    
                }
            
            
            
        }
        fatalError()
    }
    func sendAuth() ->Data{
        var buffer = Data() //req 050100
        buffer.append(SOCKS_VERSION)
        
        if proxy.method.isEmpty && proxy.password.isEmpty {
            let authCount:UInt8 = 0x01 //支持认证
            buffer.append(authCount)
            let auth:UInt8 = 0x00
            buffer.append(auth)
        }else {
            let authCount:UInt8 = 0x02 //支持认证
            buffer.append(authCount)
            let auth:UInt8 = 0x00
            buffer.append(auth)
            let authup:UInt8 = 0x02
            buffer.append(authup)
            
        }
        
        Xcon.log("send  .Auth req \(buffer as NSData)",level:.Debug)
        return buffer
    }
    func sendUserAndPassword() ->Data{
        var buffer = Data()
        //buffer.write(SOCKS_VERSION)
        let auth:UInt8 = 0x01
        buffer.append(auth) //auth version
        var len:UInt8 = UInt8(proxy.method.count)
        buffer.append(len)
        buffer.append(proxy.method.data(using: .utf8)!)
        len = UInt8(proxy.password.count)
        buffer.append(len)
        buffer.append(proxy.password.data(using: .utf8)!)
        Xcon.log("send  .Auth req \(buffer as NSData)",level:.Debug)
        return buffer
    }
    func sendBind() ->Data{
        //req 050100030F6170692E747769747465722E636F6D01BB
        let buffer = SFData() //req 050100
        buffer.append(SOCKS_VERSION)
        let connect:UInt8 = 0x01
        buffer.append(connect)
        
        let reserved:UInt8 = 0x00
        buffer.append(reserved)
        let  request_atyp:SOCKS5HostType = targetHost.validateIpAddr()
        if  request_atyp == .IPV4{
            //ip
            
            buffer.append(SOCKS_IPV4)
            let i :UInt32 = inet_addr(targetHost.cString(using: .utf8))
            buffer.append(i)
            buffer.append(targetPort.byteSwapped)
        }else if request_atyp == .DOMAIN {
            //domain name
            
            buffer.append(SOCKS_DOMAIN)
            let name_len = targetHost.count
            buffer.append(UInt8(name_len))
            buffer.append(targetHost.data(using: .utf8)!)
            buffer.append(targetPort.byteSwapped)
        }else  if request_atyp == .IPV6 {
            buffer.append(SOCKS_IPV6)
            if let data =  toIPv6Addr(ipString: targetHost) {
                
                
                Xcon.log("convert \(targetHost) to Data:\(data)",level: .Info)
                buffer.append(data)
                //buffer.append(targetPort.byteSwapped)
            }else {
                Xcon.log("convert \(targetHost) to in6_addr error )",level: .Warning)
                fatalError()
            }
            
        }
        
        Xcon.log("send  .Bind req \(buffer.data as NSData)",level: .Debug)
        return buffer.data
    }
    override func send(_ data: Data) -> Data {
        if data.count == 0 {
            if stage == .Auth {
                return sendAuth()
            }else {
                print("############### error")
                return Data()
            }
        }else {
            return data
        }
        
    }
    
    //控制是否进入streaming 模式
    override var streaming:Bool{
        get {
            if stage == .Connected {
                return true
            }else {
               return false
            }
            
        }
    }
}
