//
//  AppDelegate.swift
//  macTest
//
//  Created by yarshure on 2017/12/28.
//  Copyright © 2017年 yarshure. All rights reserved.
//

import Cocoa
import Xcon
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {


    func testParser(){
        let p = Bundle.main.path(forResource: "SimpleGET1.txt", ofType: nil)
        let data = try! Data.init(contentsOf: URL.init(fileURLWithPath: p!), options: Data.ReadingOptions.mappedIfSafe)
        let _ = SFHTTPRequestHeader.init(data: data)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        //self.testParser()
        print("Done")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

