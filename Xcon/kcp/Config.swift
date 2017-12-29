//
//  Config.swift
//  SFSocket
//
//  Created by 孔祥波 on 29/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import CommonCrypto
//default tun config
public struct KCPTunConfig {
    let SALT:String = "kcp-go"
    var LocalAddr:String = " localaddr"
    var RemoteAddr   :String = "remoteaddr"
    var Key          :String = "key"
    var Crypt        :String = "aes"
    var Mode         :String = "fast"
    var Conn         :Int = 1 // 0//"conn"
    var AutoExpire   :Int = 0 // "autoexpire"
    var ScavengeTTL  :Int = 600 // "scavengettl"
    var MTU          :Int = 1350 // "mtu"
    var SndWnd       :Int = 128 // "sndwnd"
    var RcvWnd       :Int = 512 // "rcvwnd"
    var DataShard    :Int = 10 // "datashard"
    var ParityShard  :Int = 3 // "parityshard"
    var DSCP         :Int = 0 // "dscp"
    //todo fix
    var NoComp       : Bool =  false //"nocomp"
    var AckNodelay   : Bool = false //"acknodelay"
    var NoDelay      :Int = 0 // "nodelay"
    var Interval     :Int = 50 // ":Interval"
    var Resend       :Int = 0 // "resend"
    var NoCongestion :Int = 0 // "nc"
    var SockBuf      :Int = 4194304 // "sockbuf"
    var KeepAlive    :Int = 10 // "keepalive"
    var Log          :String = "log"
    var SnmpLog      :String = "snmplog"
    var SnmpPeriod   :Int = 60 // "snmpperiod"
    var pass:String = ""
    public init(){
        
    }
    mutating func setMode() {
        switch Mode {
        case "normal":
            NoDelay = 0
            Interval = 40
            Resend = 2
            NoCongestion = 1
        case "fast":
            NoDelay = 0
            Interval = 30
            Resend = 2
            NoCongestion = 1
        case "fast2":
            NoDelay = 1
            Interval = 20
            Resend = 2
            NoCongestion = 1
        case "fast3":
            NoDelay = 1
            Interval = 10
            Resend = 2
            NoCongestion = 1
        
            
        default:
            break
        }
    }
    //MARK: - fixme
    mutating public func pkbdf2Key(pass:String,salt:Data) ->Data?{
        //test ok
        //b23383c32eefa3753ab6db6e639a0ddc3b50ec6b6c623c9171a15ba0879945cd
        //pass := pbkdf2.Key([]byte(config.Key), []byte(SALT), 4096, 32, sha1.New)
        
        return pbkdf2SHA1(password: pass, salt: salt, keyByteCount: 32, rounds: 4096)
    }
    
    func pbkdf2SHA1(password: String, salt: Data, keyByteCount: Int, rounds: Int) -> Data? {
        return pbkdf2(hash:CCPBKDFAlgorithm(kCCPRFHmacAlgSHA1), password:password, salt:salt, keyByteCount:keyByteCount, rounds:rounds)
    }
    
    func pbkdf2SHA256(password: String, salt: Data, keyByteCount: Int, rounds: Int) -> Data? {
        return pbkdf2(hash:CCPBKDFAlgorithm(kCCPRFHmacAlgSHA256), password:password, salt:salt, keyByteCount:keyByteCount, rounds:rounds)
    }
    
    func pbkdf2SHA512(password: String, salt: Data, keyByteCount: Int, rounds: Int) -> Data? {
        return pbkdf2(hash:CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512), password:password, salt:salt, keyByteCount:keyByteCount, rounds:rounds)
    }
    
    func pbkdf2(hash :CCPBKDFAlgorithm, password: String, salt: Data, keyByteCount: Int, rounds: Int) -> Data? {
        let passwordData = password.data(using:String.Encoding.utf8)!
        var derivedKeyData = Data(repeating:0, count:keyByteCount)
        
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes {derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password, passwordData.count,
                    saltBytes, salt.count,
                    hash,
                    UInt32(rounds),
                    derivedKeyBytes, derivedKeyData.count)
            }
        }
        if (derivationStatus != 0) {
            print("Error: \(derivationStatus)")
            return nil;
        }
        
        return derivedKeyData
    }
}
