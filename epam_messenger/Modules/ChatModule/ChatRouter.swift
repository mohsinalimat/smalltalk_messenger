//
//  ChatRouter.swift
//  epam_messenger
//
//  Created by Nickolay Truhin on 09.04.2020.
//

import Foundation

protocol ChatRouter {
    func showChat(_ chat: ChatProtocol)
    func showChatDetails(_ chat: ChatProtocol, from chatViewController: ChatViewControllerProtocol?)
}

extension ChatRouter {
    func showChatDetails(_ chat: ChatProtocol, from chatViewController: ChatViewControllerProtocol? = nil) {
        showChatDetails(chat, from: chatViewController)
    }
}

extension Router: ChatRouter {
    
    func showChat(_ chat: ChatProtocol) {
        guard let navigationController = navigationController else { return }
        guard let assemblyBuilder = assemblyBuilder as? ChatAssemblyBuilder else { return }
        let chatViewController = assemblyBuilder.createChat(router: self, chat: chat)
        navigationController.pushViewController(chatViewController, animated: true)
    }
    
    func showChatDetails(_ chat: ChatProtocol, from chatViewController: ChatViewControllerProtocol?) {
        guard let navigationController = navigationController else { return }
        guard let assemblyBuilder = assemblyBuilder as? ChatAssemblyBuilder else { return }
        let chatDetailsViewController = assemblyBuilder.createChatDetails(router: self, chat: chat, from: chatViewController)
        navigationController.present(chatDetailsViewController, animated: true, completion: nil)
    }
    
}
