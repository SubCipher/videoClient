 //
//  AppDelegate.swift
//  VirtualTourist
//
//  Created by Krishna Picart on 7/8/17.
//  Copyright © 2017 StepwiseDesigns. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let stack = TourCoreDataStack(modelName: "VR_Tourist")!
    //let tourDataModel = TourDataModel()
    
    //Preload data
    func preloadData() {
        
        do {  try stack.dropAllData() } catch {  print("error dropping all objects")  }  }
 
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
       //preloadData()
        stack.autoSave(180)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) { stack.save()  }

    func applicationDidEnterBackground(_ application: UIApplication) { stack.save() }
    
}



