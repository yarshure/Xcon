//
//  Mux.swift
//  SFSocket
//
//  Created by 孔祥波 on 28/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation
import AxLogger
struct Config {
    var KeepAliveInterval:UInt64 = 10 * 1//second
    var KeepAliveTimeout:UInt64 = 10 * 1//second
    var MaxFrameSize:Int = 4096
    var MaxReceiveBuffer:Int = 4194304
    func VerifyConfig() {
        Xcon.log("VerifyConfig not imp", level: .Warning)
    }
    
}
//creat session
//no imp
// Server is used to initialize a new server-side connection.
//func Server(conn io.ReadWriteCloser, config *Config) (*Session, error) {
//    if config == nil {
//        config = DefaultConfig()
//    }
//    if err := VerifyConfig(config); err != nil {
//        return nil, err
//    }
//    return newSession(config, conn, false), nil
//}
//
//// Client is used to initialize a new client-side connection.
//func Client(conn io.ReadWriteCloser, config *Config) (*Session, error) {
//    if config == nil {
//        config = DefaultConfig()
//    }
//    
//    if err := VerifyConfig(config); err != nil {
//        return nil, err
//    }
//    return newSession(config, conn, true), nil
//}
