//
//  Session.swift
//  SFSocket
//
//  Created by 孔祥波 on 28/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation

let defaultAcceptBacklog = 1024
let errBrokenPipe      = "broken pipe"
let errInvalidProtocol = "invalid protocol version"

class writeRequest {
    var frame:Frame
    var result:writeRequest?
    init(value:Frame) {
        self.frame = value
    }
}

struct writeResult {
    var n :Int
    var err:Error
}

class Session {
    
}
