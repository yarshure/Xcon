//
//  UDPVC.swift
//  macTest
//
//  Created by yarshure on 2018/1/12.
//  Copyright © 2018年 yarshure. All rights reserved.
//

import Cocoa
import XSocket
import Xcon
class UDPVC: NSViewController,RawSocketDelegate {
    func didDisconnect(_ socket: RawSocketProtocol, error: Error?) {
        
        print("111")
    }
    
    func didReadData(_ data: Data, withTag: Int, from: RawSocketProtocol) {
        if let x =  String.init(data: data, encoding: .utf8){
            print(x)
        }
        
    }
    
    func didWriteData(_ data: Data?, withTag: Int, from: RawSocketProtocol) {
        print("3")
    }
    
    func didConnect(_ socket: RawSocketProtocol) {
        print("didConnect")
    }
    
    func disconnect(becauseOf error: Error?) {
        print("5")
    }
    
    func forceDisconnect(becauseOf error: Error?) {
        print("6")
    }
    

    var con:RawSocketProtocol?
    override func viewDidLoad() {
        super.viewDidLoad()
        con = RawSocketFactory.getRawSocket(type: nil, tcp: false)
        do {
            con!.delegate = self
            con!.queue = DispatchQueue.init(label: "udp")
            try con!.connectTo("127.0.0.1", port: 9000, enableTLS: false, tlsSettings: nil)
        }catch let e {
            print(e)
        }
        
        // Do view setup here.
    }
    
    @IBAction func dis(_ sender: Any) {
        con!.forceDisconnect(becauseOf: nil)
        con = nil
    }
    @IBAction func send(_ sender: Any) {
        let d = Date()
        if let data = d.description.data(using: .utf8) {
             con!.writeData(data, withTag: 0)
        }
       
    }
}
