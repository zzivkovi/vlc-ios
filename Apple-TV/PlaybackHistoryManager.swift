//
//  PlaybackHistoryManager.swift
//  VLC-iOS
//
//  Created by Zeljko Zivkovic on 03/02/2019.
//  Copyright © 2019 VideoLAN. All rights reserved.
//

import Foundation

@objc(VLCPlaybackHistoryManager)
class PlaybackHistoryManager: NSObject {
    private static let historyManagerKey = "HistoryManagerKey"
    @objc static let shared: PlaybackHistoryManager = PlaybackHistoryManager()

    @objc
    func savePlayedFile(_ identifier: String) {
        var dictionary = UserDefaults.standard.dictionary(forKey: PlaybackHistoryManager.historyManagerKey) as? [String: Bool] ?? [String: Bool]()
        dictionary[identifier] = true
        UserDefaults.standard.set(dictionary, forKey: PlaybackHistoryManager.historyManagerKey)
        UserDefaults.standard.synchronize()
    }

    @objc
    func didPlayFile(_ identifier: String) -> Bool {
        let dictionary = UserDefaults.standard.dictionary(forKey: PlaybackHistoryManager.historyManagerKey) as? [String: Bool] ?? [String: Bool]()
        return dictionary[identifier] ?? false
    }

}
