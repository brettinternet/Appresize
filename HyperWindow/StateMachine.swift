//
//  StateMachine.swift
//  Hummingbird
//
//  Created by Sven A. Schmidt on 16/09/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//


// Based on https://www.figure.ink/blog/2015/2/9/swift-state-machines-part-4-redirect


import Foundation


enum Decision {
    case `continue`
    case abort
}


protocol TransitionDelegate {
    func shouldTransition(from: Self, to: Self) -> Decision
}


protocol StateMachineDelegate: AnyObject {
    associatedtype State: TransitionDelegate
    func didTransition(from: State, to: State)
}


class StateMachine<Delegate: StateMachineDelegate> {
    private unowned let delegate: Delegate

    private var _state: Delegate.State {
        didSet {
            delegate.didTransition(from: oldValue, to: _state)
        }
    }

    var state: Delegate.State {
        get { return _state }
        set {
            switch state.shouldTransition(from: _state, to: newValue) {
                case .continue:
                    _state = newValue
                case .abort:
                    break
            }
        }
    }

    init(initialState: Delegate.State, delegate: Delegate) {
        self._state = initialState
        self.delegate = delegate
    }
}
