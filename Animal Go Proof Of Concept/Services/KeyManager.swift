//
//  KeyManager.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/10/25.
//
import Foundation

struct KeyManager {
    
        static var apiKey: String {
        guard let url = Bundle.main.url(forResource: "Keys", withExtension: "plist") else {
            fatalError("Keys.plist not found. Did you add it to the project?")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not load data from Keys.plist")
        }
        
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            fatalError("Could not deserialize Keys.plist")
        }
        
        guard let key = plist["OPENAI_API_KEY"] as? String else {
            fatalError("OPENAI_API_KEY not found in Keys.plist")
        }
        
        return key
    }
}
