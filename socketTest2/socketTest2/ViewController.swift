//
//  ViewController.swift
//  socketTest2
//
//  Created by yesway on 2017/2/20.
//  Copyright © 2017年 yesway. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.


    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let manager = YYSocketManager.shareSocketManager
        manager.addDelegate(delegate: self, withHost: "127.0.0.1", withPort: 6969)
        
        let data = "commond jopker".data(using: .utf8)
        
        manager.sendData(data: data as NSData?, withHost: "127.0.0.1", withPort: 6969)
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
extension ViewController: SocketManagerDelegate {
    func socketDidConnectToHost(host: String, port: UInt16) {
        
    }
    func socketDidDisconnect() {
        
    }
    func socketDidReadData(data: NSData) {
        let read = String(data: data as Data, encoding: .utf8) ?? "fail"
        print(read)
    }
}

