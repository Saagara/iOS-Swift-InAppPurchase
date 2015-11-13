//
//  MyModel.swift


import Foundation
import StoreKit


class MyModel {

    //  List of products/purchases
    var AvailableProducts : [SKProduct]
    var InvalidProductIds : [String]
    
    // Create a model object
    init() {
        self.AvailableProducts = []
        self.InvalidProductIds = []
    }

}
