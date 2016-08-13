//
//  SwiftMessages.swift
//  SwiftMessages
//
//  Created by Tim Moose on 8/1/16.
//  Copyright © 2016 SwiftKick Mobile. All rights reserved.
//

import UIKit

private let globalInstance = SwiftMessages()

/**
 
 */
public class SwiftMessages: PresenterDelegate {
    
    public enum PresentationContext {
        case Automatic
        case Window(windowLevel: UIWindowLevel)
        case ViewController(_: UIViewController)
    }
    
    public enum PresentationStyle {
        case Top
        case Bottom
    }
    
    public enum Duration {
        case Automatic
        case Forever
        case Seconds(seconds: NSTimeInterval)
    }
    
    public enum DimMode {
        case None
        case Automatic(interactive: Bool)
        case Color(color: UIColor, interactive: Bool)
    }
    
    public struct Config {
        
        public init() {}
        
        public var duration = Duration.Automatic
        
        public var presentationStyle = PresentationStyle.Top
        
        public var dimMode = DimMode.None
        
        public var presentationContext = PresentationContext.Automatic
        
        /**
         Specifies the preferred status bar style when the view is displayed
         directly behind the status bar, such as when using `.Window`
         presentation context with a `UIWindowLevelNormal` window level
         and `.Top` presentation style.
         */
        public var preferredStatusBarStyle: UIStatusBarStyle = UIStatusBarStyle.Default
    }
    
    /**
     A block that returns an arbitrary view.
     */
    public typealias ViewProvider = () -> UIView

    /**
     */
    public func show(viewProvider viewProvider: ViewProvider) {
        show(config: Config(), viewProvider: viewProvider)
    }

    /**
     Show the given config and view, as provided by the `viewProvider` block,
     to the message display queue.
     
     The `viewProvider` block is guaranteed to be called on the main queue where
     it is safe to instantiate and configure the view. This variant of `add` is
     recommended when the message might be added from a background queue given that
     there is no need toexplicitly dispatch back to the main queue.
     
     - parameter config: Configuration options for showing the message view.
     - parameter viewProvider: A block that returns an arbitrary view to be displayed as a message.
     */
    public func show(config config: Config, viewProvider: ViewProvider) {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            guard let strongSelf = self else { return }
            let view = viewProvider()
            strongSelf.show(config: config, view: view)
        }
    }

    /**
     */
    public func show(view view: UIView) {
        show(config: Config(), view: view)
    }

    /**
     Show the given config and view to the message display queue.
     - parameter config: Configuration options for showing the message view.
     - parameter view: An arbitrary view to be displayed as a message.
     */
    public func show(config config: Config, view: UIView) {
        dispatch_async(syncQueue) { [weak self] in
            guard let strongSelf = self else { return }
            let presenter = Presenter(config: config, view: view, delegate: strongSelf)
            strongSelf.enqueue(presenter: presenter)
        }
    }
    
    /**
     Hide the current message being displayed by animating it away.
     */
    public func hide() {
        dispatch_async(syncQueue) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.hideCurrent()
        }
    }

    /**
     Hide current and queued messages. If a message is currently being displayed,
     it will be animated away.
     */
    public func hideAll() {
        dispatch_async(syncQueue) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.queue.removeAll()
            strongSelf.hideCurrent()
        }
    }

    /**
     Hide a message with the given `id`. If the specified message is
     currently being displayed, it will be animated away. Works with message
     views, such as `MessageView`, that implement the `Identifiable` protocol.
     - parameter id: The identifier of the message to remove.
     */
    public func hide(id id: String) {
        dispatch_async(syncQueue) { [weak self] in
            guard let strongSelf = self else { return }
            if id == strongSelf.current?.id {
                strongSelf.hideCurrent()
            }
            strongSelf.queue = strongSelf.queue.filter { $0.id != id }
        }
    }
    
    /**
     The amount of time to pause between removing a message
     and showing the next. Default is 0.5 seconds.
     */
    public var pauseBetweenMessages: NSTimeInterval = 0.5
    
    let syncQueue = dispatch_queue_create("it.swiftkick.SwiftMessages", DISPATCH_QUEUE_SERIAL)
    var queue: [Presenter] = []
    var current: Presenter? = nil {
        didSet {
            if oldValue != nil {
                let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(pauseBetweenMessages * Double(NSEC_PER_SEC)))
                dispatch_after(delayTime, syncQueue, { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.dequeueNext()
                })
            }
        }
    }
    
    func enqueue(presenter presenter: Presenter) {
        if let id = presenter.id {
            if current?.id == id { return }
            if queue.filter({ $0.id == id }).count > 0 { return }
        }
        queue.append(presenter)
        dequeueNext()
    }
    
    func dequeueNext() {
        guard self.current == nil else { return }
        guard queue.count > 0 else { return }
        let current = queue.removeFirst()
        self.current = current
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            guard let strongSelf = self else { return }
            do {
                try current.show { completed in
                    guard let strongSelf = self else { return }
                    guard completed else {
                        dispatch_async(strongSelf.syncQueue, {
                            guard let strongSelf = self else { return }
                            strongSelf.hide(presenter: current)
                        })
                        return
                    }
                    if let pauseDuration = current.pauseDuration {
                        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(pauseDuration * Double(NSEC_PER_SEC)))
                        dispatch_after(delayTime, strongSelf.syncQueue, {
                            guard let strongSelf = self else { return }
                            strongSelf.hide(presenter: current)
                        })
                    }
                }
            } catch {
                strongSelf.current = nil
            }
        }
    }
    
    func hideCurrent() {
        guard let current = current else { return }
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            current.hide { (completed) in
                guard completed else { return }
                guard let strongSelf = self else { return }
                dispatch_async(strongSelf.syncQueue, {
                    guard let strongSelf = self else { return }
                    strongSelf.current = nil
                })
            }
        }
    }
    
    /*
     MARK: - PresenterDelegate
     */
    
    func hide(presenter presenter: Presenter) {
        dispatch_async(syncQueue) { [weak self] in
            guard let strongSelf = self else { return }
            if let current = strongSelf.current where presenter === current {
                strongSelf.hideCurrent()
            }
            strongSelf.queue = strongSelf.queue.filter { $0 !== presenter }
        }
    }
}

/*
 MARK: - Static APIs
 */

extension SwiftMessages {
    
    /**
     A default instance of `SwiftMessages`.
     */
    public static var sharedInstance: SwiftMessages {
        return globalInstance
    }
    
    public static func show(viewProvider viewProvider: ViewProvider) {
        globalInstance.show(viewProvider: viewProvider)
    }
    
    public static func show(config config: Config, viewProvider: ViewProvider) {
        globalInstance.show(config: config, viewProvider: viewProvider)
    }
    
    public static func show(view view: UIView) {
        globalInstance.show(view: view)
    }

    public static func show(config config: Config, view: UIView) {
        globalInstance.show(config: config, view: view)
    }

    public static func hide() {
        globalInstance.hide()
    }
    
    public static func hideAll() {
        globalInstance.hideAll()
    }
    
    public static func hide(id id: String) {
        globalInstance.hide(id: id)
    }
    
    public static var pauseBetweenMessages: NSTimeInterval {
        get {
            return globalInstance.pauseBetweenMessages
        }
        set {
            globalInstance.pauseBetweenMessages = newValue
        }
    }
}