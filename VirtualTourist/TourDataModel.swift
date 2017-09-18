//
//  TourDataModel.swift
//  VirtualTourist
//
//  Created by Krishna Picart on 7/11/17.
//  Copyright © 2017 StepwiseDesigns. All rights reserved.
//

import Foundation
import MapKit

 class TourDataModel: NSObject {
    
    var imageData = Data()
    var tourImages = [Data]()
    
    var compareGeoString = ""
    var geoCoordinates = CLLocationCoordinate2D()
    
    //var imageArrayCount = 0
    var arrayOfURLstrings = [String]()

    //helper func to start/stop/ activityIndicatorView based on its current state in the VC
    func activityViewManager(_ activtyIndicator: UIActivityIndicatorView){
        
        let activityState = activtyIndicator.isAnimating
        
        if activityState == true {
            activtyIndicator.stopAnimating()

        } else {
            activtyIndicator.startAnimating()
            
        }
    }
    
class func sharedInstance() -> TourDataModel {
        struct Singleton {
            static var sharedInstance =  TourDataModel()
        }
    return Singleton.sharedInstance
    }
}
