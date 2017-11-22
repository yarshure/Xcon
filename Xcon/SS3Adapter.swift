//
//  SS3Adapter.swift
//  SFSocket
//
//  Created by 孔祥波 on 27/03/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//

import Foundation

class SS3Adapter :Adapter{
    override var streaming:Bool{
        get {
            return false
        }
    }
    override func recv(_ data: Data) throws -> (Bool,Data) {
        return (false,Data())
    }
    
    override func send(_ data: Data) -> Data {
        return Data()
    }
}
