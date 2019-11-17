//
//  addAnncController.swift
//  St Augustine CHS
//
//  Created by Kenny Miu on 2018-10-28.
//  Copyright © 2018 St Augustine CHS. All rights reserved.
//

import UIKit
import Firebase

class addAnncController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    //Cloud Functions
    lazy var functions = Functions.functions()
    
    //The Database
    var db: Firestore!
    var docRef: DocumentReference!
    var clubID = String()
    
    //Announcement Vars
    @IBOutlet weak var titleTxtArea: UITextView!
    @IBOutlet weak var contentTxtArea: UITextView!
    @IBOutlet weak var anncImg: UIImageView!
    @IBOutlet weak var removeImage: UIButton!
    var currentAnncID = String()
    var clubName = String()
    
    //Returning to club vars
    var onDoneBlock : ((Bool) -> Void)?
    
    //See if you are in edit mode
    var editMode = false
    var editedPhoto = false
    var editTitle = String()
    var editDesc = String()
    var editImage = UIImage()
    var editImageName = String()
    @IBOutlet weak var createNewAnncInstruction: UILabel!
    @IBOutlet weak var postButton: UIButton!
    
    let actInd: UIActivityIndicatorView = UIActivityIndicatorView()
    let container: UIView = UIView()
    
    @IBOutlet weak var statusBarView: UIView!
    @IBOutlet weak var topBarView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Set Up 
        // [START setup]
        let settings = FirestoreSettings()
        //settings.areTimestampsInSnapshotsEnabled = true
        Firestore.firestore().settings = settings
        // [END setup]
        db = Firestore.firestore()
        
        //***************INTERNET CONNECTION**************
        var iAmConneted = false
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value, with: { snapshot in
            if let connected = snapshot.value as? Bool, connected {
                print("Connected")
                iAmConneted = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0){
                    print(iAmConneted)
                    if !iAmConneted{
                        print("Not connected")
                        let alert = UIAlertController(title: "Error", message: "You are not connected to the internet", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(okAction)
                        self.present(alert, animated: true, completion: nil)
                        self.postButton.isEnabled = false
                    }
                }
            }
        })
        
        //Hide keyboard when tapped out
        self.hideKeyboardWhenTappedAround()
        
        print(clubName)
        
        //Colours
        statusBarView.backgroundColor = Defaults.darkerPrimary
        topBarView.backgroundColor = Defaults.primaryColor
        createNewAnncInstruction.textColor = Defaults.primaryColor
        titleTxtArea.tintColor = Defaults.accentColor
        contentTxtArea.tintColor = Defaults.accentColor
        removeImage.setTitleColor(Defaults.primaryColor, for: .normal)
        
        //If in edit mode, set it to edit mode
        if editMode {
            print(currentAnncID)
            createNewAnncInstruction.text = "Update the Announcement"
            postButton.setTitle("Update", for: .normal)
            titleTxtArea.text = editTitle
            contentTxtArea.text = editDesc
            
            if editImageName != "" {
                anncImg.image = editImage
                removeImage.isHidden = false
            }
        }
    }
    
    //***************************ALLOWING THE USER TO UPLOAD AN IMAGE TO USE***************************
    @IBAction func chooseImage(_ sender: Any) {
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
        removeImage.isHidden = false
        anncImg.image = image
        
        if editMode {
            editedPhoto = true
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    //If the user cancesl picking image from library
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func removeImage(_ sender: Any) {
        anncImg.image = nil
        removeImage.isHidden = true
    }
    
    //***************************CANCEL THE ANNOUNCEMENT***************************
    @IBAction func pressedCancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //***************************POSTING THE ANNOUNCEMENT***************************
    @IBAction func pressedPost(_ sender: Any) {
        //***************INTERNET CONNECTION**************
        var iAmConneted = false
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value, with: { snapshot in
            if let connected = snapshot.value as? Bool, connected {
                print("Connected")
                iAmConneted = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0){
                    print(iAmConneted)
                    if !iAmConneted{
                        print("Not connected")
                        let alert = UIAlertController(title: "Error", message: "You are not connected to the internet", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        })
        
        if self.titleTxtArea.text == "" || self.titleTxtArea.text == "title" {
            //Tell the user that information needs to be filled in
            let alert = UIAlertController(title: "Error", message: "All announcements require a title", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            self.present(alert, animated: true, completion: nil)
        }
        
        else if (self.titleTxtArea.text?.count)! > 50 && (allUserFirebaseData.data["status"] as? Int ?? 0 != 2) {
            let alert = UIAlertController(title: "Error", message: "Title is too long", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            self.present(alert, animated: true, completion: nil)
        }
        
        else if (self.contentTxtArea.text?.count)! > 300 && (allUserFirebaseData.data["status"] as? Int ?? 0 != 2) {
            let alert = UIAlertController(title: "Error", message: "Content is too long", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            self.present(alert, animated: true, completion: nil)
        }
        
        else {
            getTimeFromServer { (serverDate) in
                self.theDate = serverDate
            }
            
            //Set up an activity indicator
            showActivityIndicatory(container: container, actInd: actInd)
            
            var imageName = ""
            //Check the img field
            if self.anncImg.image != nil {
                //Give the photo a random name
                if !self.editMode || (self.editImageName == "") {
                    imageName = self.randomString(length: 20)
                } else {
                    imageName = self.editImageName
                }
                
                //Set up the image data
                let storageRef = Storage.storage().reference(withPath: "announcements").child(imageName)
                let metaData = StorageMetadata()
                metaData.contentType = "image/jpeg"
                
                //Upload the image to the database
                if let uploadData = self.anncImg.image?.resized(toWidth: 500)!.jpegData(compressionQuality: 1.0){
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
                if editMode && self.editImageName != "" {
                    let storageRef = Storage.storage().reference(withPath: "announcements").child(editImageName)
                    storageRef.delete(completion: { err in
                        if let err = err {
                            print("Error deleteing anncImg \(err.localizedDescription)")
                        } else {
                            print("Annc Img successfully deleted")
                        }
                    })
                }
                
                self.uploadRestAfterImageIsDone(imageName: imageName)
                print("there is no image available")
            }
        }
    }
    
    var theDesc = ""
    var theTitle = ""
    func uploadRestAfterImageIsDone(imageName: String){
        let anncTitle = titleTxtArea.text!
        var anncDesc = ""
        
        //Check for content text field
        if contentTxtArea.text != "" {
            anncDesc = contentTxtArea.text!
        } else{
            print("There was no description")
        }
        //If the user is purely adding an announcement
        if !editMode {
            //Send the data to firebase
            // Add a new document in collection "announcements"
            currentAnncID = randomString(length: 20)
            let user = Auth.auth().currentUser
            print("Added annc id \(currentAnncID)")
            
            theDesc = anncDesc
            theTitle = anncTitle
            
            db.collection("announcements").document(currentAnncID).setData([
                "club": clubID,
                "clubName": clubName,
                "content": anncDesc,
                "creator": user?.uid as Any,
                "date": self.theDate as Any,
                "img": imageName,
                "title": anncTitle
            ]) { err in
                if let err = err {
                    let alert = UIAlertController(title: "Error in adding announcement", message: "Please Try Again later. Error: \(err.localizedDescription)", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    self.present(alert, animated: true, completion: nil)
                    self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                    
                    print("Error writing document: \(err)")
                } else {
                    print("Document successfully written!")
                    //Return to the club controller page
                    //add a delay to allow the image to upload add an indicator to show u r uploading. same for returning and refreshing or just getting anncs in general
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                        self.doneWithAnnc()
                    }
                }
            }
        } else {
            //Update data in the firebase
            let user = Auth.auth().currentUser
            let anncRef = db.collection("announcements").document(currentAnncID)
            anncRef.updateData([
                "content": anncDesc,
                "title": anncTitle,
                "img": imageName,
                "creator": user?.uid as Any
            ]) { (err) in
                if let err = err {
                    let alert = UIAlertController(title: "Error in updating announcement", message: "Please Try Again later. Error: \(err.localizedDescription)", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    self.present(alert, animated: true, completion: nil)
                    self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                    print("Error updating document: \(err)")
                } else {
                    print("Document successfully updated")
                    //Return to the club controller page
                    //add a delay to allow the image to upload add an indicator to show u r uploading. same for returning and refreshing or just getting anncs in general
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                        self.doneWithAnncUpdate()
                    }
                }
            }
        }
    }
    
    //******************************FUNCTIONAL FUNCTIONS******************************
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
    
    var theDate: Date! = Date()
    func getTimeFromServer(completionHandler:@escaping (_ getResDate: Date?) -> Void){
        let url = URL(string: "https://www.apple.com")
        let task = URLSession.shared.dataTask(with: url!) {(data, response, error) in
            let httpResponse = response as? HTTPURLResponse
            if let contentType = httpResponse!.allHeaderFields["Date"] as? String {
                //print(httpResponse)
                let dFormatter = DateFormatter()
                dFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
                let serverTime = dFormatter.date(from: contentType)
                completionHandler(serverTime)
            }
        }
        task.resume()
    }
    
    func doneWithAnnc() {
        functions.httpsCallable("sendToTopic").call(["body": theDesc, "title": theTitle, "clubID": clubID, "clubName": clubName]) { (result, error) in
            if let error = error as NSError? {
                if error.domain == FunctionsErrorDomain {
                    let code = FunctionsErrorCode(rawValue: error.code)
                    let message = error.localizedDescription
                    let details = error.userInfo[FunctionsErrorDetailsKey]
                    print(code as Any)
                    print(message)
                    print(details as Any)
                }
            }
            print("Email sent to admins")
            print("Result is: \(String(describing: result?.data))")
        }
        
        //print("yes i get run thanks")
        if let presenter = presentingViewController as? clubFinalController {
            presenter.anncRef.append(currentAnncID) //this line should be roughly useless as i refresh the entire page when returning
        }
        onDoneBlock!(true)
        hideActivityIndicator(container: container, actInd: actInd)
        dismiss(animated: true, completion: nil)
    }
    
    func doneWithAnncUpdate() {
        onDoneBlock!(true)
        hideActivityIndicator(container: container, actInd: actInd)
        dismiss(animated: true, completion: nil)
    }
    
}


