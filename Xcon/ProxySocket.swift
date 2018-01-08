//
//  ProxyConnector.swift
//  Surf
//
//  Created by yarshure on 16/1/7.
//  Copyright © 2016年 yarshure. All rights reserved.
//

import Foundation
import AxLogger
import NetworkExtension
import Security
import XSocket
public class ProxyConnector: AdapterSocket {

    
    public var description: String {
        return ""
    }
    var cIDString:String {
        get {
            return "cIDString"
        }
    }
    var proxy:SFProxy
    var tlsSupport:Bool = false
    var targetHost:String = ""
    var targetPort:UInt16 = 0
    var tlsEvaluate:Bool = false
    #if os(iOS)
    let acceptableCipherSuites:Set<NSNumber> = [
        
        NSNumber(value: TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256),
        NSNumber(value: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA),
        NSNumber(value: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256),
        NSNumber(value: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA),
        NSNumber(value: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA),
        NSNumber(value: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256),
        NSNumber(value: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA),
        NSNumber(value: TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384),
        NSNumber(value: TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384),
        NSNumber(value: TLS_RSA_WITH_AES_256_GCM_SHA384),
        NSNumber(value: TLS_DHE_RSA_WITH_AES_256_GCM_SHA384),
        NSNumber(value: TLS_DH_RSA_WITH_AES_256_GCM_SHA384)
            
        
        
        
//    public var TLS_RSA_WITH_AES_256_GCM_SHA384: SSLCipherSuite { get }
//    public var TLS_DHE_RSA_WITH_AES_128_GCM_SHA256: SSLCipherSuite { get }
//    public var TLS_DHE_RSA_WITH_AES_256_GCM_SHA384: SSLCipherSuite { get }
//    public var TLS_DH_RSA_WITH_AES_128_GCM_SHA256: SSLCipherSuite { get }
//    public var TLS_DH_RSA_WITH_AES_256_GCM_SHA384: SSLCipherSuite { get }
        
        
    ]
    #else
    let acceptableCipherSuites:Set<NSNumber> = [
    NSNumber(value: TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256),
    NSNumber(value: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA),
    NSNumber(value: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256),
    NSNumber(value: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA),
    NSNumber(value: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA),
    NSNumber(value: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256),
    NSNumber(value: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA)
    
    ]
    #endif
    
    init(p:SFProxy) {
        proxy = p
        
        super.init()
        
        //cIDFunc()
    }
    static func connectTo(_ host: String, port: UInt16,p:SFProxy,delegate:SocketDelegate, queue: DispatchQueue) ->ProxyConnector{
        switch p.type{
        case .HTTP:
            return  HTTPProxyConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
            
        case .HTTPS:
            return HTTPProxyConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
            
        case .SS:
            return TCPSSConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
            
        case .SS3:
            return TCPSSConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
          
        case .SOCKS5:
            return Socks5Connector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
           
        case .HTTPAES:
            return   TCPSSConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
            
        case .LANTERN:
            return TCPSSConnector.connect(host, port: port, p: p, delegate: delegate, queue: queue)
           
        }
    }
     public func start() {
        guard let port = UInt16(proxy.serverPort) else {
            return
        }
        if proxy.type == .SS {
            if !proxy.serverIP.isEmpty{
                //by pass dns resolv
                try! self.connectTo(proxy.serverIP, port: port, enableTLS: false, tlsSettings: nil)
            }else {
                try! self.connectTo(proxy.serverAddress, port: port, enableTLS: false, tlsSettings: nil)
            }
            
        }else {
            try! self.connectTo(proxy.serverAddress, port: port, enableTLS: proxy.tlsEnable, tlsSettings: nil)
        }
        
    }
    override public func connectTo(_ host: String, port: UInt16, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws {
       
        
        if enableTLS {
            _ = NWHostEndpoint(hostname: host, port: "\(port)")
            let tlsParameters = NWTLSParameters()
            if let tlsSettings = tlsSettings as? [String: AnyObject] {
                tlsParameters.setValuesForKeys(tlsSettings)
            }else {
                tlsParameters.sslCipherSuites = acceptableCipherSuites 

            }
            let v = SSLProtocol.tlsProtocol12
            tlsParameters.minimumSSLProtocolVersion = Int(v.rawValue)
            
            var socket = RawSocketFactory.getRawSocket()
            socket.queue = DispatchQueue.init(label: "socket")
            socket.delegate = self
            try socket.connectTo(host, port: port, enableTLS: enableTLS, tlsSettings: [:])
        
        }else {
            try super.connectTo(host, port: port, enableTLS: false, tlsSettings: tlsSettings)
            
        }
        

    }
    
    @nonobjc public func shouldEvaluateTrustForConnection(connection: NWTCPConnection) -> Bool{
        return true
    }
    
    @nonobjc public func evaluateTrustForConnection(connection: NWTCPConnection, peerCertificateChain: [AnyObject], completionHandler completion: @escaping (SecTrust) -> Void){
        
        let myPolicy = SecPolicyCreateSSL(true, nil)//proxy.serverAddress
        
        var possibleTrust: SecTrust?
        
        let x = SecTrustCreateWithCertificates(peerCertificateChain.first!, myPolicy,
                                       &possibleTrust)
        guard let remoteAddress = connection.remoteAddress as? NWHostEndpoint else {
            completion(possibleTrust!)
            return
        }
        Xcon.log("debug :\(remoteAddress.hostname)", level: .Debug)
        if x != 0 {
             Xcon.log("debug :\(remoteAddress.hostname) \(x)", level: .Debug)
        }
        if let trust = possibleTrust {
            //let's do test by ourself first
            
             var trustResult : SecTrustResultType = .invalid
             let r = SecTrustEvaluate(trust, &trustResult)
            if r != 0{
                Xcon.log("debug :\(remoteAddress.hostname) error code:\(r)", level: .Debug)
            }
            if trustResult == .proceed {
                Xcon.log("debug :\(remoteAddress.hostname) Proceed", level: .Debug)
            }else {
                Xcon.log("debug :\(remoteAddress.hostname) Proceed error", level: .Debug)
            }
             //print(trustResult)  // the result is 5, is it
             //kSecTrustResultRecoverableTrustFailure?
             
            completion(trust)
        }else {
             Xcon.log("debug :\(remoteAddress.hostname) error", level: .Debug)
        }
    }
 

}
