//
//  PersistenceV2.swift
//  Selektor
//
//  Created by Casey Marshall on 2/7/23.
//

import Foundation
import RealmSwift
import CoreData

extension URL: FailableCustomPersistable {
    public var persistableValue: String {
        get {
            return self.absoluteString
        }
    }
    
    public init?(persistedValue: String) {
        if let u = URL(string: persistedValue) {
            self = u
        } else {
            return nil
        }
    }
    
    public typealias PersistedType = String
}

class ConfigV2: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var alertTimeSensitive: Bool = false
    @Persisted var alertType: AlertType = .none
    @Persisted var alertSound: Bool = false
    @Persisted var elementIndex: Int = 0
    @Persisted var index: Int
    @Persisted var isWatchWidget: Bool = false
    @Persisted var isWidget: Bool = false
    @Persisted var lastError: String? = nil
    @Persisted var lastFetch: Date? = nil
    @Persisted var lastValue: Result? = nil
    @Persisted var name: String
    @Persisted var resultType: ResultType = .String
    @Persisted var selector: String = ""
    @Persisted var triggerInterval: TimeDuration = TimeDuration(value: 1, units: .Days)
    @Persisted var url: URL? = nil
    
    convenience init(index: Int, name: String) {
        self.init()
        self.index = index
        self.name = name
    }
    
    convenience init(oldConfig: Config) {
        self.init()
        self.alertTimeSensitive = oldConfig.alertTimeSensitive
        self.alertType = oldConfig.alertType
        self.alertSound = oldConfig.alertSound
        self.elementIndex = Int(oldConfig.elementIndex)
        self.index = Int(oldConfig.index)
        self.isWatchWidget = oldConfig.isWatchWidget
        self.isWidget = oldConfig.isWidget
        self.lastError = oldConfig.lastError
        self.lastFetch = oldConfig.lastFetch
        self.lastValue = oldConfig.result
        self.name = oldConfig.name ?? "Config \(oldConfig.index)"
        self.resultType = oldConfig.resultTypeValue
        self.triggerInterval = TimeDuration(value: UInt(oldConfig.triggerInterval), units: TimeUnit.forTag(tag: oldConfig.triggerIntervalUnits))
        self.url = oldConfig.url
    }
    
    var nextFireDate: Date {
        get {
            return lastFetch?.addingTimeInterval(triggerInterval.toTimeInterval()) ?? Date(timeIntervalSince1970: 0)
        }
    }
}

class HistoryV2: Object, ObjectKeyIdentifable {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var configId: ObjectId
    @Persisted var date: Date
    @Persisted var error: String?
    @Persisted var result: Result?
    
    convenience init(configId: ObjectId, date: Date, error: String? = nil, result: Result? = nil) {
        self.init()
        self.configId = configId
        self.date = date
        self.error = error
        self.result = result
    }
}

class PersistenceV2: ObservableObject {
    static let shared = PersistenceV2()
    static let readOnly = PersistenceV2(readOnly: true)
    
    let config: Realm.Configuration
    
    var realm: Realm {
        get throws {
            try Realm(configuration: config)
        }
    }
    
    static var preview = {
        let p = PersistenceV2(inMemory: true)
        if let realm = try? p.realm {
            try? realm.write {
                realm.add(ConfigV2(index: 0, name: "Test Config 1"))
                realm.add(ConfigV2(index: 1, name: "Test Config 2"))
                realm.add(ConfigV2(index: 2, name: "Test Config 3"))
            }
        }
        return p
    }()
    
    init(inMemory: Bool = false, readOnly: Bool = false) {
        if inMemory {
            config = Realm.Configuration(inMemoryIdentifier: "preview")
        } else {
            let storeUrl = AppGroup.main.containerUrl.appending(component: "main.realm")
            config = Realm.Configuration(fileURL: storeUrl, readOnly: readOnly)
        }
    }
    
    func checkConfigsToRun() throws -> [ConfigV2] {
        let now = Date()
        return try realm.objects(ConfigV2.self).filter { config in
            let lastFetch = config.lastFetch ?? Date(timeIntervalSince1970: 0)
            let nextFetch = lastFetch.advanced(by: config.triggerInterval.toTimeInterval())
            return config.url != nil && config.selector.notBlank() != nil && nextFetch <= now
        }
    }
    
    func deleteConfig(realm: Realm, config: ConfigV2) throws {
        try realm.write {
            let toKeep = realm.objects(ConfigV2.self).filter { c in c.id != config.id }
            toKeep.forEach { c in
                if c.index >= config.index {
                    c.index -= 1
                }
            }
            realm.delete(config)
        }
    }
    
    func migrateFromCoreData() throws {
        let fetchRequest = NSFetchRequest<Config>(entityName: "Config")
        let configs = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
        let historyRequest = NSFetchRequest<History>(entityName: "History")
        let history = try PersistenceController.shared.container.viewContext.fetch(historyRequest)
        let realm = try realm
        try realm.write {
            configs.forEach { config in
                let newConfig = ConfigV2(oldConfig: config)
                realm.add(newConfig)
                logger.debug("added config: \(newConfig)")
                history.filter { c in c.id == config.id }.forEach { h in
                    let newHistory = HistoryV2(configId: newConfig.id, date: h.date!, error: h.error, result: h.result)
                    realm.add(newHistory)
                    logger.debug("added history entry \(newHistory)")
                }
            }
        }
    }
    
    func handleResult(id: ObjectId, result: Result?, error: Error?) {
        do {
            let realm = try self.realm
            try realm.write {
                if let config = realm.object(ofType: ConfigV2.self, forPrimaryKey: id) {
                    let now = Date()
                    config.lastFetch = now
                    config.lastValue = result
                    config.lastError = error?.localizedDescription
                    
                    let newHistory = HistoryV2(configId: id, date: now, error: error?.localizedDescription, result: result)
                    let oldHistory = realm.objects(HistoryV2.self).where { h in
                        h.configId == id
                    }.sorted(by: { (a, b) in
                        a.date < b.date
                    }).dropLast(19)
                    for h in oldHistory {
                        realm.delete(h)
                    }
                    realm.add(newHistory)
                }
            }
        } catch {
            logger.error("failed to write back results: \(error)")
        }
    }
}
