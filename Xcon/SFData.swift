//
//  SFData.swift
//  Surf
//
//  Created by 孔祥波 on 11/10/16.
//  Copyright © 2016 yarshure. All rights reserved.
//

import Foundation

public class SFData:CustomStringConvertible {
    public var data = Data()
    public var description: String {
        return (data as NSData).description
    }
    public init() {
        
    }
//    mutating func append(_ v:T) {
//        var value = v
//        let storage = withUnsafePointer(to: &value) {
//            Data(bytes: UnsafePointer($0), count: MemoryLayout.size(ofValue: v))
//        }
//        data.append(storage)
//    }
    
    public func append(_ v:UInt8){
        data.append(v)
    }
    public func append(_ v:Data){
        data.append(v)
    }
    public func append(_ v:UInt32) {
        var value = v
        let storage = withUnsafePointer(to: &value) {
            Data(bytes: UnsafePointer($0), count: MemoryLayout.size(ofValue: v))
        }
        data.append(storage)
    }
    public func append(_ newElement: CChar) {
        let v = UInt8(bitPattern: newElement)
        data.append(v)
    }
    public func append(_ v:String){
        let storage = v.data(using: .utf8)
        
        data.append(storage!)
    }
   public  func append(_ v:UInt16) {
        var value = v
        let storage = withUnsafePointer(to: &value) {
            Data(bytes: UnsafePointer($0), count: MemoryLayout.size(ofValue: v))
        }
        data.append(storage)
    }
    public func append(_ v:Int16) {
        var value = v
        let storage = withUnsafePointer(to: &value) {
            Data(bytes: UnsafePointer($0), count: MemoryLayout.size(ofValue: v))
        }
        data.append(storage)
    }
    public func length(_ r:Range<Data.Index>) ->Int {
        return r.upperBound - r.lowerBound
    }
}
//dump a vaule from Data
protocol ValueType {
    init()
    
}
extension UInt8:ValueType {}
extension Int8:ValueType {}
extension UInt16:ValueType {}
extension Int16:ValueType {}
extension UInt32:ValueType {}
extension Int32:ValueType {}
enum DataLengthError: Error {
    case outofLength
    
}
extension Data{
    func valueForIndex<T:ValueType>(index:Int,type:T.Type) throws -> T {
        //        let size = type.size
        //let alignment = MemoryLayout<T>.alignment
        
        let stride =  MemoryLayout<T>.stride
        if self.count < index+stride {
            throw DataLengthError.outofLength
        }
        let subData = self.subdata(in: index..<(index+stride))
        var ptr :UnsafePointer<T>?
       
        subData.withUnsafeBytes { (p:UnsafePointer<T>) -> Void in
            ptr = p
        }
        return ptr!.pointee
    }
    static func testMemory(){
        let x:[UInt8] = [0xFF,0xFF,0x03,0x04]
        let data = Data.init(bytes: x)

        print("value \(try! data.valueForIndex(index: 0, type: UInt8.self))")
        print("value \(try! data.valueForIndex(index: 3, type: Int8.self))")
        print("value \(try! data.valueForIndex(index: 0, type: Int16.self))")
        print("value \(try! data.valueForIndex(index: 0, type: UInt16.self))")
        print("value \(try! data.valueForIndex(index: 0, type: UInt32.self))")
        print("value \(try! data.valueForIndex(index: 0, type: Int32.self))")
    }
}
