//
//  StoreManager.swift
//
///  Retrieves product information from the App Store using SKRequestDelegate,
///  SKProductsRequestDelegate,SKProductsResponse, and SKProductsRequest.
///  Notifies its observer with a list of products available for sale along with
///  a list of invalid product identifiers. Logs an error message if the product
///  request failed.

import Foundation
import StoreKit

// Provide notification about the product request
let IAPProductRequestNotification = "IAPProductRequestNotification";

enum IAPProductRequestStatus : Int {
    case ProductsFound = 0           // Indicates that there are some valid products
    case IdentifiersNotFound = 1     // indicates that are some invalid product identifiers
    case ProductRequestResponse = 2  // Returns valid products and invalid product identifiers
    case RequestFailed = 4           // Indicates that the product request failed
}


class StoreManager : NSObject, SKRequestDelegate, SKProductsRequestDelegate {
    /// Provide the status of the product request
    var Status : IAPProductRequestStatus?
    
    /// Keep track of all valid products. These products are available for sale in the App Store
    var AvailableProducts : [SKProduct] = []
    
    /// Keep track of all invalid product identifiers
    var InvalidProductIds :  [String] = []
    
    /// Keep track of all valid products (these products are available for sale in the App Store) and of all invalid product identifiers
    var ProductRequestResponse : MyModel = MyModel()
    
    /// Indicates the cause of the product request failure
    var ErrorMessage : String? = nil

    static let Instance = StoreManager()
    
    private override init() {
        super.init()
    }

    // Request information
    private var ProductRequest : SKProductsRequest?
    
    /// Query the App Store about the given product identifiers
    /// Fetch information about your products from the App Store
    func FetchProductInformationForIds (productIds:Set<String>)
    {
        self.ProductRequestResponse = MyModel()
        // Create a product request object and initialize it with our product identifiers
        self.ProductRequest =  SKProductsRequest(productIdentifiers: productIds)
        self.ProductRequest.delegate = self;
        
        // Send the request to the App Store
        self.ProductRequest.start()
    }
    
    /// Used to get the App Store's response to your request and notifies your observer
    func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
        let model : MyModel = MyModel()
        
        // The products array contains products whose identifiers have been recognized by the App Store.
        // As such, they can be purchased. Create an "AVAILABLE PRODUCTS" model object.
        if ((response.products).count > 0)
        {
            model.AvailableProducts = response.products
            
            self.AvailableProducts = response.products
        }
        
        // The invalidProductIdentifiers array contains all product identifiers not recognized by the App Store.
        // Create an "INVALID PRODUCT IDS" model object.
        if ((response.invalidProductIdentifiers).count > 0)
        {
            model.InvalidProductIds = response.invalidProductIdentifiers
            
        }
        self.ProductRequestResponse = model
        self.Status = .ProductRequestResponse
        NSNotificationCenter.defaultCenter().postNotificationName(IAPProductRequestNotification, object: self)
    }

    /// SKRequestDelegate method
    /// Called when the product request failed.
    func request(request: SKRequest, didFailWithError error: NSError) {
        // Prints the cause of the product request failure
        print("Product Request Status:\(error.localizedDescription)")
    }
    
    /// Helper method
    
    /// Return the product's title matching a given product identifier
    func TitleMatchingProductIdentifier(identifier:String) -> String? {
        var productTitle : String?
        // Iterate through availableProducts to find the product whose productIdentifier
        // property matches identifier, return its localized title when found
        for product in self.AvailableProducts
        {
            if product.productIdentifier == identifier {
                productTitle = product.localizedTitle
                break
            }
        }
        return productTitle;
        
    }
    
    

}
