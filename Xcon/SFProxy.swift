//
//  File.swift
//  Surf
//
//  Created by yarshure on 15/12/23.
//  Copyright © 2015年 yarshure. All rights reserved.
//

import Foundation
import SwiftyJSON
import ObjectMapper
import CommonCrypto
public enum SFProxyType :Int, CustomStringConvertible{
    case HTTP = 0
    case HTTPS = 1
    case SS = 2
    case SS3 = 6
    case SOCKS5 = 3
    case HTTPAES  = 4
    case LANTERN  = 5
    //case KCPTUN = 7
    public var description: String {
        switch self {
        case .HTTP: return "HTTP"
        case .HTTPS: return "HTTPS"
        case .SS: return "SS"
        case .SS3: return "SS3"
        case .SOCKS5: return "SOCKS5"
        case .HTTPAES: return "GFW Press"
        case .LANTERN: return "LANTERN"
            //case .KCPTUN: return "KCPTUN"
        }
    }
}
public class Proxys:CommonModel {
    var chainProxys:[SFProxy] = []
    var proxys:[SFProxy] = []
    var deleteproxys:[SFProxy] = []
    public override func mapping(map: Map) {
        chainProxys  <- map["chainProxys"]
        proxys <- map["proxys"]
        deleteproxys <- map["deleteproxys"]
    }
    public required init?(map: Map) {
        super.init(map: map)
        //self.mapping(map: map)
    }
    func  selectedProxy(_ selectIndex:Int ) ->SFProxy? {
        if proxys.count > 0 {
            if selectIndex >= proxys.count {
                return proxys.first!
            }
            return proxys[selectIndex]
        }
        return nil
    }
    // for tunnel
    func findProxy(_ proxyName:String,dynamicSelected:Bool,selectIndex:Int) ->SFProxy? {
        
        
        
        if proxys.count > 0  {
            
            
            var proxy:SFProxy?
            if dynamicSelected {
                proxy =   proxys[selectIndex]
                return proxy
            }
            if selectIndex < proxys.count {
                let p =  proxys[selectIndex]
                if p.proxyName == proxyName{
                    return p
                }else {
                    proxy = p
                }
                
            }
            var proxy2:SFProxy?
            for item in proxys {
                if item.proxyName == proxyName {
                    proxy2 =  item
                    break
                }
            }
            if let p = proxy2 {
                return p
            }else {
                if let p = proxy {
                    return p
                }
            }
            
        }
        
        if proxys.count > 0 {
            return proxys.first!
        }
        
        
        return nil
    }
    
    public func cutCount() ->Int{
        if proxys.count <= 3{
            return proxys.count
        }
        return 3
    }
    
    public func removeProxy(_ Index:Int,chain:Bool = false) {
        var p:SFProxy
        if chain {
            p = chainProxys.remove(at: Index)
        }else {
            p = proxys.remove(at: Index)
        }
        deleteproxys.append(p)
        
    }
    func changeIndex(_ srcPath:IndexPath,destPath:IndexPath){
        #if os(iOS)
        if srcPath.section == destPath.section {
            if srcPath.section == 0 {
                changeIndex(srcPath.row, dest: destPath.row, proxylist: &proxys)
            }else {
                changeIndex(srcPath.row, dest: destPath.row, proxylist: &chainProxys)
            }
        }else {
            if srcPath.section == 0{
                let p = proxys.remove(at: srcPath.row)
                chainProxys.insert(p, at: destPath.row)
            }else {
                let p = chainProxys.remove(at: srcPath.row)
                proxys.insert(p, at: destPath.row)
            }
        }
        #endif
    }
    public func changeIndex(_ src:Int,dest:Int,proxylist:inout [SFProxy] ){
        let r = proxylist.remove(at: src)
        proxylist.insert(r, at: dest)
        
    }
    func save()  {
        
    }
    static func load(_ path:String)->Proxys?{
        do {
            let string  = try String.init(contentsOfFile: path)
            guard let proxy = Mapper<Proxys>().map(JSONString: string) else {
                return nil
            }
            return proxy
        }catch let e {
            print("\(e.localizedDescription)")
            return nil
        }
        
    }
    public func updateProxy(_ p:SFProxy){
        //todo
        var oldArray:[SFProxy]
        var newArray:[SFProxy]
        if p.chain {
            oldArray = chainProxys
            newArray = proxys
        }else {
            oldArray = proxys
            newArray = chainProxys
        }
        if let firstSuchElement = oldArray.index(where: { $0 == p })
            .map({ oldArray.remove(at: $0) }) {
            
            
            newArray.append(firstSuchElement)
        }
    }
    
    
    public func addProxy(_ proxy:SFProxy) ->Int {
        var index  = 0
        var found = false
        for p in deleteproxys {
            if p.base64String() == proxy.base64String() {
                //
                return -1
            }else {
                if p.serverAddress == proxy.serverAddress && p.serverPort == proxy.serverPort {
                    found = true
                }
            }
            index += 1
        }
        if !proxy.serverAddress.isEmpty && !proxy.serverPort.isEmpty{
            if found {
                deleteproxys[index] = proxy
                return -1
            }
        }
        found = false
        
        index  = 0
        for idx in 0 ..< proxys.count {
            let p = proxys[idx]
            if p.serverAddress == proxy.serverAddress && p.serverPort == proxy.serverPort {
                found = true
                index = idx
                break
            }
        }
        if found {
            proxys.remove(at: index)
            proxys.insert(proxy, at: index)
            
            return index
        }else {
            proxys.append(proxy)
            let selectIndex = proxys.count - 1
            return selectIndex
            
        }
        
    }
}
public class SFKCPTunConfig:CommonModel {
//    GLOBAL OPTIONS:
//    --localaddr value, -l value      local listen address (default: ":12948")
//    --remoteaddr value, -r value     kcp server address (default: "vps:29900")
//    --key value                      pre-shared secret between client and server (default: "it's a secrect") [$KCPTUN_KEY]
//    --crypt value                    aes, aes-128, aes-192, salsa20, blowfish, twofish, cast5, 3des, tea, xtea, xor, none (default: "aes")
//    --mode value                     profiles: fast3, fast2, fast, normal, manual (default: "fast")
//    --conn value                     set num of UDP connections to server (default: 1)
//    --autoexpire value               set auto expiration time(in seconds) for a single UDP connection, 0 to disable (default: 0)
//    --scavengettl value              set how long an expired connection can live(in sec), -1 to disable (default: 600)
//    --mtu value                      set maximum transmission unit for UDP packets (default: 1350)
//    --sndwnd value                   set send window size(num of packets) (default: 128)
//    --rcvwnd value                   set receive window size(num of packets) (default: 512)
//    --datashard value, --ds value    set reed-solomon erasure coding - datashard (default: 10)
//    --parityshard value, --ps value  set reed-solomon erasure coding - parityshard (default: 3)
//    --dscp value                     set DSCP(6bit) (default: 0)
//    --nocomp                         disable compression
//    --snmplog value                  collect snmp to file, aware of timeformat in golang, like: ./snmp-20060102.log
//    --snmpperiod value               snmp collect period, in seconds (default: 60)
//    --log value                      specify a log file to output, default goes to stderr
//    -c value                         config from json file, which will override the command from shell
//    --help, -h                       show help
//    --version, -v                    print the version
    
    public var key:String = "it's a secrect"
    public var crypt:String = "none"//"aes" //aes-256-cfb
    public var mode:String = "fast"
    public var autoexpire:Int = 0
    public var scavengettl:Int = 600
    public var mtu:Int = 1350
    public var sndwnd:Int = 1024//128
    public var rcvwnd:Int = 1024//
    public var datashard:Int = 10
    public var parityshard:Int = 3
    public var dscp:Int = 0
    public var noComp: Bool =  false //"nocomp"
    let SALT:String = "kcp-go"
    public override func mapping(map: Map) {
        
        key  <- map["key"]
        crypt <- map["crypt"]
        mode <- map["mode"]
        
        autoexpire <- map["autoexpire"]
        scavengettl <- map["scavengettl"] //http socks5 user
        mtu   <- map["mtu"]
        //type   <- (map["type"],EnumTransform<SFProxyType>())
        sndwnd    <- map["sndwnd"]
        rcvwnd         <- map["rcvwnd"]
        datashard      <- map["datashard"]
        parityshard       <- map["parityshard"]
        dscp  <- map["dscp"]
        dscp  <- map["NoComp"]
        
//         public var mode:String  = "fast2"
//        public var key:String = "" //pkdf2 use
//        public var cryptoType:String = "none"
    }
    public func pkbdf2Key(pass:String,salt:Data) ->Data?{
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
public class SFProxy:CommonModel {
    public var proxyName:String = ""
    public var serverAddress:String = ""
    public var serverPort:String = ""
    public var password:String = ""
    public var method:String = ""
    public var tlsEnable:Bool = false //对于ss ,就是OTA 是否支持
    public var type:SFProxyType = .SS
    public var pingValue:Float = -1
    public var tcpValue:Double = 0
    public var dnsValue:Double = 0
    public var priority:Int = 0
    public var enable:Bool = true
    public var serverIP:String = ""
    public var countryFlag:String = ""
    public var chain:Bool = false
    public var isoCode:String = ""
    public var udpRelay:Bool = false
    
    public var editEnable:Bool = true
   
    public var kcptun:Bool = false
    public var config:SFKCPTunConfig = SFKCPTunConfig()
    public func countryFlagFunc() ->String{
        if countryFlag.isEmpty {
            return showString()
        }else {
            return countryFlag + " " + proxyName
        }
    }
    func pkbdf2Key() ->Data? {
        let s = config.SALT.data(using: .utf8)!
        return config.pkbdf2Key(pass: config.key, salt: s)
    }
    public override func mapping(map: Map) {
        
        proxyName  <- map["pName"]
        serverAddress <- map["serverAddress"]
        serverPort <- map["serverPort"]
        
        password <- map["password"]
        method <- map["method"] //http socks5 user
        tlsEnable   <- map["tlsEnable"]
        type   <- (map["type"],EnumTransform<SFProxyType>())
        countryFlag    <- map["countryFlag"]
        priority         <- map["priority"]
        isoCode      <- map["isoCode"]
        serverIP       <- map["serverIP"]
        chain  <- map["chain"]
        udpRelay  <- map["udpRelay"]
        kcptun  <- map["kcptun"]
        config  <- map["config"]
        
        tcpValue <- map["tcpValue"]
        priority <- map["priority"]
        pingValue <- map["pingValue"]//
        editEnable <- map["editEnable"]
        //birthday    <- (map["birthday"], DateTransform())
        
        
        
    }
    public static func createProxyWithURL(_ configString:String) ->(proxy:SFProxy?,message:String) {
        // http://base64str
        //"aes-256-cfb:fb4b532cb4180c9037c5b64bb3c09f7e@108.61.126.194:14860"
        //mayflower://xx:xx@108.61.126.194:14860
        //"ss://Y2hhY2hhMjA6NTg0NTIweGMwQDQ1LjMyLjkuMTMwOjE1MDE?remark=%F0%9F%87%AF%F0%9F%87%B5"
        //(lldb) n
        //(lldb) po x
        //"ss://Y2hhY2hhMjA6NTg0NTIweGMwQDQ1LjMyLjkuMTMwOjE1MDE?remark=🇯🇵"
        //let x = configString.removingPercentEncoding!
        //NSLog("%@", configString)
        if let u = NSURL.init(string: configString){
            
            
            guard  let scheme = u.scheme else {
                //找不到scheme 会crash
                //alertMessageAction("\(configString) Invilad", complete: nil)
                return (nil,"\(configString) Invilad")
            }
            
            guard let proxy:SFProxy = SFProxy.create(name: "server", type: .SS, address: "", port: "443", passwd: "", method: "aes-256-cfb", tls: false) else  {
                return (nil, "create proxy error")
            }
            
            let t = scheme.uppercased()
            if t == "HTTP" {
                proxy.type = .HTTP
            }else if t == "HTTPS" {
                proxy.type = .HTTPS
                proxy.tlsEnable = true
            }else if t == "SOCKS5" {
                proxy.type = .SOCKS5
            }else if t == "SS" {
                proxy.type = .SS
            }else if t == "SS3" {
                proxy.type = .SS3
            }else {
                return (nil, "URL \(scheme) Invilad")
                
            }
            let result = u.host!
            
            if let query  = u.query {
                let x = query.components(separatedBy: "&")
                for xy in x {
                    let x2 = xy.components(separatedBy: "=")
                    if x2.count == 2 {
                        
                        if x2.first! == "remark" {
                            proxy.proxyName = x2.last!.removingPercentEncoding!
                        }else if x2.first! == "tlsEnable"{
                            let v = Int(x2.last!)
                            if v == 1  {
                                proxy.tlsEnable = true
                            }else {
                                proxy.tlsEnable = false
                            }
                        } else if x2.first! == "kcptun" {
                            proxy.kcptun = true
                        } else if x2.first! == "crypt" {
                            proxy.config.crypt = x2.last!
                            
                        }else if x2.first == "key" {
                            let base64Str = x2.last!
                            let d = Data.init(base64Encoded: base64Str, options: .ignoreUnknownCharacters)
                            if let key =  String.init(data: d! , encoding: .utf8){
                                proxy.config.key = key
                            }
                        }else if x2.first == "nocomp" {
                            if let v = Int(x2.last!) {
                                if v == 1 {
                                    proxy.config.noComp = true
                                }else {
                                    proxy.config.noComp = false
                                }
                            }
                        }else if x2.first! == "mode" {
                            proxy.config.mode = x2.last!
                        }else if x2.first! == "datashard"{
                            proxy.config.datashard = Int(x2.last!)!
                        }else if x2.first! == "parityshard"{
                            proxy.config.parityshard = Int(x2.last!)!
                        }
                    }
                }
            }
            var paddedLength = 0
            let left = result.count % 4
            if left != 0 {
                paddedLength = 4 - left
            }
            
            let padStr = result + String.init(repeating: "=", count: paddedLength)
            if let data = Data.init(base64Encoded: padStr, options: .ignoreUnknownCharacters) {
                if let resultString = String.init(data: data , encoding: .utf8) {
                    let items = resultString.components(separatedBy: ":")
                    if items.count == 3 {
                        proxy.method = items[0].lowercased()
                        proxy.serverPort = items[2]
                        
                        if let r = items[1].range(of: "@"){
                            let tempString = items[1]
                            proxy.password = tempString.to(index:r.lowerBound)
                            proxy.serverAddress = tempString.from(index: r.upperBound)
                            return (proxy,"OK")
                        } else {
                            return (nil,"\(resultString) Invilad")
                        }
                    }else {
                        return (nil,"\(resultString) Invilad")
                    }
                }else{
                    return (nil,"\(configString) Invilad")
                }
                
                
            }else {
                return (nil,"\(configString) Invilad")
            }
            
            
        }else {
            return (nil,"\(configString) Invilad")
        }
        
    }
    public static func createProxyWithLine(line:String,pname:String) ->SFProxy? {
        
        let name = pname.trimmingCharacters(in:
            NSCharacterSet.whitespacesAndNewlines)
        
        
        
        let list =  line.components(separatedBy: ",")
        
        if list.count >= 5{
            let t = list.first?.uppercased().trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines)
            //占位
            guard let proxy:SFProxy = SFProxy.create(name: name, type: .SS, address: "", port: "443", passwd: "", method: "aes-256-cfb", tls: false) else  {
                return (nil)
            }
            if t == "HTTP" {
                proxy.type = .HTTP
            }else if t == "HTTPS" {
                proxy.type = .HTTPS
                proxy.tlsEnable = true
            }else if t == "SOCKS5" {
                proxy.type = .SOCKS5
            }else if t == "SS" {
                proxy.type = .SS
            }else if t == "SS3" {
                proxy.type = .SS3
            }else {
                //alertMessageAction("\(scheme) Invilad", complete: nil)
                //return
            }
            
            proxy.serverAddress =  list[1].trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines)
            proxy.serverPort =   list[2].trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines)
            proxy.method =   list[3].trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines).lowercased()
            proxy.password =   list[4].trimmingCharacters(in:
                NSCharacterSet.whitespacesAndNewlines)
            
            if  list.count >= 6 {
                let temp = list[5]
                let tt = temp.components(separatedBy: "=")
                if tt.count == 2{
                    if tt.first! == "tls" {
                        if tt.last! == "true"{
                            proxy.tlsEnable = true
                        }
                    }
                }
            }
            return proxy
        }
        return nil
        
        
        
    }
    public static func create(name:String,type:SFProxyType ,address:String,port:String , passwd:String,method:String,tls:Bool) ->SFProxy?{
        
        // Convert JSON String to Model
        //let user = Mapper<User>().map(JSONString: JSONString)
        // Create JSON String from Model
        //let JSONString = Mapper().toJSONString(user, prettyPrint: true)
        guard let proxy = Mapper<SFProxy>().map(JSONString: "{\"type\":0}") else {
            return nil
        }
        
        proxy.proxyName = name
        proxy.serverAddress = address
        proxy.serverPort = port
        proxy.password = passwd
        proxy.method = method
        if type == .HTTPS {
            proxy.tlsEnable = true
        }else {
            proxy.tlsEnable = tls
        }
        
        if method == "aes" {
            proxy.type = .HTTPAES
        }else {
            proxy.type = type
        }
        
        return proxy
    }
    public required init?(map: Map) {
        super.init(map: map)
        //self.mapping(map: map)
    }
    //public required init?(map: Map) {
    //super.init(map: map)
    //super.init(map: map)
    //fatalError("init(map:) has not been implemented")
    //}
    
    
    public  func showString() ->String {
        if !proxyName.isEmpty{
            return proxyName
        }else {
            if !isoCode.isEmpty {
                return  isoCode
            }
        }
        return serverAddress
    }
    
    
    //    public func resp() ->[String:Any]{
    //        return ["name":proxyName as AnyObject,"host":serverAddress as AnyObject,"port":serverPort,"protocol":type.description,"method":method,"passwd":password,"tls":NSNumber.init(value: tlsEnable),"priority":NSNumber.init(value: priority),"enable":NSNumber.init(value: enable),"countryFlag":countryFlag,"isoCode":isoCode,"ipaddress":serverIP,"mode":mode,"kcptun":NSNumber.init(value:kcptun ),"chain":chain]
    //    }
    //open  static func map(_ name:String,value:JSON) ->SFProxy{
  
    
    public func typeDesc() ->String{
        var info:String = ""
        if tlsEnable && type == .HTTP {
            info = "Type: " + "HTTPS"
        }else {
            info = "Type: " + type.description
        }
        if kcptun {
            info += " Over KCPTUN"
        }
        return info
    }
    static open func loadFromDictioanry(_ dic:AnyObject?) ->SFProxy?{
        return self.fromDictionary(dic)
    }
    public func base64String() ->String {
        let tls = tlsEnable ? "1" : "0"
        let c = chain ? "1" : "0"
        let string = method + ":" + password + "@" + serverAddress  + ":" + serverPort
        
        //let string = config.method + ":" + config.password + "@" + a + ":" + p
        
        //let string = "aes-256-cfb:fb4b532cb4180c9037c5b64bb3c09f7e@108.61.126.194:14860"//
        let utf8str = string.data(using: .utf8)
        if kcptun {
            
            let cc = config.noComp ? "1" : "0"
            var base64Encoded = type.description.lowercased()  + "://" + utf8str!.base64EncodedString(options: .endLineWithLineFeed)
            base64Encoded += "?tlsEnable=" + tls
        
            base64Encoded += "&chain=" + c
            base64Encoded += "&kcptun=1&crypt=" + config.crypt
            let keyData = config.key.data(using: .utf8)!
            
            base64Encoded += "&key=" + keyData.base64EncodedString(options: .endLineWithLineFeed)
            base64Encoded += "&datashard=" + String(config.datashard)
            base64Encoded += "&parityshard=" + String(config.parityshard)
            base64Encoded += "&mode=" + config.mode
            base64Encoded += "&nocomp=" + cc
            return base64Encoded
        }else {
            let base64Encoded = type.description.lowercased()  + "://" + utf8str!.base64EncodedString(options: .endLineWithLineFeed) +   "?tlsEnable=" + tls + "&chain=" + c
            return base64Encoded
        }
        
    }
    
    deinit{
        
    }
}
public func ==(lhs:SFProxy, rhs:SFProxy) -> Bool { // Implement Equatable
    return lhs.serverAddress == rhs.serverAddress && lhs.serverPort == rhs.serverPort
}
