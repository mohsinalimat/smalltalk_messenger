//
//  ChatTableViewDelegate.swift
//  epam_messenger
//
//  Created by Nickolay Truhin on 15.03.2020.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

extension ChatViewController: PaginatedTableViewDelegate {
    
    // MARK: - Sections header
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let date = self.tableView.keyAt(section)
        let dateString = Message24HourDateFormatter.shared.string(from: date)
        
        let label = DateHeaderLabel()
        label.text = dateString
        
        let containerView = UIView()
        
        containerView.addSubview(label)
        label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        
        return containerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    // MARK: - Reload messages merge
    
    func didUpdateElements() {
        let flattenData = tableView.flattenData
        if flattenData.count > 1, MessageModel.checkMerge(
            flattenData[flattenData.count - 1],
            flattenData[flattenData.count - 2]
        ) {
            let data = tableView.data
            var rows: [IndexPath] = .init()
            let section = data.count - 1
            
            rows.append(.init(item: data[section].elements.count - 1, section: section))
            if data[section].count > 1 {
                rows.append(.init(
                    item: data[section].elements.count - 2,
                    section: section
                ))
            } else if data.count > 1 {
                rows.append(.init(
                    row: data[section - 1].elements.count - 1,
                    section: section - 1
                ))
            }
            
            tableView.reloadRows(
                at: rows,
                with: .fade
            )
        }
    }
    
    // MARK: - Context menu
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !tableView.isEditing else {
            return nil
        }
        
        let identifier = NSMutableArray(array: [
            indexPath.row,
            indexPath.section
        ])
        let messageModel = self.tableView.elementAt(indexPath)
        let config = UIContextMenuConfiguration(identifier: identifier, previewProvider: nil) { _ in
            let copy = UIAction(
                title: "Copy",
                image: UIImage(systemName: "doc.on.doc")
            ) { _ in
                let pasteBoard = UIPasteboard.general
                var allText = ""
                for kind in self.tableView.elementAt(indexPath).kind {
                    switch kind {
                    case .text(let text):
                        allText += text
                    default: break
                    }
                }
                pasteBoard.string = allText
            }
            
            let forward = UIAction(
                title: "Forward",
                image: UIImage(systemName: "arrowshape.turn.up.right")
            ) { _ in
                self.presentForwardController()
                self.forwardMessages = [messageModel]
            }
            
            let savePhoto = UIAction(
                title: "Save to camera roll",
                image: UIImage(systemName: "square.and.arrow.down")
            ) { _ in
                
                if let cell = tableView.cellForRow(at: indexPath) as? MessageCell,
                    let imageContent = cell.contentStack.subviews.first(where: { $0 is MessageImageContent }) as? MessageImageContent,
                    let image = imageContent.imageView.image {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            }
            
            let delete = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                self.viewModel.deleteMessage(messageModel)
            }
            
            let other = UIAction(
                title: "Other",
                image: UIImage(systemName: "ellipsis.circle")
            ) { _ in
                self.enableEditMode()
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                self.didSelectionChange()
            }
            
            var actions: [UIAction] = []
            
            if messageModel.kind.filter({ content in
                if case .image = content {
                    return true
                }
                return false
            }).count == 1 {
                actions.append(savePhoto)
            }
            if messageModel.kind.contains(where: { content in
                if case .text = content {
                    return true
                }
                return false
            }) {
                actions.append(copy)
            }
            
            actions.append(forward)
            
            if !messageModel.isIncoming {
                actions.append(delete)
            }
            
            return UIMenu(title: "", children: [
                UIMenu(title: "", options: .displayInline, children: actions),
                other
            ])
        }
        
        return config
    }
    
    func makeTargetedPreview(for configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        let identifier = configuration.identifier as! NSArray
        let indexPath = IndexPath(
            row: identifier[0] as! Int,
            section: identifier[1] as! Int
        )
        
        let messageCell: MessageCell = tableView.cellForRow(at: indexPath) as! MessageCell
        
        let parameters = UIPreviewParameters()
        parameters.visiblePath = messageCell.makeBubbleMaskPath()
        return UITargetedPreview(view: messageCell.bubbleView, parameters: parameters)
    }
    
    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return makeTargetedPreview(for: configuration)
    }
    
    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return makeTargetedPreview(for: configuration)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !tableView.paginationLock && !bottomScrollAnimationsLock {
            let hidden = tableView.bottomOffset < 100
            if self.floatingBottomButton.isHidden != hidden {
                bottomScrollAnimationsLock = true
                
                self.floatingBottomButton.alpha = hidden ? 1.0 : 0.0
                self.inputBar.separatorLine.alpha = hidden ? 1.0 : 0.0
                
                if !hidden { // show before alpha transition
                    self.floatingBottomButton.isHidden = hidden
                    self.inputBar.separatorLine.isHidden = hidden
                }
                
                UIView.transition(
                    with: floatingBottomButton,
                    duration: 0.5,
                    options: .transitionCrossDissolve,
                    animations: {
                        self.floatingBottomButton.alpha = hidden ? 0.0 : 1.0
                        self.inputBar.separatorLine.alpha = hidden ? 0.0 : 1.0
                }) { _ in
                    self.bottomScrollAnimationsLock = false
                    
                    if hidden { // hide after alpha transition
                        self.floatingBottomButton.isHidden = hidden
                        self.inputBar.separatorLine.isHidden = hidden
                    }
                    
                    self.scrollViewDidScroll(scrollView)
                }
            }
        }
    }
    
    // MARK: - Edit mode
    
    private func didSelectionChange() {
        let messagesSelected = !(tableView.indexPathsForSelectedRows?.isEmpty ?? true)
        let myMessagesSelected = !(
            tableView.indexPathsForSelectedRows?
                .map { tableView.elementAt($0).userId }
                .contains { $0 != Auth.auth().currentUser!.uid }
                ?? true
        )
        
        deleteButton.isEnabled = myMessagesSelected
        forwardButton.isEnabled = messagesSelected
        
        title = messagesSelected
            ? "Selected \(tableView.indexPathsForSelectedRows!.count) messages"
            : defaultTitle
        
        navigationItem.leftBarButtonItem = .init(
            title: "Delete chat",
            style: .plain,
            target: self,
            action: #selector(deleteChat)
        )
        
        navigationItem.rightBarButtonItem = .init(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(disableEditMode)
        )
    }
    
    @objc internal func deleteSelectedMessages() {
        for indexPath in tableView.indexPathsForSelectedRows! {
            let message = tableView.elementAt(indexPath)
            
            viewModel.deleteMessage(message) { _ in
                self.didSelectionChange()
            }
        }
    }
    
    @objc internal func deleteChat() {
        presentActivityAlert()
        viewModel.deleteChat { [weak self] _ in
            guard let self = self else { return }
            self.dismissActivityAlert()
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    internal func presentForwardController() {
        viewModel.presentForwardController(selectDelegate: self)
    }
    
    @objc internal func forwardSelectedMessages() {
        presentForwardController()
        forwardMessages = tableView.indexPathsForSelectedRows!.map { tableView.elementAt($0) }
    }
    
    private func enableEditMode() {
        tableView.setEditing(true, animated: true)
        didSelectionChange()
        
        inputBar.setMiddleContentView(editStack, animated: false)
        inputBar.middleContentViewPadding.right = 0
        inputBar.hideSideStacks()
    }
    
    @objc private func disableEditMode() {
        tableView.setEditing(false, animated: true)
        didSelectionChange()
        navigationItem.rightBarButtonItem = nil
        navigationItem.leftBarButtonItem = nil
        inputBar.setMiddleContentView(inputBar.inputTextView, animated: true)
        inputBar.showSideStacks()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            didSelectionChange()
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            didSelectionChange()
        }
    }
    
    func tableView(_ tableView: UITableView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        if !tableView.isEditing {
            enableEditMode()
        }
        return true
    }
}

extension ChatViewController: ChatSelectDelegate {
    
    func didSelectChat(_ chatId: String) {
        if forwardMessages != nil {
            for message in forwardMessages {
                viewModel.forwardMessage(chatId, message) { [weak self] err in
                    guard let self = self else { return }
                    if let err = err {
                        self.presentErrorAlert(err.localizedDescription)
                    } else if self.viewModel.chat.documentId != chatId {
                        self.viewModel.goToChat(chatId)
                    }
                }
            }
            forwardMessages = nil
            disableEditMode()
        }
    }
    
}
