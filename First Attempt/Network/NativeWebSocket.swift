//
//  NativeWebSocket.swift
//  First Attempt
//
//  Created by Daniel Aragon on 4/3/20.
//  Copyright © 2020 Daniel Aragon. All rights reserved.
//

import Foundation

protocol WebSocketProvider: class {
    var delegate: WebSocketProviderDelegate? { get set }
    func connect()
    func send(data: Data)
}

protocol WebSocketProviderDelegate: class {
    func webSocketDidConnect(_ webSocket: WebSocketProvider)
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider)
    func webSocket(_ webSocket: WebSocketProvider, didReceiveData data: Data)
}

@available(iOS 13.0, *)
class NativeWebSocket: NSObject, WebSocketProvider {
    
    var delegate: WebSocketProviderDelegate?
    private let url: URL
    private var socket: URLSessionWebSocketTask?
    private lazy var urlSession: URLSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    init(url: URL) {
        self.url = url
        super.init()
    }

    func connect() {
        let socket = urlSession.webSocketTask(with: url)
        socket.resume()
        self.socket = socket
        self.readMessage()
    }

    func send(data: Data) {
        self.socket?.send(.data(data)) { _ in }
    }
    
    private func readMessage() {
        self.socket?.receive { [weak self] message in
            guard let self = self else { return }
            
            switch message {
            case .success(.data(let data)):
                self.delegate?.webSocket(self, didReceiveData: data)
                self.readMessage()
                
            case .success:
                debugPrint("Warning: Expected to receive data format but received a string. Check the websocket server config.")
                self.readMessage()

            case .failure:
                self.disconnect()
            }
        }
    }
    
    private func disconnect() {
        self.socket?.cancel()
        self.socket = nil
        self.delegate?.webSocketDidDisconnect(self)
    }
}

@available(iOS 13.0, *)
extension NativeWebSocket: URLSessionWebSocketDelegate, URLSessionDelegate  {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.delegate?.webSocketDidConnect(self)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.disconnect()
    }
}
