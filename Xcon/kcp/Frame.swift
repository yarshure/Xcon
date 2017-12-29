//
//  Frame.swift
//  SFSocket
//
//  Created by 孔祥波 on 28/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation

struct kcp {
    static let version:UInt8 = 1
}


let cmdSYN:UInt8 = 0 // stream open
let cmdFIN:UInt8 = 1          // stream close, a.k.a EOF mark
let cmdPSH:UInt8 = 2            // data push
let cmdNOP:UInt8 = 3            // no operation

let sizeOfVer    = 1
let sizeOfCmd    = 1
let sizeOfLength = 2
let sizeOfSid    = 4
let headerSize   = sizeOfVer + sizeOfCmd + sizeOfSid + sizeOfLength
public typealias rawHeader = Data
// Frame defines a packet from or to be multiplexed into a single connection
public struct Frame {
    var ver:UInt8 = kcp.version
    var cmd:UInt8 = 0
    var sid:UInt32 = 0
    var data:Data?
    var left:Int = 0 //当满1个packet 的时候使用，只用来解包
    init(_ cmd:UInt8,sid:UInt32) {
        self.cmd = cmd
        self.sid = sid
        
    }
    init(_ cmd:UInt8,sid:UInt32,data:Data) {
        self.cmd = cmd
        self.sid = sid
        self.data = data
    }
    func frameData() ->Data{
        let f:SFData = SFData()
        f.append(kcp.version)
        f.append(cmd)
        if let d = data {
            f.append(UInt16(d.count))
        }else {
            f.append(UInt16(0))
        }
        
        f.append(sid)
        if let d = data {
            f.append(d)
        }
        return f.data
    }
    public static  func testframe(){
        var f = Frame.init(0, sid: 3)
        print(f.frameData() as NSData)
        let d = "hello".data(using: .utf8)!
        f.data = d
        print(f.frameData() as NSData)
    
    }
    public var desc: String {
        if let d = data {
            return "ver:\(ver) cmd:\(cmd) sid:\(sid) data \(d as NSData)"
        }else {
           return "ver:\(ver) cmd:\(cmd) sid:\(sid)"
        }
        
    }
}
func sysVersion() ->Int {
    return 10
}
public extension rawHeader {
    public func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.pointee }
    }
    public func Version() ->UInt8 {
        return self.first!
    }
    public func cmd() ->UInt8{
        return self[1]
    }
    public func Length() ->Int{
     
        let x = self.subdata(in: Range(2 ..< 4))
        let y = x.to(type: UInt16.self)
        return Int(y)
    }
    public func StreamID() ->UInt32{
        let x = self.subdata(in: Range(4 ..< 8))
        let y = x.to(type: UInt32.self)
        return y
    }
    public func desc() ->String{
        return String.init(format: "Version:%d Cmd:%d StreamID:%d Length:%d", Version(),cmd(),StreamID(),Length())
    }
}
