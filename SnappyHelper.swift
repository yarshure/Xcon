//
//  File.swift
//  SFSocket
//
//  Created by yarshure on 2017/6/5.
//  Copyright © 2017年 Kong XiangBo. All rights reserved.
//

import Foundation
import snappy
class SnappyHelper {
    
    var dataBuffer:Data = Data()
    
    func compress(_ data:Data) ->Data{
        
        let count:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        count.pointee =  snappy_max_compressed_length(data.count)
        let out:UnsafeMutablePointer<Int8> = UnsafeMutablePointer<Int8>.allocate(capacity: count.pointee)
        defer {
            out.deallocate()
            count.deallocate()
            
        }
        data.withUnsafeBytes { (inp: UnsafeRawBufferPointer) -> Void in
            let inputbuffer = inp.bindMemory(to: Int8.self)
            let input:UnsafePointer<Int8> = inputbuffer.baseAddress!
            if snappy_compress(input, data.count, out, count) == SNAPPY_OK {
                Xcon.log("ok \(count.pointee)",level:.Info)
                
            }
        }
        
        
        //let raw = UnsafeRawPointer.init(out)
        let result = Data(buffer: UnsafeBufferPointer(start:out,count:count.pointee))
        //print("out \(count.pointee) \(result as NSData)")
        return result
        //testDecomp(st, mid: result)
    }
    func decompress(_ data:Data) ->Data?{
        let count:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        dataBuffer.append(data)
        //count.pointee =  snappy_max_compressed_length(dataBuffer.count)
        
         let output_length:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        
        
        
        let out:UnsafeMutablePointer<Int8> = UnsafeMutablePointer<Int8>.allocate(capacity: count.pointee)
        defer {
            out.deallocate( )
            count.deallocate( )
            output_length.deallocate()
        }
        var sec:Bool = false
        dataBuffer.withUnsafeBytes { (inp: UnsafeRawBufferPointer) -> Void in
            let inputbuffer = inp.bindMemory(to: Int8.self)
            let input:UnsafePointer<Int8> = inputbuffer.baseAddress!
            if snappy_uncompressed_length(input, dataBuffer.count,output_length) != SNAPPY_OK{
                Xcon.log("snappy snappy_uncompressed_length error", level: .Error)
                fatalError()
                
            }else {
                if snappy_uncompress(input, dataBuffer.count, out, output_length) == SNAPPY_OK {
                    print("ok \(count.pointee)")
                    sec = true
                }else {
                    Xcon.log("snappy snappy_uncompress error", level: .Error)
                    fatalError()
                }
            }
            
            
        }
        if sec {
            let result = Data(buffer: UnsafeBufferPointer(start:out,count:output_length.pointee))
            //print("out \(count.pointee) \(result as NSData)")
            return result
        }else {
            return nil
        }
        
    }
}
