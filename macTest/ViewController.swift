//
//  ViewController.swift
//  macTest
//
//  Created by yarshure on 2017/12/28.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Cocoa
import  Xcon
import snappy
import XSocket
import ObjectMapper
class ViewController: NSViewController ,XconDelegate{
    func didConnect(_ socket: Xcon, cert: SecTrust?) {
        
    }
    
    
    
    func didDisconnect(_ socket: Xcon, error: Error?) {
        
        print("didDisconnect")
    }
    
    func didReadData(_ data: Data, withTag: Int, from: Xcon) {
        //print("222 \(data as NSData)")
        //con!.forceDisconnect()
        if let content = String.init(data: data, encoding: .utf8){
            print(content)
        }
        //con = nil
    }
    
    func didWriteData(_ data: Data?, withTag: Int, from: Xcon) {
        print("\(withTag) write")
        con!.readDataWithTag(0)
    }
    
    func didConnect(_ socket: Xcon) {
        print("222 4")
        print(socket.remote as Any)
        print(socket.local as Any)
        let str = "GET / HTTP/1.1\r\nHost: www.google.com\r\nUser-Agent: curl/7.54.0\r\nAccept: */*\r\n\r\n".data(using: .utf8)!
        con?.writeData(str, withTag: 0)
        
    }
    

    var con:Xcon?
    let q = DispatchQueue.init(label: "test.queue")
    //let p = SFProxy.create(name: "11", type: .SS, address: "35.197.117.170", port: "53784", passwd: "aHR0cHM6Ly9yYXcuZ2l0aHVidXN", method: "aes-256-cfb", tls: false)
    //let p = SFProxy.create(name: "11", type: .HTTP, address: "192.168.11.131", port: "6000", passwd: "", method: "", tls: false)

    //let p = SFProxy.create(name: "11", type: .HTTP, address: "127.0.0.1", port: "8000", passwd: "", method: "", tls: false)
    
    let p = SFProxy.create(name: "11", type: .HTTP, address: "144.34.203.132", port: "6000", passwd: "", method: "", tls: false)

    func start(){
        guard let p = self.p else {return}
        p.kcptun = true
        p.config.crypt = "none"
        if let x = Xcon.socketFromProxy(p, targetHost: "www.google.com", Port: 80, delegate: self, queue: q){

            self.con = x
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        Xsocket.debugEnable = true
        Xcon.debugEnable = true
        start()
        // Do any additional setup after loading the view.
    }

    func testsnappy(){
        let st = "sdlfjlsadfjalsdjfalsdfjlasf".data(using: .utf8)!
        
        
        
        let count:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        count.pointee =  snappy_max_compressed_length(st.count)
        let out:UnsafeMutablePointer<Int8> = UnsafeMutablePointer<Int8>.allocate(capacity: count.pointee)
        defer {
            out.deallocate()
            count.deallocate()
            
        }
        
        st.withUnsafeBytes { (input: UnsafeRawBufferPointer) -> Void in
            let x = input.bindMemory(to: Int8.self)
            if snappy_compress(x.baseAddress!, st.count, out, count) == SNAPPY_OK {
                print("ok \(count.pointee)")
            }
        }
        print(out)
        print("src \(st as NSData)")
        
        //let raw = UnsafeRawPointer.init(out)
        let result = Data(buffer: UnsafeBufferPointer(start:out,count:count.pointee))
        print("out \(count.pointee) \(result as NSData)")
        testDecomp(st, mid: result)
    }
    func testDecomp(_ src:Data,mid:Data){
        let count:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        count.pointee =  snappy_max_compressed_length(mid.count)
        let out:UnsafeMutablePointer<Int8> = UnsafeMutablePointer<Int8>.allocate(capacity: count.pointee)
        defer {
            out.deallocate()
            count.deallocate()
            
        }
        
        mid.withUnsafeBytes { (input: UnsafeRawBufferPointer) -> Void in
             let x = input.bindMemory(to: Int8.self)
            if snappy_uncompress(x.baseAddress!, mid.count, out, count) == SNAPPY_OK {
                print("ok \(count.pointee)")
            }
        }
        let result = Data(buffer: UnsafeBufferPointer(start:out,count:count.pointee))
        print("out \(count.pointee) \(result as NSData)")
        
    }
    func testaead(){
        let lengString = String(repeating: "AAA", count: 4)
        print(lengString)
        _ = AEADCrypto.init(password: "aes-256", key: "", method: "aes-256-gcm")
        //enc.testGCM()
        let x:[UInt8] = [0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68]
        let _:rawHeader = Data.init(x)
        //print(data.desc())
        //print(ProxyGroupSettings.share.proxys)
        guard let p = Mapper<SFProxy>().map(JSONString: "{\"type\":0}") else {
            
            return
        }
        print(p)
        //_ = ProxyGroupSettings.share.addProxy(p)
        //let line = " https,office.hshh.org,51001,vpn_yarshure,kong3191"
        let kcptun = "http,192.168.11.8,6000,,"
        if let p = SFProxy.createProxyWithLine(line: kcptun, pname: "CN2"){
            //_ = ProxyGroupSettings.share.addProxy(p)
            p.kcptun = true
            p.serverIP = "192.168.11.8"
            //_  = ProxyGroupSettings.share.addProxy(p)
            p.config.crypt = "none"
            print(p.base64String())
            //self.http = HTTPTester.init(p: p)
            //self.http?.start()
            
        }
        //var config = KCPTunConfig()
        //let pass = config.pkbdf2Key(pass: p.key, salt: "kcp-go".data(using: .utf8)!)
        //print("\(pass as! NSData)")
        //print(ProxyGroupSettings.share.proxys)
        
    }
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

