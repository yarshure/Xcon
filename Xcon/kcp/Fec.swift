//
//  Fec.swift
//  SFSocket
//
//  Created by 孔祥波 on 25/04/2017.
//  Copyright © 2017 Kong XiangBo. All rights reserved.
//
// "github.com/klauspost/reedsolomon"
import Foundation


let fecHeaderSize      = 6
let fecHeaderSizePlus2 = fecHeaderSize + 2 // plus 2B data size
let typeData           = 0xf1
let typeFEC            = 0xf2

struct fecPatcket {
    var seqid:UInt32 = 0
    var flag:UInt16 = 0
    var data:Data?
}

struct FECDecoder {
    var rxlimit:Int = 0 //queue size limit
    var dataShards:Int = 0
    var parityShards:Int = 0
    var shardSize:Int = 0
    var rx:[fecPatcket] = [] //ordered receive queue
    
    
    //caches
    var decodeCache:[Data] = []
    var flagCache:[Bool] = []
    
    //RS Decoder
    //codec reedsolomon.Encoder
    
    init?(limit:Int,shards:Int,parityShards:Int) {
        if shards <= 0 || parityShards <= 0 {
            return nil
        }
        if limit < shards + parityShards {
            return nil
        }
        
        self.rxlimit = limit
        self.dataShards = shards
        self.parityShards = parityShards
        self.shardSize = shards + parityShards
        
//        enc, err := reedsolomon.New(dataShards, parityShards, reedsolomon.WithMaxGoroutines(1))
//        if err != nil {
//            return nil
//        }
//        fec.codec = enc
//        fec.decodeCache = make([][]byte, fec.shardSize)
//        fec.flagCache = make([]bool, fec.shardSize)
//        return fec
    }
    func decodeBytes(_ data:Data) ->fecPatcket{
        var pkt:fecPatcket = fecPatcket()
        
        let d = data as NSData
        var seqid:UInt32 = 0
        d.getBytes(&seqid, length: MemoryLayout<UInt32>.size)
        pkt.seqid = seqid.littleEndian
        let d1 = d.subdata(with: NSMakeRange(4, 2))
        var f:UInt16 = 0
        d1.withUnsafeBytes { (ptr:UnsafePointer<UInt16>) -> Void in
            f = ptr.pointee.littleEndian
        }
        pkt.flag = f
        pkt.data = data.subdata(in: 6..<data.count)
        return pkt
    }
}
