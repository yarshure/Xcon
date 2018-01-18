//
//  TCP.swift
//  macTest
//
//  Created by yarshure on 2018/1/12.
//  Copyright © 2018年 yarshure. All rights reserved.
//

import Cocoa
import Xcon
class TCP: NSViewController,XconDelegate {
    func didDisconnect(_ socket: Xcon, error: Error?) {
        
    }
    
    func didReadData(_ data: Data, withTag: Int, from: Xcon) {
        
    }
    
    func didWriteData(_ data: Data?, withTag: Int, from: Xcon) {
        
    }
    
    func didConnect(_ socket: Xcon) {
        
    }
    

    var con:Xcon?
    var p:SFProxy!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        let x = "http,192.168.11.131,8000,,"
        if let p = SFProxy.createProxyWithLine(line: x, pname: "CN2"){
            self.con = Xcon.socketFromProxy(p, targetHost: "twitter.com", Port: 443, delegate: self, queue: DispatchQueue.main, sessionID: 1)
        }
        
        // Do view setup here.
    }
    
}
