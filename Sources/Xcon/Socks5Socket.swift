//
//  ProxyConnectorSOCKS5.swift
//  SimpleTunnel
//
//  Created by yarshure on 15/11/11.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import AxLogger
import XFoundation
//public enum SFSocks5Stage:Int8,CustomStringConvertible{
//    case Auth = 0
//    case AuthSend = 2
//    case Bind = 1
//    case Connected = 5
//    public var description: String {
//        switch self {
//        case .Auth :return "Auth"
//        case .AuthSend: return "AuthSend"
//        case .Bind: return "Bind"
//        case .Connected: return "Connected"
//        }
//    }
//}

//
//
// 050000010000000001BB
import XSocket
public class Socks5Connector:ProxyConnector{
//    var host:String?
//    var port:UInt16 = 0
    var stage:SFSocks5Stage = .Auth
    var recvBuffer:Data?
    static var  ReadTag:Int = -3000
    static func connect(_ target: String, port: UInt16,p:SFProxy, delegate: SocketDelegate, queue: DispatchQueue)  -> Socks5Connector {
        let c:Socks5Connector = Socks5Connector.init(target, port: port, p: p, delegate: delegate, queue: queue)
        

        return c
    }
    
    func sendAuth(){
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
        
        Xcon.log("\(cIDString) send  .Auth req \(buffer as NSData)",level:.Debug)
        self.writeData(buffer,withTag: Socks5Connector.ReadTag)
    }
    func sendUserAndPassword(){
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
        Xcon.log("\(cIDString) send  .Auth req \(buffer as NSData)",level:.Debug)
        self.writeData( buffer, withTag: Socks5Connector.ReadTag)
        
    }
    func sendBind(){
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
                
             
                Xcon.log("\(cIDString) convert \(targetHost) to Data:\(data)",level: .Info)
                buffer.append(data)
                //buffer.append(targetPort.byteSwapped)
            }else {
                Xcon.log("\(cIDString) convert \(targetHost) to in6_addr error )",level: .Warning)
                return
            }
            
        }
    
        Xcon.log("\(cIDString) send  .Bind req \(buffer.data as NSData)",level: .Debug)
        self.writeData(buffer.data, withTag: Socks5Connector.ReadTag)
    }
     func socketConnectd(){
         if stage == .Auth {
            sendAuth()
         }else {
           self.socketdelegate?.didConnectWith(adapterSocket: self)
        }
        
    }
    

     func readCallback(data: Data?, tag: Int) {
        
        guard let data = data else {
            Xcon.log("\(cIDString) read nil", level: .Debug)
            return
        }
        Xcon.log("\(cIDString) recv new data  \(data as NSData)",level: .Debug)
        if stage == .Auth {
            //ans 0500
            if recvBuffer == nil {
                recvBuffer = data
            }else {
                recvBuffer?.append(data)
            }
            
           
            guard var buffer = recvBuffer else {return }
            Xcon.log("\(cIDString)  .Auth  respon buf \(buffer as NSData)",level: .Debug)
            let version : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: version, count: 1)
            
            let auth : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: auth, from: Range(1 ... 1))
            if version.pointee == SOCKS_VERSION {
                
                //buffer
                if auth.pointee == 0x00 {
                    //no auth
                    if buffer.count > 2 {
                        buffer =  buffer.subdata(in: 2 ..< buffer.count)
                    }else {
                        recvBuffer = Data()
                    }
                    stage = .Bind
                   //XCon.log("\(cIDString) recv .Auth respon and send Bind req",level: .Debug)
                    sendBind()
                }else if auth.pointee == 0x02 {
                    //user/password auth
                    if buffer.count > 2 {
                        //TODO: test 
                        buffer =  buffer.subdata(in: 2 ..< buffer.count)
                    }else {
                        recvBuffer = Data()
                    }
                    recvBuffer = nil
                    stage = .AuthSend
                    sendUserAndPassword()
                }else if auth.pointee == 0xff {
                    Xcon.log("socks5 client don't have auth type, need close",level: .Error)
                    //self.forceDisconnect()
                } else {
                    Xcon.log("socks5 auth type:\(auth.pointee) don't support, need close",level: .Error)
                    //self.forceDisconnect()
                }
                
            }else {
               Xcon.log("socks5 client don't recv  respon ver error ver:\(version.pointee)",level: .Debug)
            }
            version.deallocate()
            auth.deallocate()
        }else if stage == .AuthSend {
            
            if recvBuffer == nil {
                recvBuffer = Data()
            }
            recvBuffer?.append(data)
            //05020004 00000000 0000
            
           
            guard var buffer = recvBuffer else {return }
            Xcon.log("\(cIDString)  .AuthSend   respon buf \(buffer as NSData )",level: .Debug)
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
            
            if version.pointee == SOCKS_AUTH_VERSION && result.pointee == SOCKS_AUTH_SUCCESS {
                if buffer.count > 2 {
                    buffer = buffer.subdata(in: 2 ..< buffer.count)
                }else {
                    recvBuffer = Data()
                }
               Xcon.log("\(cIDString)  .Auth Success and send BIND CMD",level: .Warning)
                sendBind()
                stage = .Bind
            }else {
                Xcon.log("socks5 client  .Auth failure",level: .Warning)
                self.disconnect(becauseOf: nil)
            }
            version.deallocate()
            result.deallocate()
        }else if stage == .Bind {
            if recvBuffer == nil {
                recvBuffer = Data()
            }
            recvBuffer?.append(data)
           
            //05000001 c0a80251 c4bf
            guard let buffer = recvBuffer else {return }
            Xcon.log("\(cIDString)  .Bind  respon buf \(buffer as NSData)",level: .Debug)
            let version : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: version, count: 1)
            
            let result : UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            buffer.copyBytes(to: result, from: Range(1 ... 1))
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
                    buffer.copyBytes(to: port, from: 8 ..< 10)
                   //XCon.log("\(cIDString) Bind respond \(ip.pointee):\(port.pointee)",level: .Debug)
                    if buffer.count > 10  {
                        recvBuffer = buffer.subdata(in: 10 ..<  buffer.count)
                    }else {
                        recvBuffer = nil
                    }
                    ip.deallocate( )
                    port.deallocate( )
                }else if type.pointee == SOCKS_DOMAIN  {
                    let length: UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                    buffer.copyBytes(to: length, from: 4 ..< 5)
                    _ = buffer.subdata(in: 5 ..< 5 +  Int(length.pointee))
                    let port: UnsafeMutablePointer<UInt8> =  UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
                    buffer.copyBytes(to: port, from: 5+Int(length.pointee) ..< 7+Int(length.pointee))
                   //XCon.log("\(cIDString) Bind respond domain name length:\(length.pointee) \(domainname):\(port.pointee)",level: .Debug)
                    let len = 5+Int(length.pointee) + 2
                    if buffer.count >  len {
                        recvBuffer = buffer.subdata(in: len ..< buffer.count )
                    }else {
                        recvBuffer = nil
                    }
                    length.deallocate( )
                    port.deallocate( )
                }else if type.pointee == SOCKS_IPV6 {
                    Xcon.log("\(cIDString) Bind respond ipv6 currnetly don't support",level:.Error)
                }
                
                stage = .Connected
               
                sock5connected()
                reserved.deallocate( )
                type.deallocate()
            }else {
               Xcon.log("\(cIDString) don't recv .Bind respon",level: .Debug)
            }
            version.deallocate( )
            result.deallocate()
        }else if stage == .Connected {
//            queueCall {
//                if let buffer = self.recvBuffer  {
//                    self.recvBuffer!.append(data)
//                    if let d = self.delegate {
//                        //d.connector(self, didReadData: buffer, withTag: Int64(tag))
//                        autoreleasepool(invoking: {
//                             d.didReadData(buffer, withTag: tag, from: self)
//                        })
//                       
//                    }
//                    
//                    self.recvBuffer = nil
//                }else {
//                    if let d = self.delegate {
//                        autoreleasepool(invoking: {
//                            d.didReadData( data, withTag: tag, from: self)
//                        })
//                        //d.connector(self, didReadData: data, withTag: Int64(tag))
//                        
//                    }
//                    
//                    
//                }
//            }

            
        }
    }
    func sock5connected(){
        if let d = socketdelegate {
            //d.connectorDidBecomeAvailable(self)
           d.didConnectWith(adapterSocket: self)
        }
        
    }
    
    public  func sendData(data: Data, withTag tag: Int) {
//        if writePending {
//            XCon.log("Socket-\(cID) writePending error", level: .Debug)
//            return
//        }
//        writePending = true
//        if isConnected == false {
//            XCon.log("Socket-\(cID)  isConnected error", level: .Error)
//            return
//        }
//        self.connection!.write(data) {[weak self] error in
//            guard let strong = self else  {return}
//            strong.writePending = false
//
//            guard error == nil else {
//                XCon.log("  NWTCPSocket got an error when writing data: \(error!.localizedDescription)",level: .Debug)
//                strong.forceDisconnect()
//                return
//            }
//
//            strong.queueCall {
//                if strong.stage != .Connected {
//                    strong.readDataWithTag(Socks5Connector.ReadTag)
//                }else {
//                    strong.queueCall { autoreleasepool {
//                        strong.delegate?.didWriteData(data, withTag: tag, from: strong)
//                        }}
//
//                }
//
//            }
//            strong.checkStatus()
//        }
    }

    public override func start() {
        tlsSupport = proxy.tlsEnable
        super.start()
    }

}
