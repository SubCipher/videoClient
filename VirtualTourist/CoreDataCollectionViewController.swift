//
//  CoreDataCollectionViewController.swift
//  VirtualTourist
//
//  Created by Krishna Picart on 7/14/17.
//  Copyright © 2017 StepwiseDesigns. All rights reserved.
//

import UIKit
import CoreData
import MapKit


class CoreDataCollectionViewController: UIViewController, UIGestureRecognizerDelegate, UICollectionViewDelegate {
    
    var searchKey = ""
    let stack = TourCoreDataStack(modelName: "VR_Tourist")
    lazy var fetchRequest = NSFetchRequest<NSFetchRequestResult>()
    
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>? {
        
        didSet {
        // Whenever the frc changes execute search
            fetchedResultsController?.delegate = self
            performCollectionSearch()
        }
    }
    
    
    var isDeviceVertical = true
    let apiMethods = APImethods()
    let tourDataModel = TourDataModel()
    var coordinates: CLLocationCoordinate2D?
    var placeholderArray = [UIImage]()
    
    
    var cellPlaceHolder = UIImage(named: "placeholder")
    private let refreshControl = UIRefreshControl()
    
    @IBOutlet weak var newSelectionOutlet: UIButton!
    @IBOutlet weak var flowViewLayout: UICollectionViewFlowLayout!
    @IBOutlet var coreDataCollectionVCoutlet: UICollectionView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        coreDataCollectionVCoutlet.refreshControl = refreshControl
        coreDataCollectionVCoutlet.delegate = self
        coreDataCollectionVCoutlet.dataSource = self
        
           }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //scroll update for view controller
        refreshControl.addTarget(self, action: #selector(refreshTourData(_:)), for: .valueChanged)
        
        //fetch photos here to eliminate time loading and displaying
        fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "text", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "text = %@", searchKey)
        
        // Create the FetchedResultsController
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: (stack?.context)!, sectionNameKeyPath: nil, cacheName: nil)
        
        //fetch Pin to store current site coordinates to regen images
        let pinFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Pin")
        
        pinFetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        pinFetchRequest.predicate = NSPredicate(format: "name = %@", searchKey)
        
        
        do { let pinSearchResults = try self.stack?.context.fetch(pinFetchRequest)
            for pin in pinSearchResults as! [Pin] {   self.coordinates = CLLocationCoordinate2DMake(pin.latitude, pin.longitude) }  }
            
        catch {  print("Could Not Get Coordinates",error)  }  }
    
    
    @objc private func refreshTourData(_ sender: Any) {
        
        DispatchQueue.main.async {  self.coreDataCollectionVCoutlet.reloadData()
            self.refreshControl.endRefreshing()
        }
    }
    
    internal override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        isDeviceVertical = traitCollection.verticalSizeClass == .compact ? false : true
        
        
        let space: CGFloat = isDeviceVertical == true ? 2 : 5
        flowViewLayout.minimumInteritemSpacing = 0
        flowViewLayout.minimumLineSpacing = isDeviceVertical == true ? 5 : 2
        
        let dimensionWidthMultiplyer = isDeviceVertical == true ? CGFloat(3) : CGFloat(2)
        let dimensionHeightMultipler = isDeviceVertical == true ? CGFloat(2) : CGFloat(3)
        
        //dimenision of cells
        let dimensionWidthDivisor = isDeviceVertical == true ? CGFloat(3) : CGFloat(4)
        let dimensionHeightDivisor = isDeviceVertical == true ? CGFloat(4) : CGFloat(3)
        
        let dimensionW = (view.frame.size.width - (dimensionWidthMultiplyer * space)) / dimensionWidthDivisor
        let dimensionH = (view.frame.size.height - (dimensionHeightMultipler * space)) / dimensionHeightDivisor
        
        flowViewLayout.itemSize = CGSize(width: dimensionW,height: dimensionH)
    }
    
    //used to get approx coordinates if site is removed before saved to coredata
    func getLatANDLongFromNetwork(_ coordString: String)->CLLocationCoordinate2D {
        
        //guard return value for failed coordinates
        let defaultCoord = CLLocationCoordinate2DMake(39.000000000000000, -101.000000000000000)
        let locAsString = filterSearchKey(coordString)
        
        guard let geoCoorLat = Double(locAsString[0]) else { print("coordinates not found");  return defaultCoord  }
        
        guard let geoCoorLong = Double(locAsString[1]) else {  print("coordinates not found");  return defaultCoord }
        
        let geoConvertedCoors = CLLocationCoordinate2DMake(geoCoorLat, geoCoorLong);  return geoConvertedCoors }
    
    func filterSearchKey(_ targetStr: String)->[String] {
        
        //filter site coordinates,from API: used for NEW images displayed direct from network
        var targetResponse = targetStr
        var indexCount = 0
        var matchArray = [Int]()
        let charToMatch = Character("+")
        var geoString = [String]()
        
        
        for i in targetStr.characters {
            
            if charToMatch == i {  matchArray.append(indexCount)  }; indexCount += 1  }
        
        let charToMatchIndex = matchArray.max()
        let start = targetResponse.characters.startIndex
        let filterRange = targetStr.characters.index(start, offsetBy: charToMatchIndex!)
        let range = (targetResponse.startIndex...filterRange)
        
        targetResponse.characters.removeSubrange(range)
        
        if targetResponse.characters.contains(">"){
            targetResponse.characters.removeSubrange(targetResponse.characters.index(of: ">")!...targetResponse.characters.index(before: targetResponse.characters.endIndex))
            //split flitered String into lat and long for coordinate conversion
            geoString = targetResponse.components(separatedBy: ",")
        }
        return geoString
    }
    
    //Mark:- Delete all objects in current context
    func deletePhotoInFetch(_ completionHanderlForPhotoDelete: @escaping (_ success:Bool,_ error:String)-> Void ) {
        
        let delFetchReq = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        //batch delete coredata photos
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: (stack?.context)!, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try self.stack?.context.execute(delFetchReq)
            performCollectionSearch()
            try self.stack?.context.save()
            
            completionHanderlForPhotoDelete(true,"")
            
        } catch {  completionHanderlForPhotoDelete(false,"\(error)")   } }
    
    
    @IBAction func newSelectionAction(_ sender: UIButton) {
        newSelectionOutlet.isEnabled = false
        
        self.deletePhotoInFetch({ (success, error) in
            guard success == true else {  return }
            self.tourReloaded()
            
        })
    }
}
//MARK:- CollectionView Extension
extension CoreDataCollectionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var itemsInSection = 0
        if (self.fetchedResultsController?.fetchedObjects?.count)! == 0 { itemsInSection = TourDataModel.sharedInstance().arrayOfURLstrings.count }
            
        else {
            TourDataModel.sharedInstance().arrayOfURLstrings.removeAll()
            itemsInSection = (self.fetchedResultsController?.fetchedObjects?.count)! }
        
    return itemsInSection
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
       
        let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "tourCollectionViewCell", for: indexPath) as? TourCollectionViewCell)!
        
        //Display placeholder on slow connections
        cell.tourImageForCell.image = cellPlaceHolder
        
        /* image downloads are initiated in the mapViewConroller, this helps eliminate load time on fast connections and only shows the placeholder on slow connections 
         see:
         Last entry for project suggestions
         https://review.udacity.com/#!/rubrics/22/view
         
         https://discussions.udacity.com/t/background-queue-and-space-holders-images/357922/2
         */
        
        if   (self.fetchedResultsController?.fetchedObjects?.count)! == 0 {
            let conversionQueue = DispatchQueue(label: "com.stepwisedesigns.conversionQueue", qos: .background)
            
            conversionQueue.asyncAfter(deadline: DispatchTime.now() + .seconds(0)) {
                //get the URLs from URLSession task and download its contents
                    guard let imageURL = URL(string: TourDataModel.sharedInstance().arrayOfURLstrings[indexPath.item]) else {
                    return
                }
                
                guard let imageData = try? Data(contentsOf: imageURL) else {
                    return
                }
                
                DispatchQueue.main.async {
                    //convert data and assign resulting UIImage to the cell
                    cell.tourImageForCell.image = self.cellPlaceHolder
                    cell.tourImageForCell.image =  UIImage(data: imageData)
                    cell.cellTextForImage.text = self.searchKey
                    cell.cellActivityIndicatorOutlet.stopAnimating()
                }
            }
        }
        else {
            if (self.fetchedResultsController?.fetchedObjects?.count)! > 0 {
                //use core data images once they're available
                let photo = self.fetchedResultsController!.object(at: indexPath) as! Photo
                
                //load cellPlaceholder if conversion fails
                guard let tourImage = UIImage(data: (photo.photoFromTour)!) else {
                    
                    cell.setImageForCell(cellPlaceHolder!)
                    cell.cellTextForImage.text = "image not available"
                    return cell
                }
                DispatchQueue.main.async {

                cell.cellActivityIndicatorOutlet.stopAnimating()
                cell.setImageForCell(tourImage)
                cell.cellTextForImage.text = photo.text
                cell.cellActivityIndicatorOutlet.stopAnimating()
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        performCollectionSearch()
       
        //delete core data and reset the array:
        //NOTE the cellImage/ item at indexPath is deleted via delegate in the extension once the coredata reference is removed

            if (self.fetchedResultsController?.fetchedObjects?.count)! > 0 {
                
                if let context = self.fetchedResultsController?.managedObjectContext, let tourImage = self.fetchedResultsController?.object(at:
                    indexPath) as? Photo {
                    context.delete(tourImage)
                    stack?.save()
                }
            }
        }
    }


// MARK: - CoreDataCollectionViewController (Fetches)

extension CoreDataCollectionViewController{
    
    func performCollectionSearch() {
        
        if let fc = fetchedResultsController {
            do {  try fc.performFetch() }
            catch let fetchError as NSError {
                print("Error while trying to perform a search: \n\(fetchError)\n\(String(describing: fetchedResultsController))")
            }
        }
    }
}

// MARK: - CoreDataCollectionViewController: NSFetchedResultsControllerDelegate

extension CoreDataCollectionViewController: NSFetchedResultsControllerDelegate {
    
    //didChange sectionInfo
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        let set = IndexSet(integer: sectionIndex)
        
        switch (type) {
        case .insert:
            coreDataCollectionVCoutlet?.insertSections(set)
        case .delete:
            coreDataCollectionVCoutlet?.deleteSections(set)
        default:
            break
        }
    }
    
    
    //didChange anObject
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch(type) {
        case .insert:
            coreDataCollectionVCoutlet?.insertItems(at: [newIndexPath!])
        case .delete:
            coreDataCollectionVCoutlet?.deleteItems(at: [indexPath!])
        case .update:
            coreDataCollectionVCoutlet?.reloadItems(at: [indexPath!])
        case .move:
            coreDataCollectionVCoutlet?.deleteItems(at: [indexPath!])
            coreDataCollectionVCoutlet?.insertItems(at: [newIndexPath!])
        }
    }
    
    func tourReloaded(){
        TourDataModel.sharedInstance().compareGeoString = searchKey
        
        if self.coordinates == nil {
            self.coordinates = getLatANDLongFromNetwork(searchKey)
        }
        apiMethods.geoSearch(self.coordinates!, completionHandlerForGeoSearch: { (success,error ) in
            if success == true {
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(0)) {
                    self.performCollectionSearch()
                    self.coreDataCollectionVCoutlet?.reloadData()
                    self.newSelectionOutlet.isEnabled = true
                }
            } else {
                let actionSheet = UIAlertController(title: "Session ERROR", message: error, preferredStyle: .alert)
                
                actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                self.present(actionSheet,animated: true, completion: nil)
            }
        })
    }
    
    //controllerDidChangeContent
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if self.fetchedResultsController?.fetchedObjects?.count == 0 {
            tourReloaded()
            //self.newSelectionOutlet.isEnabled = false
        }
    }
}
