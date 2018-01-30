//
//  ext.swift
//  Xcon
//
//  Created by yarshure on 2017/11/22.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Foundation
public extension String {
    public func to(index:Int) ->String{
        return String(self[..<self.index(self.startIndex, offsetBy:index)])
        
    }
    public func to(index:String.Index) ->String{
        return String(self[..<index])
        
    }
    public func from(index:Int) ->String{
        return String(self[self.index(self.startIndex, offsetBy:index)...])
        
    }
    public func from(index:String.Index) ->String{
        return String(self[index...])
        
    }
    public func validateIpAddr() ->SOCKS5HostType{
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        
        if self.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
            // IPv6 peer.
            return .IPV6
        }
        else if self.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
            // IPv4 peer.
            return .IPV4
        }
        
        return .DOMAIN
        
    }
}
public enum SOCKS5HostType:UInt8,CustomStringConvertible{
    case IPV4 = 0x01
    case DOMAIN = 0x03
    case IPV6 = 0x04
    public var description: String {
        switch self {
        case .IPV4 :return "SFSocks5HostTypeIPV4"
        case .DOMAIN: return "SFSocks5HostTypeDOMAIN"
        case .IPV6: return "SFSocks5HostTypeIPV6"
        }
    }
}
public enum SFSocks5Stage:Int8,CustomStringConvertible{
    case Auth = 0
    case AuthSend = 2
    case Bind = 1
    case Connected = 5
    public var description: String {
        switch self {
        case .Auth :return "Auth"
        case .AuthSend: return "AuthSend"
        case .Bind: return "Bind"
        case .Connected: return "Connected"
        }
    }
}
let SOCKS_VERSION:UInt8 = 0x05
let SOCKS_AUTH_VERSION:UInt8 = 0x01
let SOCKS_AUTH_SUCCESS:UInt8 = 0x00
let SOCKS_CMD_CONNECT:UInt8 = 0x01
let SOCKS_IPV4:UInt8 = 0x01
let SOCKS_DOMAIN :UInt8 = 0x03
let SOCKS_IPV6:UInt8 = 0x04
let SOCKS_CMD_NOT_SUPPORTED :UInt8 = 0x07

struct method_select_request
{
    var ver:UInt8
    var nmethods:UInt8
    //char methods[255];
    var methods:Data
}

struct method_select_response
{
    var ver:UInt8
    var method:UInt8
}

struct socks5_request
{
    var ver:UInt8
    var cmd:UInt8
    var rsv:UInt8
    var atyp:UInt8
}

struct socks5_response
{
    var ver:UInt8
    var rep:UInt8
    var rsv:UInt8
    var atyp:UInt8
}
public func toIPv6Addr(ipString:String) -> Data?  {
    var addr = in6_addr()
    let retval = withUnsafeMutablePointer(to: &addr) {
        inet_pton(AF_INET6, ipString, UnsafeMutablePointer($0))
    }
    if retval < 0 {
        return nil
    }
    
    let data = NSMutableData.init(length: 16)
    let p = UnsafeMutableRawPointer.init(mutating: (data?.bytes)!)
    //let addr6 =
    //#if swift("2.2")
    //memcpy(p, &(addr.__u6_addr), 16)
    memcpy(p, &addr, 16)
    //#else
    //#endif
    //print(addr.__u6_addr)
    return data as Data?
}
extension Data{
    
    public func withUnsafeRawPointer<ResultType>(_ body: (UnsafeRawPointer) throws -> ResultType) rethrows -> ResultType {
        return try self.withUnsafeBytes { (ptr: UnsafePointer<Int8>) -> ResultType in
            let rawPtr = UnsafeRawPointer(ptr)
            return try body(rawPtr)
        }
    }
    public func scanValue<T>(start: Int, length: Int) -> T {
        //start+length > Data.last is security?
        return self.subdata(in: start..<start+length).withUnsafeBytes { $0.pointee }
    }
}
extension Range{
    //<Data.Index>
    public func length() -> Int{
        return 0 //
    }
}
public enum SFConnectionMode:String {
    case HTTP = "HTTP"
    case HTTPS = "HTTPS"
    case TCP = "TCP"
    case UDP = "UDP"
    //case CONNECT = "CONNECT"
    public var description: String {
        switch self {
        case .HTTP: return "HTTP"
        case .HTTPS: return "HTTPS"
        case .TCP: return "TCP"
        case .UDP: return "UDP"
            //case CONNECT: return "CONNECT"
        }
    }
    
}
