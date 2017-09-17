//
//  CoreDataStack.swift
//  Created by Krishna Picart
//
//  Original Code by Fernando Rodríguez Romero on 21/02/16.
//  Copyright © 2016 udacity.com. All rights reserved.
//

import CoreData

// MARK: - CoreDataStack

struct TourCoreDataStack {
    
    // MARK: Properties
    
    private let model: NSManagedObjectModel
    internal let coordinator: NSPersistentStoreCoordinator
    private let modelURL: URL
    internal let dbURL: URL
    
    internal let persistingContext: NSManagedObjectContext
    internal let backgroundContext: NSManagedObjectContext
    
    let context: NSManagedObjectContext
    
    
    // MARK: Initializers
    
    init?(modelName: String) {
        
        // Assumes the model is in the main bundle
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
            print("Unable to find \(modelName)in the main bundle")
            return nil
        }
        self.modelURL = modelURL
        
        // Try to create the model from the URL
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            print("unable to create a model from \(modelURL)")
            return nil
        }
        self.model = model
        // Create the store coordinator
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        persistingContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        persistingContext.persistentStoreCoordinator = coordinator
        persistingContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        // create a context and add connect it to the coordinator
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = persistingContext
        //context.persistentStoreCoordinator = coordinator
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        
        backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        
        // Add a SQLite store located in the documents folder
        let fm = FileManager.default
        
        guard let docUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to reach the documents folder")
            return nil
        }
        
        //self.dbURL = docUrl.appendingPathComponent("VirtualTourist.sqlite")
        self.dbURL = docUrl.appendingPathComponent("model.sqlite")
        
        // Options for migration
        let options = [NSInferMappingModelAutomaticallyOption: true,NSMigratePersistentStoresAutomaticallyOption: true]
        
        do {
            try addStoreCoordinator(NSSQLiteStoreType, configuration: nil, storeURL: dbURL, options: options as [NSObject : AnyObject]?)
        } catch {
            print("unable to add store at \(dbURL)")
        }
    }
    
    // MARK: Utils
    
    
    static func getContext() -> NSManagedObjectContext{
        return persistentContainer.viewContext
    }
    
    static var persistentContainer: NSPersistentContainer = {
              let container = NSPersistentContainer(name: "VR_Tourist")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    
    func addStoreCoordinator(_ storeType: String, configuration: String?, storeURL: URL, options : [NSObject:AnyObject]?) throws {
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: nil)
    }
}

// MARK: - CoreDataStack (Removing Data)

internal extension TourCoreDataStack  {
    
    func dropAllData() throws {
        // delete all the objects in the db. This won't delete the files, it will
        // just leave empty tables.
        try coordinator.destroyPersistentStore(at: dbURL, ofType:NSSQLiteStoreType , options: nil)
        try addStoreCoordinator(NSSQLiteStoreType, configuration: nil, storeURL: dbURL, options: nil)
    }
}

// MARK: - CoreDataStack (Save Data)

extension TourCoreDataStack {
    typealias Batch = (_ workerContext: NSManagedObjectContext) -> ()
    func performBackgroundBatchOperation(_ batch: @escaping Batch) {
        backgroundContext.perform() {
            batch(self.backgroundContext)
            
            //save it to the parent context
            do {
                try self.backgroundContext.save()
            }
            catch {
                fatalError("Error while saving backgroundContext:\(error)")
                }
            }
        }
    }

extension TourCoreDataStack {
    
    func save() {
        context.performAndWait() {
            
            if self.context.hasChanges {
                do {
                    try self.context.save()
                } catch {
                    fatalError("Error while saving main context: \(error)")
                }
                
            //now save in the background
            self.persistingContext.perform() {
                do {
                   try self.persistingContext.save()
                } catch {
                    fatalError("Error while saving persisting context: \(error)")
                }
            }
        }
    }
}    
    func autoSave(_ delayInSeconds : Int) {
        
        if delayInSeconds > 0 {
            do {
                try self.context.save()
            } catch {
                print("Error while autosaving")
            }
            
            let delayInNanoSeconds = UInt64(delayInSeconds) * NSEC_PER_SEC
            let time = DispatchTime.now() + Double(Int64(delayInNanoSeconds)) / Double(NSEC_PER_SEC)
            
            DispatchQueue.main.asyncAfter(deadline: time) {
                self.autoSave(delayInSeconds)
            }
        }
    }
}


