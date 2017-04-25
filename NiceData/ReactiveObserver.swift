//
//  File.swift
//  Median
//
//  Created by Vojtech Rinik on 28/11/2016.
//  Copyright © 2016 Vojtech Rinik. All rights reserved.
//

import Foundation
import CoreData
import ReactiveSwift


public typealias CDCallback = (([NSManagedObject]) -> ())

public class ReactiveObserver<T: NSManagedObject>: CDObserver {
    public var objects = MutableProperty<[T]>([])
    
    override public func fetch() {
        super.fetch()
        
        objects.value = self.results as! [T]
    }
}

public class CDObserver: NSObject {
    let context: NSManagedObjectContext
    let request: NSFetchRequest<NSFetchRequestResult>
    public var callback: CDCallback?
    var includeChanges: Columns
    dynamic var results = [NSManagedObject]()
    
    public enum Columns {
        case all
        case some(Set<String>)
        case none
    }
    
    public init(context: NSManagedObjectContext, request: NSFetchRequest<NSFetchRequestResult>, includeChanges: Columns = .all, callback: CDCallback? = nil) {
        self.context = context
        self.request = request
        self.callback = callback
        self.includeChanges = includeChanges
        
        super.init()
        
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleObjectsChanged(notification:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: context)
        
        fetch()
    }
    
    public func fetch() {
        do {
            let results = try context.fetch(request) as! [NSManagedObject]
            self.results = results
            callback?(results)
        } catch _ {
            print("Failed executing fetch request \(request)")
        }
    }
    
    public var onObjectsChanged: (([NSManagedObject]) -> ())?
    
    func handleObjectsChanged(notification: NSNotification) {
        let changedObjects = CDObserver.changedObjects(forNotification: notification, includeChanges: self.includeChanges)
        var changedEntities = Set<String>()
        
        onObjectsChanged?(Array(changedObjects))
        
        for object in changedObjects {
            let entityName = object.entity.name!
            changedEntities.insert(entityName)
        }
        
        if changedEntities.contains(request.entityName!) {
            fetch()
        }
    }
    
    public static func changedObjects(forNotification notification: NSNotification, includeChanges: Columns = .all) -> Set<NSManagedObject> {
        let userInfo = notification.userInfo!
        
        var changedObjects = Set<NSManagedObject>()
        
        for object in (userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? Set() {
            changedObjects.insert(object)
        }
        
        for object in (userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>) ?? Set() {
            changedObjects.insert(object)
        }
        
        let updatedObjects = (userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? Set()
        
        switch includeChanges {
        case .all:
            for updatedObject in updatedObjects {
                changedObjects.insert(updatedObject)
            }
        case .some(let columns):
            for updatedObject in updatedObjects {
                let changedKeys = Set(updatedObject.changedValuesForCurrentEvent().keys)
                
                for key in changedKeys {
                    if columns.contains(key) {
                        changedObjects.insert(updatedObject)
                        break
                    }
                }
            }
        case .none:
            break
        }
        

        return changedObjects
    }
    
    
    
    func cancel() {
        let center = NotificationCenter.default
        
        center.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: context)
    }
}


