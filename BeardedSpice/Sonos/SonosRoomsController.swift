//
//  SonosRoomsController.swift
//  Beardie
//
//  Created by Roman Sokolov on 29.06.2021.
//  Copyright © 2021 GPL v3 http://www.gnu.org/licenses/gpl.html
//

import Cocoa
import RxSwift
import RxSonosLib

@objc protocol SonosRoom {
    @objc var displayName: String {get}
    @objc var enabled: Bool {get set}
}

final class SonosRoomsController: NSObject {
    
    static let groupObtainTimeout: TimeInterval = 6
    static let requestTimeout: TimeInterval = 2
    
    // MARK: Public
    @objc static let singleton = SonosRoomsController()
    
    @objc var tabs = [SonosTabAdapter]()
    @objc var rooms = [SonosRoom]()
    
    override init() {
        
        super.init()
        self.startMonitoringGroups()
    }
    
    // MARK: File Private
    
    fileprivate func roomEnabled(_ room: Room) -> Bool {
        self.queue.sync {
            return true
        }
    }
    
    fileprivate func setRoom(_ room: Room, enabled: Bool) {
        
    }
    
    // MARK: Private
    private var allGroupDisposable: Disposable?
    private let queue = DispatchQueue(label: "SonosRoomsControllerQueue")

    private func startMonitoringGroups() {
        
        SonosSettings.shared.renewGroupsTimer = Self.groupObtainTimeout
        SonosSettings.shared.requestTimeout = Self.requestTimeout
        
        self.allGroupDisposable?.dispose()
        self.allGroupDisposable = SonosInteractor.getAllGroups()
            .distinctUntilChanged()
            .subscribe(self.onGroups)

    }
    
    private lazy var onGroups: (Event<[Group]>) -> Void = { [weak self] event in
        guard let self = self else {
            return
        }
        DDLogDebug("New Sonos Group event: \(event)")
        switch event {
        case .next(let groups):
            self.rooms = groups.flatMap { group in
                return ([group.master] + group.slaves) as [SonosRoom]
            }
            
            self.tabs = groups.map { SonosTabAdapter($0) }
        case .error(let err):
            DDLogError("Error obtaing group: \(err)")
            fallthrough
        default:
            self.tabs = []
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.groupObtainTimeout) {
                self.startMonitoringGroups()
            }
        }
    }
}

// MARK: - SonosRoom extension for Room -

extension Room: SonosRoom {
    
    var displayName: String {
        "\(self.name) (Sonos)"
    }
    
    var enabled: Bool {
        get {
            SonosRoomsController.singleton.roomEnabled(self)
        }
        set {
            SonosRoomsController.singleton.setRoom(self, enabled: newValue)
        }
    }
    
    
}
