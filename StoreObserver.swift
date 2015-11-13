//
//  StoreObserver.swift
//
/// Abstract:
/// Implements the SKPaymentTransactionObserver protocol. Handles purchasing and restoring products
/// as well as downloading hosted content using paymentQueue:updatedTransactions: and paymentQueue:updatedDownloads:,
/// respectively. Provides download progress information using SKDownload's progres. Logs the location of the downloaded
/// file using SKDownload's contentURL property.

import Foundation
import StoreKit

let IAPPurchaseNotification = "IAPPurchaseNotification"

enum IAPPurchaseNotificationStatus : Int {
    case PurchaseFailed = 0      // Indicates that the purchase was unsuccessful
    case PurchaseSucceeded = 1   // Indicates that the purchase was successful
    case RestoredFailed = 2      // Indicates that restoring products was unsuccessful
    case RestoredSucceeded = 3   // Indicates that restoring products was successful
    case DownloadStarted = 4     // Indicates that downloading a hosted content has started
    case DownloadInProgress = 5  // Indicates that a hosted content is currently being downloaded
    case DownloadFailed = 6      // Indicates that downloading a hosted content failed
    case DownloadSucceeded = 7   // Indicates that a hosted content was successfully downloaded
}


class StoreObserver : NSObject, SKPaymentTransactionObserver {
    var Status : IAPPurchaseNotificationStatus?
    
    // Keep track of all purchases
    var ProductsPurchased : [SKPaymentTransaction] = []

    // Keep track of all restored purchases
    var ProductsRestored : [SKPaymentTransaction] = []

    var Message : String?

    var DownloadProgress : Float?

    // Keep track of the purchased/restored product's identifier
    var PurchasedID : String?

    /// Has purchased products
    /// Returns whether there are purchased products
    var HasPurchasedProducts : Bool {
        // productsPurchased keeps track of all our purchases.
        // Returns YES if it contains some items and NO, otherwise
        return self.ProductsPurchased.count > 0;
    }
    
    /// Has restored products
    /// Returns whether there are restored purchases
    var HasRestoredProducts : Bool {
        // productsRestored keeps track of all our restored purchases.
        // Returns YES if it contains some items and NO, otherwise
        return self.ProductsRestored.count > 0;
    }


    static let Instance = StoreObserver()
    
    private override init() {
        super.init()
        
        self.ProductsPurchased = []
        self.ProductsRestored = []
    }
    
    /// Make a purchase
    /// Create and add a payment request to the payment queue
    func Buy(product:SKProduct) {
        let payment = SKMutablePayment(product: product)
        SKPaymentQueue.defaultQueue().addPayment(payment)
    }
    
    /// Restore purchases
    func Restore() {
        self.ProductsRestored = []
        SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
    }
    
    /// SKPaymentTransactionObserver methods
    // Called when there are trasactions in the payment queue
    func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions
        {
            switch (transaction.transactionState )
            {
            case .Purchasing:
                print("Store Observer -> Payment Queue: Purchasing")
                break;
                
            case .Deferred:
                // Do not block your UI. Allow the user to continue using your app.
                print("Store Observer -> Payment Queue: Allow the user to continue using your app.")
                
                // The purchase was successful
            case .Purchased:
                self.PurchasedID = transaction.payment.productIdentifier
                self.ProductsPurchased.append(transaction)
                
                print("Store Observer -> Payment Queue: Deliver content for \(transaction.payment.productIdentifier)")
                self.Status = IAPPurchaseNotificationStatus.PurchaseSucceeded
                NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
                
                // not in original code, 
                //NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
                
                // Check whether the purchased product has content hosted with Apple.
                if transaction.downloads.count > 0 {
                    self.CompleteTransaction(transaction, forStatus: .DownloadStarted)
                }
                else {
                    self.CompleteTransaction(transaction, forStatus: .PurchaseSucceeded)
                }
                
                // There are restored products
            case .Restored:
                self.PurchasedID = transaction.payment.productIdentifier;
                self.ProductsRestored.append(transaction)
                
                print("Store Observer -> Payment Queue: Restore content for \(transaction.payment.productIdentifier)");
                // Send a IAPDownloadStarted notification if it has
                if transaction.downloads.count > 0 {
                    self.CompleteTransaction(transaction, forStatus: .DownloadStarted)
                }
                else
                {
                    self.CompleteTransaction(transaction, forStatus: .RestoredSucceeded)
                }
                // The transaction failed
            case .Failed:
                self.Message = "Store Observer -> Payment Queue: Purchase of \(transaction.payment.productIdentifier) failed."
                self.CompleteTransaction(transaction, forStatus: .PurchaseFailed)

            }
        }
    }
    
    // Called when the payment queue has downloaded content
    func paymentQueue(queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        for download in downloads {
            switch (download.downloadState) {
                case .Active:
                    // The content is being downloaded. Let's provide a download progress to the user
                    self.Status = .DownloadInProgress;
                    self.PurchasedID = download.transaction.payment.productIdentifier;
                    self.DownloadProgress = download.progress*100;
                    print("Store Observer -> Payment Queue: Download is active - \(self.DownloadProgress)")
                    
                    NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
                    
                case .Cancelled:
                    // StoreKit saves your downloaded content in the Caches directory. Let's remove it
                    // before finishing the transaction.
                    do {
                        print("Store Observer -> Payment Queue: Download was cancelled")
                        try NSFileManager.defaultManager().removeItemAtURL(download.contentURL!)
                        self.FinishDownloadTransaction(download.transaction)
                        
                    } catch {
                        print("Store Observer -> Problem removing downloaded content from the caches directory")
                    }
                    NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
                    
                case .Failed:
                    // If a download fails, remove it from the Caches, then finish the transaction.
                    // It is recommended to retry downloading the content in this case.
                    do {
                        print("Store Observer -> Payment Queue: Download failed")
                        try NSFileManager.defaultManager().removeItemAtURL(download.contentURL!)
                        self.FinishDownloadTransaction(download.transaction)
                        
                    } catch {
                        print("Store Observer -> Payment Queue: Problem removing downloaded content from the caches directory")
                    }
                    NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
                    
                case .Paused:
                    print("Store Observer -> Payment Queue: Download was paused")
                    NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
                    
                case .Finished:
                    // Download is complete. StoreKit saves the downloaded content in the Caches directory.
                    print("Store Observer -> Payment Queue: Download Finished")
                    //print ("Store Observer -> Payment Queue: Location of downloaded file \(download.contentURL)")
                    self.ProcessDownload(download)
                    self.FinishDownloadTransaction(download.transaction)
                    NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
                
                case .Waiting:
                    print("Store Observer -> Payment Queue: Download Waiting")
                    SKPaymentQueue.defaultQueue().startDownloads([download]);
            }
        }
        
    }
    
    /// We cycle through files made available
    /// http://xinsight.ca/blog/iap-content-download-in-ios6/
    func ProcessDownload(download:SKDownload){
        let pathCheck = download.contentURL?.path
        
        // if path is empty, something is terribly wrong
        if pathCheck == nil {
            return
        }
        
        // file should be a zip file
        // path will look like the following
        // "/private/var/mobile/Containers/Data/Application/(guid)/Library/Caches/(random unique name).zip"
        // we want to work with NSString in order to use stringByAppendingPathComponent
        var downloadedFilesPath : NSString = pathCheck! as NSString
        
        // the zip file can be accessed like any other directory
        // downloadable content file will have a "Contents" directory
        // path will now look like the following
        // "/private/var/mobile/Containers/Data/Application/(guid)/Library/Caches/(random unique name).zip/Contents"
        downloadedFilesPath = downloadedFilesPath.stringByAppendingPathComponent("Contents")
        
        let fileManager = NSFileManager.defaultManager()
        
        do {
            let files = try fileManager.contentsOfDirectoryAtPath(downloadedFilesPath as String)
            
            // /var/mobile/Containers/Data/Application/(guid)/Library/Application Support/Downloads
            let destinationPath = self.DownloadableContentPath as NSString
            
            // cycle through each of the files
            // 1) remove any existing files if they exist in destination (note, can't simply overwrite)
            // 2) move the files to destination
            for file in files {
                
                let downloadedFilePath = downloadedFilesPath.stringByAppendingPathComponent(file)
                let destinationFilePath = destinationPath.stringByAppendingPathComponent(file)
                
                print ("Store Observer -> *********************************************************")
                print ("Store Observer -> *** Current Downloaded File: \(downloadedFilePath)")
                print ("Store Observer -> *** Current Destination File: \(destinationFilePath)")
                
                // not allowed to overwrite files - remove destination file
                do {
                    try fileManager.removeItemAtPath(destinationFilePath)
                    print("Store Observer -> Removed old file \"\(file)\" from Application Support")
                }
                catch let error as NSError {
                    print ("Store Observer -> Unable or unneccessary to remove file -> \(error.localizedDescription)")
                }
                
                // move the file
                do {
                    try fileManager.moveItemAtPath(downloadedFilePath, toPath: destinationFilePath)
                    
                    print("Store Observer -> Moved new downloaded \"\(file)\" to Application Support")
                }
                catch let error as NSError {
                    print("Store Observer -> \(error.localizedDescription)")
                }
            }
        } catch let error as NSError {
            print("Store Observer -> ERROR: Unable to completely load files  \(error.localizedDescription)")
        }
        
    }
    
    
    
    /// Reference to path where new files will be placed for the app to work with
    /// For iOS, makes use of the Library folder called Application Support
    /// Application Support files are not visible to the user (thus, can't download raw files)
    /// User could still use backup, we however flag the new folder to be excluded from backup
    /// This conforms to best practice for Downloadable IAP Content
    var DownloadableContentPath : String {
        var paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.ApplicationSupportDirectory,.UserDomainMask, true)
        
        var directory = paths[0] as NSString
        directory = directory.stringByAppendingPathComponent("Downloads")
        
        let fileManager = NSFileManager.defaultManager()
        
        if fileManager.fileExistsAtPath(directory as String) == false {
            
            do {
                try fileManager.createDirectoryAtPath(directory as String, withIntermediateDirectories: true, attributes: nil)
                print("Store Observer -> Directory created -> \(directory)")
            } catch let error as NSError {
                print("Store Observer -> ERROR: Unable to create directory -> \(error.localizedDescription)");
            }
            let url = NSURL(fileURLWithPath: directory as String)
            do {
                try url.setResourceValue(NSNumber(bool: true), forKey: NSURLIsExcludedFromBackupKey)
                print("Store Observer -> Excluded directory from backup")
            }
            catch let error as NSError {
                print("Store Observer -> ERROR: Unable to exclude directory from backup -> \(error.localizedDescription)")
            }
        }
        return directory as String
    }

    
    // Logs all transactions that have been removed from the payment queue
    func paymentQueue(queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
        for transaction in transactions {
            print("Store Observer -> Payment Queue: \(transaction.payment.productIdentifier) was removed from the payment queue.");
        }
    }
    
    // Called when an error occur while restoring purchases. Notify the user about the error.
    func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {
    
        if error.code != SKErrorPaymentCancelled
        {
            self.Status = .RestoredFailed;
            self.Message = error.localizedDescription;
            NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
        }
    }

    // Called when all restorable transactions have been processed by the payment queue
    func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
        print("Store Observer -> Payment Queue: All restorable transactions have been processed by the payment queue.");
    }
    
    
    /// Complete transaction
    
    /// Notify the user about the purchase process. Start the download process if status is
    /// IAPDownloadStarted. Finish all transactions, otherwise.
    func CompleteTransaction(transaction:SKPaymentTransaction, forStatus status:IAPPurchaseNotificationStatus)
    {
        self.Status = status;
    
        //Do not send any notifications when the user cancels the purchase
        if transaction.error != nil && transaction.error!.code != SKErrorPaymentCancelled {
            // Notify the user
            NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
        }
        if status == .DownloadStarted {
            // The purchased product is a hosted one, let's download its content
            SKPaymentQueue.defaultQueue().startDownloads(transaction.downloads)
            
            NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
        } else if status == .PurchaseSucceeded || status == .RestoredSucceeded {
            NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
            SKPaymentQueue.defaultQueue().finishTransaction(transaction)
        } else {
            // Remove the transaction from the queue for purchased and restored statuses
            SKPaymentQueue.defaultQueue().finishTransaction(transaction)
        }
    }
    
    
    /// Handle download transaction
    func FinishDownloadTransaction(transaction:SKPaymentTransaction) {
        
        //allAssetsDownloaded indicates whether all content associated with the transaction were downloaded.
        var allAssetsDownloaded = true;
        
        // A download is complete if its state is SKDownloadStateCancelled, SKDownloadStateFailed, or SKDownloadStateFinished
        // and pending, otherwise. We finish a transaction if and only if all its associated downloads are complete.
        // For the SKDownloadStateFailed case, it is recommended to try downloading the content again before finishing the transaction.
        for download in transaction.downloads {
            
            if download.downloadState != .Cancelled &&
                download.downloadState != .Failed &&
                download.downloadState != .Finished {
                
                    //Let's break. We found an ongoing download. Therefore, there are still pending downloads.
                    allAssetsDownloaded = false;
                    break;
            }
        }
        
        // Finish the transaction and post a IAPDownloadSucceeded notification if all downloads are complete
        if allAssetsDownloaded {
            self.Status = .DownloadSucceeded;
        
            SKPaymentQueue.defaultQueue().finishTransaction(transaction)
            NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
        
            if self.ProductsRestored.contains(transaction) {
                self.Status = .RestoredSucceeded;
                NSNotificationCenter.defaultCenter().postNotificationName(IAPPurchaseNotification, object: self)
            }
        
        }
    }
}
