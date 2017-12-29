//
//  BlockCrypt.swift
//  SFSocket
//
//  Created by 孔祥波 on 29/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import CommonCrypto
let initialVector:[UInt8] = [167, 115, 79, 156, 18, 172, 27, 1, 164, 21, 242, 193, 252, 120, 230, 107]
let saltxor       = "sH3CIVoF#rWLtJo6"
public enum BlockCryptType:Int,CustomStringConvertible {
    case tea = 0
    case xor = 1
    case none = 2
    case aes128 = 3
    case aes192 = 4
    case blowfish  = 5
    case cast5  = 6
    case des = 7
    case xtea = 8
    case salsa20 = 9
    case aes = 10
    public var description: String {
        switch self {
        case .tea: return "tea"
        case .xor: return "xor"
        case .none: return "none"
        case .aes128: return "aes-128"
        case .aes192: return "aes-192"
        case .blowfish:  return "blowfish"
        case .cast5:  return "cast5"
        case .des: return "3des"
        case .xtea: return "xtea"
        case .salsa20: return "salsa20"
        case .aes: return  "aes"
            //case .KCPTUN: return "KCPTUN"
        }
    }
    
}
public protocol BlockCryptProtocol {
    

    // Encrypt encrypts the whole block in src into dst.
    // Dst and src may point at the same memory.
    func Encrypt(data:Data) ->Data
    // Decrypt decrypts the whole block in src into dst.
    // Dst and src may point at the same memory.
    func Decrypt(data:Data) ->Data
}
class BlockCrypt :BlockCryptProtocol{
    var type:BlockCryptType = .aes
    var pass:Data
    init(t:BlockCryptType,p:Data) {
        self.type = t
        self.pass = p
    }
    
    static func create(type:String,pass:Data) ->BlockCrypt{
        
        switch type {
        case "tea":
            //block, _ = kcp.NewTEABlockCrypt(pass[:16])
            return NoneBlockCrypt.init(t: .none, p: pass)
        case "xor":
            //block, _ = kcp.NewSimpleXORBlockCrypt(pass)
            return NoneBlockCrypt.init(t: .none, p: pass)
            
        case "none":
            //block, _ = kcp.NewNoneBlockCrypt(pass)
            return NoneBlockCrypt.init(t: .none, p: pass)
            
        case "aes-128":
            //block, _ = kcp.NewAESBlockCrypt(pass[:16])
            return AESBlockCrypt.init(t: .aes128, p: pass)
            
        case "aes-192":
            //block, _ = kcp.NewAESBlockCrypt(pass[:24])
            return AESBlockCrypt.init(t: .aes192, p: pass)
        case "blowfish":
            //block, _ = kcp.NewBlowfishBlockCrypt(pass)
            return NoneBlockCrypt.init(t: .none, p: pass)
        case "twofish":
            //block, _ = kcp.NewTwofishBlockCrypt(pass)
            return NoneBlockCrypt.init(t: .none, p: pass)
        case "cast5":
            //block, _ = kcp.NewCast5BlockCrypt(pass[:16])
            return NoneBlockCrypt.init(t: .none, p: pass)
        case "3des":
            //block, _ = kcp.NewTripleDESBlockCrypt(pass[:24])
            return NoneBlockCrypt.init(t: .none, p: pass)
        case "xtea":
            //block, _ = kcp.NewXTEABlockCrypt(pass[:16])
            return NoneBlockCrypt.init(t: .none, p: pass)
        case "salsa20":
            //block, _ = kcp.NewSalsa20BlockCrypt(pass)
            return NoneBlockCrypt.init(t: .none, p: pass)
        default:
            
            //config.Crypt = "aes"
            //block, _ = kcp.NewAESBlockCrypt(pass)
            return AESBlockCrypt.init(t: .aes, p: pass)
        }
    }
    func Decrypt(data: Data) -> Data {
        return data
    }
    
    func Encrypt(data: Data) -> Data {
        return data
    }
    
}
class AESBlockCrypt:BlockCrypt {
    var  ctx:CCCryptorRef?
    override func Decrypt(data: Data) -> Data {
        return data
    }

    override  func Encrypt(data: Data) -> Data {
        return data
        var inptr:UnsafePointer<UInt8>?
        _ = pass.withUnsafeBytes({ (ptr:UnsafePointer<UInt8>)  in
            inptr = ptr
        })
        
    }

    
    override init(t:BlockCryptType,p:Data) {
        super.init(t: t, p: p)
        //ctx = CCCryptorCreateWithMode(<#T##op: CCOperation##CCOperation#>, <#T##mode: CCMode##CCMode#>, <#T##alg: CCAlgorithm##CCAlgorithm#>, <#T##padding: CCPadding##CCPadding#>, <#T##iv: UnsafeRawPointer!##UnsafeRawPointer!#>, <#T##key: UnsafeRawPointer!##UnsafeRawPointer!#>, <#T##keyLength: Int##Int#>, <#T##tweak: UnsafeRawPointer!##UnsafeRawPointer!#>, <#T##tweakLength: Int##Int#>, <#T##numRounds: Int32##Int32#>, <#T##options: CCModeOptions##CCModeOptions#>, <#T##cryptorRef: UnsafeMutablePointer<CCCryptorRef?>!##UnsafeMutablePointer<CCCryptorRef?>!#>)
    }

    
}
class NoneBlockCrypt:BlockCrypt {
    override  func Decrypt(data: Data) -> Data {
        return data
    }
    
    override  func Encrypt(data: Data) -> Data {
        return data
    }
    
    
    override init(t:BlockCryptType,p:Data) {
        super.init(t: t, p: p)
    }
    
    
}
