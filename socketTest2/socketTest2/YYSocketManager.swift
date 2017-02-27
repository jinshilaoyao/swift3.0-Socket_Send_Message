//
//  YYSocketManager.swift
//  socketTest2
//
//  Created by yesway on 2017/2/20.
//  Copyright © 2017年 yesway. All rights reserved.
//

import UIKit

@objc protocol SocketManagerDelegate: NSObjectProtocol {
    func socketDidConnectToHost(host: String, port: UInt16)
    func socketDidDisconnect()
    func socketDidReadData(data: NSData)
}

class YYSocketManager: NSObject {

    static let shareSocketManager: YYSocketManager = YYSocketManager()
    
    fileprivate let socketDictionary = NSMutableDictionary()//端口号为key
    fileprivate let socketDelegateDictionary = NSMutableDictionary()//端口号为key,可以允许有多个业务等待的情况。
    fileprivate let cacheSendBusinessDataDictionary = NSMutableDictionary()//端口号为key，每个端口只缓存一个将要发送的数据（目前主要解决的是在未连接的状态变为连接成功的状态后，再发送数据的问题。）
    private var sendHeartbeatTimer:Timer?
    
    fileprivate var reConnectTime = 0;
    
    var delegate: SocketManagerDelegate?
    
    override init() {
        super.init()
        
    }
    
    func initHeartBeat() {
        if sendHeartbeatTimer == nil {
            sendHeartbeatTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(onTimer(sender:)), userInfo: nil, repeats: true)
        }
    }
    
    func stopHeartBeat() {
        if sendHeartbeatTimer != nil {
            sendHeartbeatTimer?.invalidate()
            sendHeartbeatTimer = nil
        }
    }
    
    func onTimer(sender: Timer) {
        print("heart")
    }
    
    func addDelegate(delegate: SocketManagerDelegate, withHost host: String, withPort port: UInt16) {
        if (socketDelegateDictionary.object(forKey: "\(port)") == nil) {
            let socketDelegate = NSMutableArray()
            socketDelegateDictionary.setObject(socketDelegate, forKey: "\(port)" as NSCopying)
        }
        let socketDelegates = socketDelegateDictionary.object(forKey: "\(port)") as! NSMutableArray
        
        if socketDelegates.contains(delegate) == false {
            socketDelegates.add(delegate)
        }
    }
    
    func removeDelegate(delegate: SocketManagerDelegate) {
        for socketDelegates in socketDelegateDictionary.allValues {
            (socketDelegates as AnyObject).remove(delegate)
        }
    }
    
    func sendData(data: NSData?, withHost host: String, withPort port: UInt16) {
        if socketDictionary.object(forKey: "\(port)") == nil {
            let newSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
            socketDictionary.setObject(newSocket, forKey: "\(port)" as NSCopying)
            
            do {
                try newSocket.connect(toHost: host, onPort: port)
            } catch let error as NSError {
                let socketDelegates = socketDelegateDictionary.object(forKey: "\(port)") as! NSMutableArray
                for socketDelegate in socketDelegates {
                    (socketDelegate as AnyObject).socketDidDisconnect!(newSocket, withError: error)
                }
                print(error.localizedDescription)
            }
        }
        
        
        let socket = socketDictionary.object(forKey: "\(port)") as? GCDAsyncSocket
        
        if (socket?.isConnected == true)
        {
            socket?.write(data! as Data, withTimeout: -1, tag: 0)
        }
        else
        {
            if data != nil {
                cacheSendBusinessDataDictionary.setObject(data!, forKey: "\(port)" as NSCopying)
            }
        }
        
    }
    
    func disConnect(port: UInt16) {
        
        guard let sockets = socketDictionary.object(forKey: "\(port)") as? GCDAsyncSocket else {
            return
        }
        sockets.disconnect()
        socketDictionary.removeObject(forKey: "\(port)")
    }
    
    
    func reConnect(port: UInt16) {
        disConnect(port: port)
        
        if reConnectTime > 64 {
            return
        }
        
        DispatchQueue.main.async {
            self.connect(port: port)
        }
        
        if reConnectTime == 0 {
            reConnectTime = 2
        } else {
            reConnectTime *= 2
        }
    }
    
    func connect(port: UInt16) {
        if socketDictionary.object(forKey: "\(port)") == nil {
            let newSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
            socketDictionary.setObject(newSocket, forKey: "\(port)" as NSCopying)
            
            do {
                try newSocket.connect(toHost: "127.0.0.1", onPort: port)
            } catch let error as NSError {
                let socketDelegates = socketDelegateDictionary.object(forKey: "\(port)") as! NSMutableArray
                for socketDelegate in socketDelegates {
                    (socketDelegate as AnyObject).socketDidDisconnect!(newSocket, withError: error)
                }
                print(error.localizedDescription)
            }
        }

    }
}

extension YYSocketManager: GCDAsyncSocketDelegate {

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        sock.readData(withTimeout: -1, tag: 0)
        
        guard let data = cacheSendBusinessDataDictionary.object(forKey: "\(sock.connectedPort)") as? Data else  {
            return
        }
        
        initHeartBeat()
        delegate?.socketDidConnectToHost(host: host, port: port)
        sock.write(data, withTimeout: -1, tag: 0)
        reConnectTime = 0
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        sock.disconnect()
        delegate?.socketDidDisconnect()
        stopHeartBeat()
        reConnect(port: sock.connectedPort)
//        do {
//            try sock.connect(toHost: sock.connectedHost!, onPort: sock.connectedPort)
//        } catch let error as NSError {
//            let socketDelegates = socketDelegateDictionary.object(forKey: "\(sock.connectedPort)") as! NSMutableArray
//            for socketDelegate in socketDelegates {
//                (socketDelegate as AnyObject).socketDidDisconnect(sock, withError: error)
//            }
//            print(error.localizedDescription)
//        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        
        guard let socketDelegates = socketDelegateDictionary.object(forKey: "\(sock.connectedPort)") as? Array<AnyObject> else {
            return
        }
        
        
        for socketDelegate in socketDelegates
        {
            socketDelegate.socketDidReadData(data: data as NSData)
        }
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    

}
