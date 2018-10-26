//
//  KcpTestVC.swift
//  macTest
//
//  Created by yarshure on 2018/1/16.
//  Copyright © 2018年 yarshure. All rights reserved.
//

import Cocoa
import Xcon
import os.log
class KcpTestVC: NSViewController ,XconDelegate{
    func didConnect(_ socket: Xcon, cert: SecTrust?) {
        
    }
    
    func didConnect(_ socket: Xcon, cert: Data) {
        
    }
    
    func didDisconnect(_ socket: Xcon, error: Error?) {
        let ts = Date().timeIntervalSince(start)
        if #available(OSX 10.12, *) {
            os_log("Xcon: %.2f", log: .default, type: .debug, ts)
        } else {
            // Fallback on earlier versions
        }
        
    }
    
    func didReadData(_ data: Data, withTag: Int, from: Xcon) {
        print("didReadData \(data as NSData)")
        let ts = Date().timeIntervalSince(start)
        if #available(OSX 10.12, *) {
            os_log("Xcon: didReadData:%.2f", log: .default, type: .debug, ts)
        } else {
            // Fallback on earlier versions
        }
    }
    
    func didWriteData(_ data: Data?, withTag: Int, from: Xcon) {
       
         //print("didReadData \(data as? NSData)")
         //con.forceDisconnect()
    }
    
    func didConnect(_ socket: Xcon) {
        let ts = Date().timeIntervalSince(start)
        if #available(OSX 10.12, *) {
            os_log("Xcon: didConnect: %.2f", log: .default, type: .debug, ts)
        } else {
            // Fallback on earlier versions
        }
        let data = "GET / HTTP/1.1\r\nHost: twitter.com\r\nUser-Agent: curl/7.54.0\r\nAccept: */*\r\n\r\n".data(using: .utf8)
        con.writeData(data!, withTag: 0)
        
    }
    

    var con:Xcon!
    var start:Date = Date()
    let queue = DispatchQueue.init(label: "callback.kcp")
    override func viewDidLoad() {
        super.viewDidLoad()
        let kcptun = "http,45.76.141.59,6000,,"
        guard let p = SFProxy.createProxyWithLine(line: kcptun, pname: "CN2") else{
            fatalError()
        }
        start = Date()
        p.kcptun = true
        con = Xcon.socketFromProxy(p, targetHost: "twitter.com", Port: 80, delegate: self, queue: queue,sessionID:0)
        // Do view setup here.
    }
    
}
