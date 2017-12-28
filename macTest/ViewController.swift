//
//  ViewController.swift
//  macTest
//
//  Created by yarshure on 2017/12/28.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Cocoa
import  Xcon
import XSocket
class ViewController: NSViewController ,XconDelegate{
    func didDisconnect(_ socket: Xcon, error: Error?) {
        print("111")
    }
    
    func didReadData(_ data: Data, withTag: Int, from: Xcon) {
        print("222 \(data as NSData)")
    }
    
    func didWriteData(_ data: Data?, withTag: Int, from: Xcon) {
        print("\(withTag) write")
        con!.readDataWithTag(0)
    }
    
    func didConnect(_ socket: Xcon) {
        print("222 4")
        let str = "GET / HTTP/1.1\r\nHost: baidu.com\r\nUser-Agent: curl/7.54.0\r\nAccept: */*\r\n\r\n".data(using: .utf8)!
        con?.writeData(str, withTag: 0)
        
    }
    

    var con:Xcon?
    let q = DispatchQueue.init(label: "test.queue")
    let p = SFProxy.create(name: "11", type: .HTTP, address: "192.168.11.131", port: "8000", passwd: "", method: "", tls: false)
    func start(){
        
        if let x = Xcon.socketFromProxy(self.p, targetHost: "www.google.com", Port: 80, sID: 1, delegate: self, queue: q){
            self.con = x
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        Xcon.debugEnable = true
        start()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

