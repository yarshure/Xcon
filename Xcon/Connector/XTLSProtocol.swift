//
//  XTLSProtocol.swift
//  Xcon
//
//  Created by yarshure on 2018/1/19.
//  Copyright © 2018年 yarshure. All rights reserved.
//

import Foundation

public protocol XTLSProtocol {
    var ctx:SSLContext!
    var certState:SSLClientCertificateState!
    var negCipher:SSLCipherSuite!
    var negVersion:SSLProtocol!
    let handShakeTag:Int
    var handShanked:Bool
    
    func startHandShake()
    
}
