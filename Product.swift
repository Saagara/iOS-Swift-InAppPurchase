//
//  Product.swift

import Foundation

class Product {
    
    // Products are organized by category
    var Category : String
    // Title of the product
    var Title : String
    // iTunes identifier of the product
    var ProductID : String
    // App Analytics campagin token
    var CampaignToken : String
    // App Analytics provider token
    var ProviderToken : String
    
    init(category:String, title:String, productID:String, campaignToken:String, providerToken:String) {
        
        self.Category = category
        self.Title = title
        self.ProductID = productID
        self.CampaignToken = campaignToken
        self.ProviderToken = providerToken
        
    }

}
