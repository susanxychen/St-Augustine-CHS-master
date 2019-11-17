//
//  createBadgeController.swift
//  St Augustine CHS
//
//  Created by Kenny Miu on 2019-01-02.
//  Copyright © 2019 St Augustine CHS. All rights reserved.
//

import UIKit
import Firebase
import CropViewController

class createBadgeController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CropViewControllerDelegate {

    var clubID: String!
    var clubMembers = [String]()
    var clubEmails = [String]()
    
    //The Database
    var db: Firestore!
    var docRef: DocumentReference!
    
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var descriptionTxtFld: UITextField!
    
    var onDoneBlock : ((Bool) -> Void)?
    
    var isUpdatingBadge = false
    var oldBadgeID: String!
    var oldBadgeImg: UIImage!
    var oldBadgeImgId: String!
    var oldBadgeDesc: String!
    var didUpdateBadgeImage = false
    
    var isClubBadge = false
    
    let actInd: UIActivityIndicatorView = UIActivityIndicatorView()
    let container: UIView = UIView()
    
    //Colours
    @IBOutlet weak var statusBarView: UIView!
    @IBOutlet weak var topBarView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Intialize the club Emails
        for _ in clubMembers {
            clubEmails.append("")
        }
        
        if isUpdatingBadge {
            badgeImageView.image = oldBadgeImg
            descriptionTxtFld.text = oldBadgeDesc
        }
        
        //Set Up
        // [START setup]
        let settings = FirestoreSettings()
        //settings.areTimestampsInSnapshotsEnabled = true
        Firestore.firestore().settings = settings
        // [END setup]
        db = Firestore.firestore()
        
        print(clubID as Any)
        
        hideKeyboardWhenTappedAround()
        
        descriptionTxtFld.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        
        //Round the image
        badgeImageView.layer.cornerRadius = badgeImageView.frame.width / 2
        badgeImageView.clipsToBounds = true
        
        statusBarView.backgroundColor = Defaults.darkerPrimary
        topBarView.backgroundColor = Defaults.primaryColor
        descriptionTxtFld.tintColor = Defaults.accentColor
    }
    
    @IBAction func chooseImagePressed(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        
        let actionSheet = UIAlertController(title: "Photo Source", message: "Choose a source", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { (action:UIAlertAction) in
            //Check to see if the app has access to camera or if there is one available
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                imagePicker.sourceType = .camera
                self.present(imagePicker, animated: true, completion: nil)
            } else {
                print("no camera access")
                //Tell the user there is no camera available
                let alert = UIAlertController(title: "Cannot access Camera", message: "Either the app does not have access to the camera or the device does not have a camera", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { (action:UIAlertAction) in
            //Check to see if the app has access to camera or if there is one available
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                imagePicker.sourceType = .photoLibrary
                self.present(imagePicker, animated: true, completion: nil)
            } else {
                print("no photo access")
                //Tell the user there is no camera available
                let alert = UIAlertController(title: "Cannot access Photos", message: "The app does not have access to the photo library", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    //Picking the image from photo libarry.....Info dictionary contains the image data
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        
        let cropVC = CropViewController(croppingStyle: .circular, image: image)
        cropVC.delegate = self
        
        picker.dismiss(animated: true, completion: nil)
        present(cropVC, animated: true, completion: nil)
    }
    
    //If the user cancesl picking image from library
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        print("i get here crop")
        cropViewController.dismiss(animated: true, completion: nil)
        print(image)
        badgeImageView.image = image
        didUpdateBadgeImage = true
    }
    
    @IBAction func cancelButtonPushed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func createPressed(_ sender: Any) {
        if badgeImageView.image == UIImage(named: "blankUser") {
            print("Choose an image")
            let ac = UIAlertController(title: "Error", message: "Badges Require Images", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
        
        else if descriptionTxtFld.text == "" {
            print("no text")
            let ac = UIAlertController(title: "Error", message: "Badges Require a Description", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
        //add a max of 100 characters
        else {
            //Set up an activity indicator
            showActivityIndicatory(container: container, actInd: actInd)
            
            var imageName = ""
            
            //This check is just to quickly prevent needing to upload to storage if image has not changed
            if didUpdateBadgeImage {
                //Give the photo a random name
                if isUpdatingBadge {
                    imageName = oldBadgeImgId
                } else {
                    imageName = self.randomString(length: 20)
                }
                
                //Set up the image data
                let storageRef = Storage.storage().reference(withPath: "badges").child(imageName)
                let metaData = StorageMetadata()
                metaData.contentType = "image/jpeg"
                
                //Upload the image to the database
                if let uploadData = badgeImageView.image?.jpegData(compressionQuality: 1.0){
                    storageRef.putData(uploadData, metadata: metaData) { (metadata, error) in
                        if let error = error {
                            let alert = UIAlertController(title: "Error in uploading image to database", message: "Please Try Again later. Error: \(error.localizedDescription)", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alert.addAction(okAction)
                            self.present(alert, animated: true, completion: nil)
                            print(error as Any)
                            self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                            
                            return
                        }
                        print(metadata as Any)
                        self.uploadRestAfterImageIsDone(imageName: imageName)
                    }
                }
            } else {
                //If the image wasnt touched, just go straight to updating description
                self.uploadRestAfterImageIsDone(imageName: imageName)
            }
        }
    }
    
    func uploadRestAfterImageIsDone(imageName: String){
        let desc = descriptionTxtFld.text!
        
        let badgeID = randomString(length: 20)
        let user = Auth.auth().currentUser
        print("Added badge id \(badgeID)")
        
        //If you are adding a club badge (as there are no regular ones)
        if !isUpdatingBadge {
            db.collection("clubs").document(clubID).updateData(["clubBadge" : badgeID])
            db.collection("badges").document(badgeID).setData([
                "club": clubID as Any,
                "desc": desc,
                "creator": user?.uid as Any,
                "img": imageName,
                "giveaway": false
            ]) { err in
                if let err = err {
                    let alert = UIAlertController(title: "Error in adding badge", message: "Please Try Again later. Error: \(err.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                } else {
                    print("Document successfully written!")
                    self.giveClubBadgeToMembers(id: badgeID)
                }
            }
        } else {
            let user = Auth.auth().currentUser
            
            if imageName == "" {
                db.collection("badges").document(oldBadgeID).updateData([
                    "desc": desc,
                    "creator": user?.uid as Any
                ]) { (err) in
                    if let err = err {
                        let alert = UIAlertController(title: "Error in editing badge", message: "Please Try Again later. Error: \(err.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                    } else {
                        print("Document successfully written!")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                            self.onDoneBlock!(true)
                            self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            } else {
                db.collection("badges").document(oldBadgeID).updateData([
                    "desc": desc,
                    "creator": user?.uid as Any,
                    "img": imageName
                ]) { (err) in
                    if let err = err {
                        let alert = UIAlertController(title: "Error in editing badge", message: "Please Try Again later. Error: \(err.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                    } else {
                        print("Document successfully written!")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                            self.onDoneBlock!(true)
                            self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }
    
    func giveClubBadgeToMembers(id: String){
        for user in clubMembers {
            //Give the badge to each member
            let userRef = self.db.collection("users").document(user)
            userRef.updateData([
                "badges": FieldValue.arrayUnion([id])
            ])
            
            //Give user points
            self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                let uDoc: DocumentSnapshot
                do {
                    try uDoc = transaction.getDocument(userRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                guard let oldPoints = uDoc.data()?["points"] as? Int else {
                    let error = NSError(
                        domain: "AppErrorDomain",
                        code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Unable to retrieve points from snapshot \(uDoc)"
                        ]
                    )
                    errorPointer?.pointee = error
                    return nil
                }
                transaction.updateData(["points": oldPoints + Defaults.joiningClub], forDocument: userRef)
                return nil
            }, completion: { (object, err) in
                if let error = err {
                    print("Transaction failed: \(error)")
                } else {
                    print("Transaction successfully committed!")
                    print("successfuly gave badge")
                }
            })
            
            //Get all the grades
            db.collection("users").document(user).collection("info").document("vital").getDocument { (snap, err) in
                if let err = err {
                    print("error \(err)")
                }
                if let snap = snap {
                    let data = snap.data() ?? ["name":"error", "email":"error", "profilePic": 0, "msgToken":"error"]
                    let email = data["email"] as? String ?? "error"
                    
                    let gradYear = Int(email.suffix(14).prefix(2)) ?? 0
                    let pointRef = self.db.collection("info").document("spiritPoints")
                    self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                        let pDoc: DocumentSnapshot
                        do {
                            try pDoc = transaction.getDocument(pointRef)
                        } catch let fetchError as NSError {
                            errorPointer?.pointee = fetchError
                            return nil
                        }
                        guard let oldPoints = pDoc.data()?[String(gradYear)] as? Int else {
                            let error = NSError(
                                domain: "AppErrorDomain",
                                code: -1,
                                userInfo: [
                                    NSLocalizedDescriptionKey: "Unable to retrieve points from snapshot \(pDoc)"
                                ]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }
                        transaction.updateData([String(gradYear): oldPoints + Defaults.joiningClub], forDocument: pointRef)
                        return nil
                    }, completion: { (object, err) in
                        if let error = err {
                            print("Transaction failed: \(error)")
                        } else {
                            print("Transaction successfully committed!")
                        }
                    })
                }
            }
            
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0){
            self.hideActivityIndicator(container: self.container, actInd: self.actInd)
            self.onDoneBlock!(true)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func randomString(length: Int) -> String {
        //announcements are 20 long
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let len = UInt32(letters.length)
        
        var randomString = ""
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        return randomString
    }
    
}
