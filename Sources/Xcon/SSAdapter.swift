///Users/yarshure/Xcon/Carthage/Build/iOS/kcp.framework
//  SSAdapter.swift
//  SFSocket
//
//  Created by 孔祥波 on 27/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import AxLogger
import XFoundation
class SSAdapter:Adapter {
    var engine:SSEncrypt
    var ota:Bool = false
    var headSent:Bool = false
    var tag:Int32 = 0
    override var streaming:Bool{
        get {
            return headSent
        }
    }
    override init(p: SFProxy, h: String, port: UInt16) {
        
        engine = SSEncrypt.init(password: p.password, method: p.method)
        super.init(p: p, h: h, port: port)
    }
    func buildHead() ->Data {
        let header = SFData()
        //NSLog("TCPSS %@:%d",targetHost,targetPort)
        //targetHost is ip or domain
        var addr_len = 0
        
        //        let  buf:bufferRef = bufferRef.alloc(1)
        //        balloc(buf,BUF_SIZE)
        let  request_atyp:SOCKS5HostType = realHost.validateIpAddr()
        
        if  request_atyp  == .IPV4{
            
            header.append(SOCKS_IPV4)
            addr_len += 1
            //Xcon.log("\(cIDString) target host use ip \(targetHost) ",level: .Debug)
            let i :UInt32 = inet_addr(realHost.cString(using: .utf8)!)
            header.append(i)
            header.append(realPort.byteSwapped)
            addr_len  +=  MemoryLayout<UInt32>.size + 2
            
        }else if request_atyp == .DOMAIN{
            
            header.append(SOCKS_DOMAIN)
            addr_len += 1
            let name_len = realHost.count
            header.append(UInt8(name_len))
            addr_len += 1
            header.append(realHost.data(using: .utf8)!)
            addr_len += name_len
            let x = realPort.byteSwapped
            //let v = UnsafeBufferPointer(start: &x, count: 2)
            header.append(x)
            addr_len += 2
        }else {
            //ipv6
            
            header.append(SOCKS_IPV6)
            addr_len += 1
            if let data =  toIPv6Addr(ipString: targetHost) {
                
                //not work
                //Xcon.log("\(cIDString) convert \(targetHost) to Data:\(data)",level: .Info)
                header.append(data)
                let x = targetPort.byteSwapped
                //let v = UnsafeBufferPointer(start: &x, count: 2)
                
                header.append(x)
                addr_len += 2
            }else {
                //Xcon.log("\(cIDString) convert \(targetHost) to in6_addr error )",level: .Warning)
                //return
            }
            //2001:0b28:f23f:f005:0000:0000:0000:000a
            //            let ptr:UnsafePointer<Int8> = UnsafePointer<Int8>.init(bitPattern: 32)
            //            let host:UnsafeMutablePointer<Int8> = UnsafeMutablePointer.init(targetHost.cStringUsingEncoding(NSUTF8StringEncoding)!)
            //            inet_pton(AF_INET6,ptr,host)
        }
        if ota {
//            atype |= ONETIMEAUTH_FLAG
//            //fixme
//            //header.replaceSubrange(Range( 0 ... 0), with: atype)
//            header.data.replaceSubrange(0 ..< 1, with: [atype])
//            let hash = engine.ss_onetimeauth(buffer: header.data)
//            header.append(hash)
//            Xcon.log("ota enabled", level: .Debug)
        }
        return header.data
        
        
    }
    override func recv(_ data: Data) throws -> (Bool,Data) {
        //crash here
        if let result = engine.decrypt(encrypt_bytes: data) {
            return (true,result)
        }else {
            return (false,Data())
        }
        
        
    }
    
    override func send(_ data: Data) -> (Data,Int) {
        var datatemp:Data?
        if !headSent {
            var temp = Data()
            let head = buildHead()
            Xcon.log("Adapter-SS: header: \(head as NSData) via \(targetHost):\(targetPort)", level: .Debug)
            temp.append(head)
            headSent = true
            if data.count > 0 {
                if ota {
                    let chunk = engine.ss_gen_hash(buffer: data, counter: Int32(tag))
                    temp.append(chunk)
                    temp.append(data)
                }else {
                    temp.append(data)
                }
            }
            
            
            datatemp = temp
            //Xcon.log("\(cIDString) will send \(head.length) \(head) ",level: .Trace)
        }else {
            if ota {
                
                let chunk = engine.ss_gen_hash(buffer: data, counter: Int32(tag))
                var temp = Data()
                temp.append( chunk)
                temp.append(data)
                datatemp = temp
            }else {
                datatemp = data
            }
            
        }
        
        if let dd = datatemp {
            if let cipher =  engine.encrypt(encrypt_bytes: dd) {
                //socks_writing = true
                return (cipher,-1)
            }
        }else {
            Xcon.log("encrypt init error or data length 0",level: .Error)
            fatalError()
            
        }
        return (Data(),-3000)
    }
}
