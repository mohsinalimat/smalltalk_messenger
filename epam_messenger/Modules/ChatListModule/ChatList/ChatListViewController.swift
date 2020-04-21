//
//  ChatListViewController.swift
//  epam_messenger
//
//  Created by Anton Pryakhin on 07.03.2020.
//

import UIKit
import Firebase
import FirebaseUI
import CodableFirebase
import Reusable

protocol ChatSelectDelegate: AnyObject {
    func didSelectChat(_ chatModel: ChatModel)
}

protocol ChatListCellDelegate: AnyObject {
    func userListData(
        _ userList: [String],
        completion: @escaping ([UserModel]?) -> Void
    )
    func userData(
        _ userId: String,
        completion: @escaping (UserModel?) -> Void
    )
    func chatData(
        _ chatId: String,
        completion: @escaping (ChatModel?) -> Void
    )
}

protocol ChatListViewControllerProtocol {
}

let separatorInsetEdit: CGFloat = 120
let separatorInsetPlain: CGFloat = 75

class ChatListViewController: UIViewController {
    
    // MARK: - Vars
    
    var tableView: PaginatedTableView<ChatModel>!
    
    var viewModel: ChatListViewModelProtocol!
    let searchController = UISearchController(searchResultsController: nil)
    internal var searchChatItems = [ChatModel]()
    internal var searchMessageItems = [MessageModel]()
    
    weak var forwardDelegate: ChatSelectDelegate?
    
    var searchDataSource: FUIFirestoreTableViewDataSource!
    
    lazy var deleteButton: UIBarButtonItem = {
        return UIBarButtonItem(
            title: "Delete",
            style: .plain,
            target: self,
            action: #selector(deleteSelectedChats)
        )
    }()
    
    // MARK: - Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if isSelectMode {
            title = "Select chat"
            let backItem = UIBarButtonItem()
            backItem.title = "Cancel"
            backItem.tintColor = .accent
            backItem.action = #selector(didCancelTap)
            backItem.target = self
            navigationItem.leftBarButtonItem = backItem
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        setupTableView()
        setupSearchController()
        setupNavigationItem()
        setupToolbarItems()
        didSelectionChange()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    @objc func didCancelTap() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    private func setupTableView() {
        tableView = .init(
            baseQuery: viewModel.firestoreQuery(),
            initialPosition: .top,
            cellForRowAt: { indexPath in
                let cell = self.tableView.dequeueReusableCell(for: indexPath, cellType: ChatCell.self)
                let chatModel = self.tableView.elementAt(indexPath)
                
                cell.chat = chatModel
                cell.delegate = self
                
                return cell
            },
            querySideTransform: { chat in
                return chat.lastMessage.date
            },
            fromSnapshot: ChatModel.fromSnapshot
        )
        
        tableView.register(cellType: ChatCell.self)
        tableView.register(cellType: SearchChatCell.self)
        tableView.register(cellType: SearchMessageCell.self)
        tableView.paginatedDelegate = self
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.separatorInset.left = separatorInsetPlain
        tableView.sectionHeaderHeight = 20
        
        view.addSubview(tableView)
        tableView.edgesToSuperview()
    }
    
    private func setupToolbarItems() {
        tabBarController?.setToolbarItems([
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            deleteButton
        ], animated: false)
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search by chats and messages"
        searchController.navigationItem.rightBarButtonItem?.tintColor = .red
        if let navigationItem = isSelectMode
            ? self.navigationItem
            : tabBarController?.navigationItem {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        }
    }
    
    // MARK: - Edit mode
    
    private func setupNavigationItem() {
        let leftItem = UIBarButtonItem(
            title: "Edit",
            style: .plain,
            target: self,
            action: #selector(toggleEditMode)
        )
        tabBarController?.navigationItem.setLeftBarButton(leftItem, animated: true)
        
        let rightItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(goToChatCreate)
        )
        tabBarController?.navigationItem.setRightBarButton(rightItem, animated: true)
    }
    
    @objc private func goToChatCreate() {
        viewModel.goToChatCreate()
    }
    
    @objc private func toggleEditMode(_ sender: UIBarButtonItem) {
        tableView.reloadRows(at: [ .init(row: 0, section: 0) ], with: .fade)
        
//        tableView.setEditing(!tableView.isEditing, animated: true)
//        tableView.separatorInset.left = tableView.isEditing
//            ? separatorInsetEdit
//            : separatorInsetPlain
//        sender.title = tableView.isEditing ? "Done" : "Edit"
//        sender.style = tableView.isEditing ? .done : .plain
//        searchController.searchBar.isUserInteractionEnabled = !tableView.isEditing
//        UIView.animate(withDuration: 0.3) {
//            self.searchController.searchBar.alpha = self.tableView.isEditing ? 0.75 : 1
//        }
//        tabBarController?.navigationItem.rightBarButtonItem?.isEnabled = !tableView.isEditing
//
//        setToolbarHidden(!tableView.isEditing)
//        self.setTabBarHidden(tableView.isEditing)
    }
    
    private func setToolbarHidden(_ isHidden: Bool, completion: @escaping () -> Void = {}) {
        UIView.animate(withDuration: 0.3, animations: {
            self.tabBarController?.navigationController?.setToolbarHidden(!self.tableView.isEditing, animated: true)
        }, completion: { _ in
            completion()
        })
    }
    
    @objc private func deleteSelectedChats() {
        viewModel.deleteSelectedChats(
            tableView.indexPathsForSelectedRows!.map { tableView.elementAt($0) }
        )
    }
    
    private func didSelectionChange() {
        let rowsSelected = tableView.indexPathsForSelectedRows != nil
        
        tabBarController?.title = rowsSelected
            ? "Selected \(tableView.indexPathsForSelectedRows!.count) chats"
            : "Chats"
        
        deleteButton.isEnabled = rowsSelected
    }
    
    // MARK: - Helpers
    
    func setTabBarHidden(
        _ hidden: Bool,
        animated: Bool = true,
        duration: TimeInterval = 0.3,
        completion: @escaping () -> Void = {}
    ) {
        
        if animated,
            let tabbar = tabBarController?.tabBar {
            if !hidden {
                tabbar.isHidden = false
            }
            UIView.animate(withDuration: duration, animations: {
                tabbar.alpha = hidden ? 0.0 : 1.0
            }) { _ in
                completion()
                if hidden {
                    tabbar.isHidden = true
                }
            }
            return
        }
        self.tabBarController?.tabBar.isHidden = hidden
    }
    
    var isSelectMode: Bool {
        return tabBarController == nil
    }
    
    var isSearch: Bool {
        return !(searchController.searchBar.text?.isEmpty ?? true)
    }
}

extension ChatListViewController: PaginatedTableViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchController.searchBar.resignFirstResponder()
    }
    
    private func chatModel(
        at indexPath: IndexPath,
        completion: @escaping (ChatModel?) -> Void
    ) {
        switch indexPath.section {
        case 0:
            completion(searchChatItems[indexPath.item])
        case 1:
            let message = searchMessageItems[indexPath.item]
            viewModel.chatData(message.chatId!, completion: completion)
        default:
            fatalError("Unknown section")
        }
    }
    
    private func didSelect(_ chatModel: ChatModel?, _ indexPath: IndexPath) {
        if let chatModel = chatModel {
            if isSelectMode {
                navigationController?.dismiss(animated: true) {
                    self.forwardDelegate?.didSelectChat(chatModel)
                }
            } else {
                tableView.deselectRow(at: indexPath, animated: true)
                viewModel.goToChat(chatModel)
            }
        } else {
            debugPrint("Error while parse selected chat")
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            didSelectionChange()
        } else {
            if isSearch {
                chatModel(at: indexPath) { chatModel in
                    self.didSelect(chatModel, indexPath)
                }
            } else {
                didSelect(self.tableView.elementAt(indexPath), indexPath)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        didSelectionChange()
    }
    
    func tableView(_ tableView: UITableView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        return !isSelectMode && !isSearch
    }
    
    func tableView(_ tableView: UITableView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        if !isSelectMode && !isSearch {
            self.setEditing(true, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if !isSelectMode, !isSearch {
            let identifier = NSString(string: String(indexPath.item))
            let chatModel = self.tableView.elementAt(indexPath)
            let configuration = UIContextMenuConfiguration(identifier: identifier, previewProvider: { () -> UIViewController? in
                // Return Preview View Controller here
                return self.viewModel.createChatPreview(chatModel)
            }) { _ -> UIMenu? in
                let delete = UIAction(
                    title: "Delete",
                    image: UIImage(systemName: "trash.fill"),
                    attributes: .destructive
                ) { _ in
                    self.viewModel.deleteSelectedChats([ chatModel ])
                }
                
                return UIMenu(title: "", children: [delete])
            }
            return configuration
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        if !isSelectMode {
            guard let identifier = configuration.identifier as? String else { return }
            guard let itemIndex = Int(identifier) else { return }
            
            let chatModel = self.tableView.elementAt(itemIndex)
            
            animator.addCompletion {
                self.viewModel.goToChat(chatModel)
            }
        }
    }
    
}

// MARK: - Cell delegate

extension ChatListViewController: ChatListCellDelegate {
    
    func userData(_ userId: String, completion: @escaping (UserModel?) -> Void) {
        viewModel.userData(userId, completion: completion)
    }
    
    func userListData(_ userList: [String], completion: @escaping ([UserModel]?) -> Void) {
        viewModel.userListData(userList, completion: completion)
    }
    
    func chatData(_ chatId: String, completion: @escaping (ChatModel?) -> Void) {
        viewModel.chatData(chatId, completion: completion)
    }
    
}

extension ChatListViewController: ChatListViewControllerProtocol {}
