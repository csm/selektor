//
//  Persistence.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for i in 0..<10 {
            let newConfig = Config(context: viewContext)
            newConfig.name = "Config \(i)"
            newConfig.index = Int32(i + 1)
            newConfig.id = UUID()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Selektor")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let storeUrl = AppGroup.main.containerUrl.appending(component: "main.sqlite")
            let description = NSPersistentStoreDescription(url: storeUrl)
            container.persistentStoreDescriptions = [description]
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                logger.error("error loading PersistenceController \(error) \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    static func checkConfigToRun() throws -> Config? {
        logger.info("checking if anything to refresh")
        let viewContext = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<Config>(entityName: "Config")
        let results = try viewContext.fetch(request)
        logger.debug("fetched configs \(results.count), \(results.map { r in "name: \(r.name) lastFetch: \(r.lastFetch) nextFireDate: \(r.nextFireDate) id: \(r.id) selector: \(r.selector) resultType: \(r.resultType)" })")
        let result = results.sorted {
            a, b in a.nextFireDate < b.nextFireDate
        }.first { config in
            config.url != nil && config.id != nil && config.selector?.notBlank() != nil && config.resultType != nil
        }
        logger.debug("next selector is \(result?.name ?? "<nil>") next fire date \(result?.nextFireDate)")
        if let r = result, r.nextFireDate <= Date() {
            return r
        }
        return nil
    }
    
    func deleteConfig(config: Config) {
        let viewContext = self.container.viewContext
        let fetchRequest = NSFetchRequest<Config>(entityName: "Config")
        do {
            let configs = try viewContext.fetch(fetchRequest).filter { c in c.id != config.id }
            for c in configs {
                if c.index > config.index {
                    c.index = c.index - 1
                }
            }
            viewContext.delete(config)
            try viewContext.save()
        } catch {
            logger.error("error deleting config: \(config)")
        }
    }
}
