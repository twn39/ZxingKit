// Copyright 2024 ZxingKit Contributors
//
// SPDX-License-Identifier: Apache-2.0

import Foundation
import os

// MARK: - AdaptiveLock
//
// Issue #5: Consolidate the duplicated OS-adaptive locking strategy from
// BarcodeVideoOutputDelegate and CameraFrameScanner into a single generic type.
//
// Tier 1 — iOS 16+ / macOS 13+:  OSAllocatedUnfairLock (fast, type-safe)
// Tier 2 — iOS 14+:              NSLock (broad compat fallback)

/// A generic, OS-version-adaptive mutual exclusion lock protecting a value of type `State`.
final class AdaptiveLock<State: Sendable>: @unchecked Sendable {

    private class ImplBase {
        func withLock<R>(_ body: @Sendable (inout State) throws -> R) rethrows -> R {
            fatalError("subclass must implement")
        }
    }

    // NSLock fallback — iOS 14+
    private final class NSLockImpl: ImplBase, @unchecked Sendable {
        private let lock = NSLock()
        private var state: State
        init(_ s: State) { self.state = s }
        override func withLock<R>(_ body: @Sendable (inout State) throws -> R) rethrows -> R {
            lock.lock(); defer { lock.unlock() }
            return try body(&state)
        }
    }

    // OSAllocatedUnfairLock — iOS 16+
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    private final class UnfairLockImpl: ImplBase, @unchecked Sendable {
        private let lock: OSAllocatedUnfairLock<State>
        init(_ s: State) { lock = OSAllocatedUnfairLock(initialState: s) }
        override func withLock<R>(_ body: @Sendable (inout State) throws -> R) rethrows -> R {
            // withLockUnchecked does not require R: Sendable, unlike withLock.
            try lock.withLockUnchecked(body)
        }
    }

    private let impl: ImplBase

    init(initialState: State) {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            impl = UnfairLockImpl(initialState)
        } else {
            impl = NSLockImpl(initialState)
        }
    }

    @discardableResult
    func withLock<R>(_ body: @Sendable (inout State) throws -> R) rethrows -> R {
        try impl.withLock(body)
    }
}
