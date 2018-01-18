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
        print("1")
    }
    
    func didReadData(_ data: Data, withTag: Int, from: Xcon) {
         print("2")
    }
    
    func didWriteData(_ data: Data?, withTag: Int, from: Xcon) {
         print("3")
    }
    
    func didConnect(_ socket: Xcon) {
         print("4")
    }
    

    var con:Xcon!
    var dq = DispatchQueue(label:"")
    override func viewDidLoad() {
        con = Xcon.socketFromProxy(nil, targetHost: "swiftai.us", Port: 443, sID: 0, delegate: self , queue: dq, sessionID: 0, enableTLS: true)
    }
    @IBAction func  testTLS(_ sender:Any){
         let c = con as! SecurtXcon 
            c.configTLS()
        
    }
}
