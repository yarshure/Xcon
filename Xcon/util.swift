//
//  util.swift
//  Xcon
//
//  Created by yarshure on 2018/1/16.
//  Copyright © 2018年 yarshure. All rights reserved.
//

import Foundation
public func query(_ domain:String) ->[String] {
    var results:[String] = []
    
    let host = CFHostCreateWithName(nil,domain as CFString).takeRetainedValue()
    CFHostStartInfoResolution(host, .addresses, nil)
    var success: DarwinBoolean = false
    if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? {
        
        for s in  addresses{
            let theAddress =  s as! Data
            var hostname = [CChar](repeating: 0, count: Int(256))
            
            let p = theAddress as Data

            _ =  p.withUnsafeBytes { (ptr: UnsafeRawBufferPointer)   in
              
                var storage = ptr.load(as: sockaddr.self)

                if getnameinfo(&storage, socklen_t(theAddress.count),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let numAddress = String(cString:hostname)

                    results.append(numAddress)

                }
            }
           
        }
    }
    return results
}
