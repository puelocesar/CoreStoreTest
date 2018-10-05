//
//  DataBaseManager.swift
//  CoreStoreTest
//
//  Created by Paulo Cesar Ferreira on 05.10.18.
//  Copyright © 2018 teste. All rights reserved.
//

import UIKit
import CoreStore
import SwiftyJSON

typealias ParseCompletion<T: BaseModel> = (_ objects: [T]?, _ error: NSError?) -> Void

class BaseModel: CoreStoreObject, ImportableUniqueObject {

    // MARK: ImportableUniqueObject

    typealias UniqueIDType = String
    typealias ImportSource = JSON

    class var uniqueIDKeyPath: String { fatalError("must override") }
    class func uniqueID(from source: ImportSource, in transaction: BaseDataTransaction) throws -> String? { fatalError("must override") }
    func update(from source: ImportSource, in transaction: BaseDataTransaction) throws { fatalError("must override") }
}

class TestModel: BaseModel {
    override static var uniqueIDKeyPath: String {
        return String(keyPath: \TestModel.id)
    }

    override static func uniqueID(from source: JSON, in transaction: BaseDataTransaction) throws -> String? {
        return source["id"].string
    }

    override func update(from source: JSON, in transaction: BaseDataTransaction) throws {
        id .= source["id"].string ?? ""
        name .= source["name"].string ?? ""
    }

    let id = Value.Required<String>("id", initial: "")
    let name = Value.Required<String>("name", initial: "")
}

class DatabaseManager {
    static let shared = DatabaseManager()
    private init() {}

    func setupCoredata(progressHandler: @escaping (Progress) -> Void, then completion: @escaping () -> Void) {
        CoreStore.defaultStack = DataStack(
            CoreStoreSchema(
                modelVersion: "V1",
                entities: [
                    Entity<TestModel>("TestModel"),
                ]
            )
        )

        let storage = SQLiteStore(fileName: "Test.sqlite")
        let _ = CoreStore.addStorage(storage, completion: { (result) in
            switch result {
            case .success:
                completion()
            case .failure(let error):
                fatalError("could not setup coredata: \(error.localizedDescription)")
            }
        })
    }

    func importObjects<T: BaseModel, S: Sequence>(into: T.Type, source: S, completion: @escaping ParseCompletion<T>)
        where S.Iterator.Element == T.ImportSource {

            CoreStore.perform(asynchronous: { (transaction) -> [T] in
                let imported = try transaction.importUniqueObjects(Into<T>(), sourceArray: source)
                return imported
            }, success: { (objects) in
                let fetchedObjects = CoreStore.fetchExisting(objects)
                completion(fetchedObjects, nil)
            }, failure: { (_) in
                completion(nil, nil)
            })
    }
}
