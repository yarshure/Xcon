//
//  TCPSSConnector.swift
//  SimpleTunnel
//
//  Created by 孔祥波 on 15/10/27.
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import AxLogger
import XSocket
import XFoundation
let  ONETIMEAUTH_FLAG:UInt8 = 0x10
public class  TCPSSConnector:ProxyConnector{
    //config_encryption(password, method);
    
    //var
    var aes:SSEncrypt!
    var ota:Bool = false
    var headSent:Bool = false
    //var auth:Bool = false
    
    deinit {
        Xcon.log("TCPSSConnector deinit", level: .Debug)
        //maybe crash
        
    }


    func buildHead() ->Data {
        let header = SFData()
        //NSLog("TCPSS %@:%d",targetHost,targetPort)
        //targetHost is ip or domain
        var addr_len = 0
        
//        let  buf:bufferRef = bufferRef.alloc(1)
//        balloc(buf,BUF_SIZE)
        let  request_atyp:SOCKS5HostType = targetHost.validateIpAddr()
        var atype:UInt8 = SOCKS_IPV4
        if  request_atyp  == .IPV4{
           
            header.append(SOCKS_IPV4)
            addr_len += 1
           //Xcon.log("\(cIDString) target host use ip \(targetHost) ",level: .Debug)
            let i :UInt32 = inet_addr(targetHost.cString(using: .utf8)!)
            header.append(i)
            header.append(targetPort.byteSwapped)
            addr_len  +=  MemoryLayout<UInt32>.size + 2
            
        }else if request_atyp == .DOMAIN{
            atype = SOCKS_DOMAIN
            header.append(SOCKS_DOMAIN)
            addr_len += 1
            let name_len = targetHost.count
            header.append(UInt8(name_len))
            addr_len += 1
            header.append(targetHost.data(using: .utf8)!)
            addr_len += name_len
            let x = targetPort.byteSwapped
            //let v = UnsafeBufferPointer(start: &x, count: 2)
            header.append(x)
            addr_len += 2
        }else {
            //ipv6
            atype = SOCKS_IPV6
            header.append(SOCKS_IPV6)
            addr_len += 1
            if let data =  toIPv6Addr(ipString: targetHost) {
                
                
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
            atype |= ONETIMEAUTH_FLAG
            //fixme
            //header.replaceSubrange(Range( 0 ... 0), with: atype)
            header.data.replaceSubrange(0 ..< 1, with: [atype])
            let hash = aes!.ss_onetimeauth(buffer: header.data)
            header.append(hash)
            Xcon.log("ota enabled", level: .Debug)
        }
        return header.data

        
    }
    

 
    override public func writeData(_ data: Data, withTag tag: Int) {
        
        var datatemp:Data?
        if !headSent {
            var temp = Data()
            let head = buildHead()
            Xcon.log(  "ss socket header:\(targetHost):\(targetPort) \(head )", level: .Debug)
            temp.append(head)
            headSent = true
            if ota {
                let chunk = aes!.ss_gen_hash(buffer: data, counter: Int32(tag))
                temp.append(chunk)
                temp.append(data)
            }else {
                temp.append(data)
            }
            
            datatemp = temp
            //Xcon.log("\(cIDString) will send \(head.length) \(head) ",level: .Trace)
        }else {
            if ota {
                
                let chunk = aes!.ss_gen_hash(buffer: data, counter: Int32(tag))
                var temp = Data()
                temp.append( chunk)
                temp.append(data)
                datatemp = temp
            }else {
                datatemp = data
            }
            
        }
        
        if let dd = datatemp {
            if let cipher =  aes.encrypt(encrypt_bytes: dd) {
                //socks_writing = true
                
                super.writeData(cipher, withTag: tag)
            }
        }else {
            Xcon.log("encrypt init error or data length 0",level: .Error)
        }

    }
   
    static func connect(_ target: String, port: UInt16,p:SFProxy, delegate: SocketDelegate, queue: DispatchQueue)  ->TCPSSConnector {
        let c:TCPSSConnector = TCPSSConnector.init(target, port: port, p: p, delegate: delegate, queue: queue)
        
        //TCPSSConnector.swift.[363]:12484608:12124160:360448:Bytes
        //c.cIDFunc()
      
        c.ota = p.tlsEnable
        c.aes = SSEncrypt.init(password: p.password, method: p.method)
        if p.editEnable == false {
            let iv = "This is an IV456" // should be of 16 characters.
            //here we are convert nsdata to String
            
            let ss = SSEncrypt.init(password:"This is a key123This is an IV456" , method: "aes-256-cfb",ivsys: iv)
            
            var data = iv.data(using: .utf8)!
            data.append(Data(base64Encoded: p.password)!)
            
            if let passwd = ss.decrypt(encrypt_bytes: data){
                
                let pw = String.init(data: passwd, encoding: .utf8)!
                c.aes = SSEncrypt.init(password: pw, method: p.method)
            }
            
            
        }else {
            c.aes = SSEncrypt.init(password: p.password, method: p.method)
        }
        c.start()
       
        return c
    }

    public override func didDisconnect(_ socket: RawSocketProtocol, error: Error?) {
        
        self.socketdelegate?.didDisconnectWith(socket: self)
    }
    
    public override func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol) {
        
        if let cipher = self.aes.decrypt(encrypt_bytes: data){
            if let d = self.socketdelegate {
                d.didRead(data: cipher, from: self)
                // d.connector(self, didReadData: cipher, withTag: Int64(tag))
                
            }else {
                Xcon.log(" didReadData Connection deal drop data ",level: .Error)
            }
        }else {
            Xcon.log("SS Engine Decrypt Error ",level: .Error)
        }
    }
    
    public override func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol) {
        
        self.socketdelegate?.didWrite(data: data, by: self)
    }
    
    public override func didConnect(_ socket: RawSocketProtocol) {
        
        self.socketdelegate?.didConnectWith(adapterSocket:  self)
    }
    

}

