//
//  CloudKitKVSManager.swift
//  Squirrel
//
//  Created by PinkXaciD on 2025/01/07.
//

import Foundation
import Combine

final class CloudKitKVSManager: ObservableObject {
    @Published
    var iCloudSync: Bool

    private let store: NSUbiquitousKeyValueStore?
    private var valueSubscription: AnyCancellable?

    init(store: NSUbiquitousKeyValueStore? = nil) {
        let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil

        if iCloudAvailable {
            let kvs = store ?? .default
            self.store = kvs
            self.iCloudSync = kvs.bool(forKey: UDKey.iCloudSync.rawValue)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(update(_:)),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: kvs
            )

            self.toggleKVS()
            kvs.synchronize()
        } else {
            self.store = nil
            self.iCloudSync = false
        }
    }

    deinit {
        if let store {
            NotificationCenter.default.removeObserver(
                self,
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store
            )
        }
    }

    @objc
    func update(_ notification: Notification) {
        guard let store,
              let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? Array<String> else {
            return
        }

        if changedKeys.contains(UDKey.iCloudSync.rawValue) {
            DispatchQueue.main.async {
                self.iCloudSync = store.bool(forKey: UDKey.iCloudSync.rawValue)
            }
        }
    }

    private func toggleKVS() {
        self.valueSubscription = self.$iCloudSync
            .sink { [weak self] newValue in
                self?.store?.set(newValue, forKey: UDKey.iCloudSync.rawValue)
            }
    }
}
