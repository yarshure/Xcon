//
//  TLSNSViewController.swift
//  macTest
//
//  Created by yarshure on 15/01/2018.
//  Copyright © 2018 yarshure. All rights reserved.
//

import Cocoa
import Xcon
class TLSNSViewController: NSViewController,XconDelegate {
    func didDisconnect(_ socket: Xcon, error: Error?) {
        print("didDisconnect")
    }
    
    func didReadData(_ data: Data, withTag: Int, from: Xcon) {
         print("didReadData \(data as NSData)")
    }
    
    func didWriteData(_ data: Data?, withTag: Int, from: Xcon) {
         print("didWriteData \(withTag)")
        con.readDataWithTag(10)
    }
    
    func didConnect(_ socket: Xcon) {
         print("didConnect")
         let str = "GET / HTTP/1.1\r\nHost: swiftai.us\r\nUser-Agent: curl/7.54.0\r\nAccept: */*\r\n\r\n".data(using: .utf8)!
        con.writeData(str, withTag: 1);
    }
    

    var con:Xcon!
    var dq = DispatchQueue(label:"")
    override func viewDidLoad() {
        con = Xcon.socketFromProxy(nil, targetHost: "swiftai.us", Port: 443 , delegate: self , queue: dq, enableTLS: true, sessionID: 0)
    }
    @IBAction func  testTLS(_ sender:Any){
         let c = con as! SecurtXcon
       
        c.testTLS()
        
    }
}
