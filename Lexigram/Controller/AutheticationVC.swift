//
//  ViewController.swift
//  Lexigram
//
//  Created by James Kang on 10/2/17.
//  Copyright © 2017 James Kang. All rights reserved.
//

import UIKit
import FBSDKLoginKit
import FBSDKCoreKit
import Firebase
import SwiftKeychainWrapper
import SwiftyJSON


class AuthenticationVC: UIViewController {
    
    //stores the url for my firebase database
    private let dataURL = "https://lexicord-fcfeb.firebaseio.com/"
    
    //propertis needed for graph request
    var user = User()
    var ref: DatabaseReference!            // firebase database ref
    var storageRef: StorageReference!      // firebase storage ref
    var userProfilePicURL: String!         // Url string for users pic
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        if Auth.auth().currentUser != nil {
            performSegue(withIdentifier: "loginToMain", sender: nil)
        } else {
            print("No user validated")
        }
    }
    
    @IBAction func facebookTapped(_ sender: Any) {
        
        let facebookLogin = FBSDKLoginManager()
        print("Logging In")
        
        facebookLogin.logIn(withReadPermissions: ["email", "public_profile"], from: self, handler:{(facebookResult, facebookError) -> Void in
            
            if facebookError != nil {
                print("Facebook login failed. Error \(facebookError)")
            } else if (facebookResult?.isCancelled)! {
                print("Facebook login was cancelled.")
            } else {
                //Now we are in
                let credential = FacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                
                Auth.auth().signIn(with: credential) { (user, error) in
                    if error != nil {
                        print(error!.localizedDescription)
                        return
                    } else {
                        print("Current user logged in with Facebook")
                        self.performSegue(withIdentifier: "loginToMain", sender: nil) // testing
                        // call fbGraphSDK
                        self.facebookGraphSDKCall()
                    }
                }
            }
        });
    }
    
    // calling graphrequestdata
    func facebookGraphSDKCall() {
        
        FBSDKGraphRequest(graphPath: "/me", parameters: ["fields": "id, first_name, last_name, email, picture.width(400).height(400)"]).start { (connection, result, err) in
            if err != nil {
                print("Failed to start graph request:", err ?? "")
            }
            print(result ?? "")
            
            if let user = Auth.auth().currentUser {
                
                self.ref = Database.database().reference()                                                         // Firebase Database Reference
                let imageName = NSUUID().uuidString                                                                // Giving an uploaded image a unique name
                self.storageRef = Storage.storage().reference().child("profile_images").child("\(imageName).jpg")  // Firebase Storage Reference
                let uid = user.uid                                                                                 // Firebase user by UID
                let data: [String:Any] = result as! [String:Any]                                                   // Dictionary for data involved in values sent to FirBse
                let json = JSON(result)                                                                            // URL picture stuff in this constant
                
                
                // turning the graphrequest data into firebase data
                let userFirstName: NSString? = data["first_name"] as? NSString
                self.user.first_name = userFirstName as String?
                let userLastName: NSString? = data["last_name"] as? NSString
                self.user.last_name = userFirstName as String?
                let userEmail: NSString? = data["email"] as? NSString
                self.user.email = userEmail as String?
                let userID: NSString? = data["id"] as? NSString
                self.user.id = userID as String?
                
                // Grabbing the string value from the url
                let urlPic = (json["picture"]["data"]["url"].stringValue) as String
                print(urlPic)
                
                if let imageData = NSData(contentsOf: URL(string: urlPic)!) as Data? {
                    _ = self.storageRef.putData(imageData, metadata: nil) {
                        (metadata, error) in
                        if (error == nil) {
                            print("Saved profile image to storage")
                            _ = metadata!.downloadURL // may need to change...
                        } else {
                            print("Error in downloading the image")
                        }
                        self.userProfilePicURL = "\(metadata!.downloadURL()!)"
                        let values = ["first_name": userFirstName,"last_name": userLastName, "email": userEmail, "id": userID, "profilePicURL": self.userProfilePicURL] as [String : Any]
                        
                        self.sendUserToFirebase(uid: uid, values: values)
                    }
                }
            }
        }
    }
    
    // send user graphrequest information to firebase "user" node
    func sendUserToFirebase(uid: String, values:[String: Any]) {
        let usersReference = ref.child("users").child(uid)
        usersReference.updateChildValues(values) { (err, ref) in
            if err != nil {
                print("The error is: \(err.debugDescription)")
                return
            }
            print("user sent to firebase")
        }
    }
    
    
    
}

