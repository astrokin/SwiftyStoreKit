//
//  ViewController.swift
//  SwiftStoreOSXDemo
//
//  Created by phimage on 22/12/15.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Cocoa
import StoreKit
import SwiftyStoreKit

enum RegisteredPurchase : String {
    
    case Purchase1 = "purchase1"
    case Purchase2 = "purchase2"
    case NonConsumablePurchase = "nonConsumablePurchase"
    case ConsumablePurchase = "consumablePurchase"
    case AutoRenewablePurchase = "autoRenewablePurchase"
    case NonRenewingPurchase = "nonRenewingPurchase"
    
}

class ViewController: NSViewController {

    let AppBundleId = "com.musevisions.OSX.SwiftyStoreKit"
    
    let Purchase1 = RegisteredPurchase.Purchase1
    let Purchase2 = RegisteredPurchase.AutoRenewablePurchase

    // MARK: actions
    @IBAction func getInfo1(sender: AnyObject?) {
        getInfo(Purchase1)
    }
    @IBAction func purchase1(sender: AnyObject?) {
        purchase(Purchase1)
    }
    @IBAction func verifyPurchase1(sender: AnyObject?) {
        verifyPurchase(Purchase1)
    }

    @IBAction func getInfo2(sender: AnyObject?) {
        getInfo(Purchase2)
    }
    @IBAction func purchase2(sender: AnyObject?) {
        purchase(Purchase2)
    }
    @IBAction func verifyPurchase2(sender: AnyObject?) {
        verifyPurchase(Purchase2)
    }

    func getInfo(purchase: RegisteredPurchase) {

        SwiftyStoreKit.sharedInstance.retrieveProductsInfo([AppBundleId + "." + purchase.rawValue]) { result in

            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }

    func purchase(purchase: RegisteredPurchase) {

        SwiftyStoreKit.sharedInstance.purchaseProduct(AppBundleId + "." + purchase.rawValue) { result in

            self.showAlert(self.alertForPurchaseResult(result))
        }
    }

    @IBAction func restorePurchases(sender: AnyObject?) {

        SwiftyStoreKit.sharedInstance.restorePurchases() { results in
            
            self.showAlert(self.alertForRestorePurchases(results))
        }
    }

    @IBAction func verifyReceipt(sender: AnyObject?) {

        SwiftyStoreKit.sharedInstance.verifyReceipt() { result in

            self.showAlert(self.alertForVerifyReceipt(result)) { response in

                SwiftyStoreKit.sharedInstance.refreshReceipt()
            }
        }
    }

    func verifyPurchase(purchase: RegisteredPurchase) {
        
        SwiftyStoreKit.sharedInstance.verifyReceipt() { result in
            
            switch result {
            case .Success(let receipt):
                
                let productId = self.AppBundleId + "." + purchase.rawValue
                
                // Specific behaviour for AutoRenewablePurchase
                if purchase == .AutoRenewablePurchase {
                    let purchaseResult = SwiftyStoreKit.sharedInstance.verifySubscription(
                        productId: productId,
                        inReceipt: receipt,
                        validUntil: NSDate()
                    )
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                }
                else {
                    let purchaseResult = SwiftyStoreKit.sharedInstance.verifyPurchase(
                        productId: productId,
                        inReceipt: receipt
                    )
                    self.showAlert(self.alertForVerifyPurchase(purchaseResult))
                }
                            
            case .Error(_):
                self.showAlert(self.alertForVerifyReceipt(result))
            }
        }
    }
    


}

// MARK: User facing alerts
extension ViewController {
    
    func alertWithTitle(title: String, message: String) -> NSAlert {
        
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = NSAlertStyle.Informational
        return alert
    }
    func showAlert(alert: NSAlert, handler: ((NSModalResponse) -> Void)? = nil) {
        
        if let window = NSApplication.sharedApplication().keyWindow {
            alert.beginSheetModalForWindow(window)  { (response: NSModalResponse) in
                handler?(response)
            }
        } else {
            let response = alert.runModal()
            handler?(response)
        }
    }

    func alertForProductRetrievalInfo(result: SwiftyStoreKit.sharedInstance.RetrieveResults) -> NSAlert {
        
        if let product = result.retrievedProducts.first {
            let numberFormatter = NSNumberFormatter()
            numberFormatter.locale = product.priceLocale
            numberFormatter.numberStyle = .CurrencyStyle
            let priceString = numberFormatter.stringFromNumber(product.price ?? 0) ?? ""
            return alertWithTitle(product.localizedTitle ?? "no title", message: "\(product.localizedDescription) - \(priceString)")
        }
        else if let invalidProductId = result.invalidProductIDs.first {
            return alertWithTitle("Could not retrieve product info", message: "Invalid product identifier: \(invalidProductId)")
        }
        else {
            let errorString = result.error?.localizedDescription ?? "Unknown error. Please contact support"
            return alertWithTitle("Could not retrieve product info", message: errorString)
        }
    }
    
    func alertForPurchaseResult(result: SwiftyStoreKit.sharedInstance.PurchaseResult) -> NSAlert {

        switch result {
        case .Success(let productId):
            print("Purchase Success: \(productId)")
            return alertWithTitle("Thank You", message: "Purchase completed")
        case .Error(let error):
            print("Purchase Failed: \(error)")
            switch error {
            case .Failed(let error):
                if error.domain == SKErrorDomain {
                    return alertWithTitle("Purchase failed", message: "Please check your Internet connection or try again later")
                }
                return alertWithTitle("Purchase failed", message: "Unknown error. Please contact support")
            case .InvalidProductId(let productId):
                return alertWithTitle("Purchase failed", message: "\(productId) is not a valid product identifier")
            case .NoProductIdentifier:
                return alertWithTitle("Purchase failed", message: "Product not found")
            case .PaymentNotAllowed:
                return alertWithTitle("Payments not enabled", message: "You are not allowed to make payments")
            }
        }
    }
    
    func alertForRestorePurchases(results: SwiftyStoreKit.sharedInstance.RestoreResults) -> NSAlert {
        
        if results.restoreFailedProducts.count > 0 {
            print("Restore Failed: \(results.restoreFailedProducts)")
            return alertWithTitle("Restore failed", message: "Unknown error. Please contact support")
        }
        else if results.restoredProductIds.count > 0 {
            print("Restore Success: \(results.restoredProductIds)")
            return alertWithTitle("Purchases Restored", message: "All purchases have been restored")
        }
        else {
            print("Nothing to Restore")
            return alertWithTitle("Nothing to restore", message: "No previous purchases were found")
        }
    }
    
    func alertForVerifyReceipt(result: SwiftyStoreKit.sharedInstance.VerifyReceiptResult) -> NSAlert {

        switch result {
        case .Success(let receipt):
            print("Verify receipt Success: \(receipt)")
            return self.alertWithTitle("Receipt verified", message: "Receipt verified remotly")
        case .Error(let error):
            print("Verify receipt Failed: \(error)")
            return self.alertWithTitle("Receipt verification failed", message: "The application will exit to create receipt data. You must have signed the application with your developer id to test and be outside of XCode")
        }
    }
    
    func alertForVerifySubscription(result: SwiftyStoreKit.sharedInstance.VerifySubscriptionResult) -> NSAlert {
        
        switch result {
        case .Purchased(let expiresDate):
            print("Product is valid until \(expiresDate)")
            return alertWithTitle("Product is purchased", message: "Product is valid until \(expiresDate)")
        case .Expired(let expiresDate):
            print("Product is expired since \(expiresDate)")
            return alertWithTitle("Product expired", message: "Product is expired since \(expiresDate)")
        case .NotPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }


    func alertForVerifyPurchase(result: SwiftyStoreKit.sharedInstance.VerifyPurchaseResult) -> NSAlert {
        
        switch result {
        case .Purchased:
            print("Product is purchased")
            return alertWithTitle("Product is purchased", message: "Product will not expire")
        case .NotPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }
}

