//
//  ViewController.swift
//  St Augustine CHS
//
//  Created by Kenny Miu on 2018-10-14.
//  Copyright © 2018 St Augustine CHS. All rights reserved.
//

import UIKit
import Foundation
import Firebase
import WebKit
import GoogleSignIn
import SafariServices
import UserNotifications

//This is the struct that holds all of the users firebase data
struct allUserFirebaseData {
    static var data:[String:Any] = [:]
    static var profilePic:UIImage = UIImage(named: "blankUser")!
    static var didUpdateProfilePicture = false
}

class menuController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, GIDSignInDelegate, GIDSignInUIDelegate {
    
    //Sign In Variables
    var allowAnyGoogleAccount = false
    @IBOutlet weak var failedSignInButton: UIButton!
    @IBOutlet weak var newUserButton: UIButton!
    
    //All Basic Menu Variables
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var menuView: UIView!
    @IBOutlet var homeView: UIView!
    @IBOutlet weak var tapOutOfMenuButton: UIButton!
    @IBOutlet weak var dateToString: UILabel!
    @IBOutlet weak var dayNumber: UILabel!
    @IBOutlet weak var dayNumberHeight: NSLayoutConstraint!
    @IBOutlet weak var snowDayLabel: UILabel!
    @IBOutlet weak var snowDayLabelHeight: NSLayoutConstraint!
    
    //Scroll Height
    @IBOutlet weak var homeScrollViewHeight: NSLayoutConstraint!
    
    //Profile UI Variables
    @IBOutlet weak var profilePicture: UIImageView!
    @IBOutlet weak var displayName: UILabel!
    @IBOutlet weak var displayEmail: UILabel!
    var menuShowing = false
    
    //Online Data Variables
    //let dayURL = URL(string: "https://staugustinechs.netfirms.com/stadayonetwo/")
    let newsURL = URL(string: "http://staugustinechs.ca/printable/")
    
    //Annoucment Variables
    var newsData = [[String]]()
    @IBOutlet weak var annoucView: UICollectionView!
    @IBOutlet weak var anncViewHeight: NSLayoutConstraint!
    
    //Club Annc
    @IBOutlet weak var clubAnncView: UICollectionView!
    @IBOutlet weak var clubAnncHeight: NSLayoutConstraint!
    var clubNewsData = [[String:Any]]()
    
    //Refresh Variables
    var refreshControl: UIRefreshControl?
    @IBOutlet weak var homeScrollView: UIScrollView!
    let actInd: UIActivityIndicatorView = UIActivityIndicatorView()
    let container: UIView = UIView()
    
    //Database Variables
    var db: Firestore!
    var docRef: DocumentReference!
    
    //Filler Vars
    var fillerImage = UIImage(named: "blankUser")
    
    let viewAboveAllViews = UIView()
    
    //Calendar Vars
    @IBOutlet weak var calendarButton: UIButton!
    
    //Titan Tag Brightness
    var brightnessBeforeTT:CGFloat = 0
    
    //Colors
    @IBOutlet weak var clubAnnouncementsLabel: UILabel!
    @IBOutlet weak var dateAndDayView: UIView!
    @IBOutlet weak var gradientSocialView: UIView!
    
    var cameFromTT = false
    //***********************************SETTING UP EVERYTHING****************************************
    override func viewDidLoad() {
        super.viewDidLoad()
        brightnessBeforeTT = UIScreen.main.brightness
        calendarButton.isHidden = true
        viewAboveAllViews.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.7)
        viewAboveAllViews.frame = UIApplication.shared.keyWindow!.frame
        UIApplication.shared.keyWindow!.addSubview(viewAboveAllViews)
        definesPresentationContext = true
        
        dateToString.text = DateFormatter.localizedString(from: Date(), dateStyle: DateFormatter.Style.full, timeStyle: DateFormatter.Style.none)
        
        DispatchQueue.main.async {
            self.setupRemoteConfigDefaults()
            self.updateViewWithRCValues()
            self.fetchRemoteConfig()
        }
        
        //Only sign in if you have not come from there
        GIDSignIn.sharedInstance()?.delegate = self
        GIDSignIn.sharedInstance()?.uiDelegate = self
        GIDSignIn.sharedInstance()?.signIn()
    }
    
    //**********************************SIGN IN TO GOOGLE AND FIREBASE*************************************
    func sign(inWillDispatch signIn: GIDSignIn!, error: Error!) {
        guard error == nil else {
            viewAboveAllViews.removeFromSuperview()
            self.performSegue(withIdentifier: "failedLogin", sender: self.failedSignInButton)
            return
        }
        print("Successful Redirection")
        viewAboveAllViews.removeFromSuperview()
    }
    
    //MARK: GIDSignIn Delegate
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!){
        UIApplication.shared.keyWindow!.addSubview(viewAboveAllViews)
        if (error == nil) {
            //Successfuly Signed In to Google
            print("Sucessfully sign in to google")
        } else {
            print(error.localizedDescription)
            viewAboveAllViews.removeFromSuperview()
            self.performSegue(withIdentifier: "failedLogin", sender: self.failedSignInButton)
            return
        }
        let checkEmail = user.profile.email
        
        if ((checkEmail?.hasSuffix("ycdsbk12.ca"))! || (checkEmail == "sachstesterforapple@gmail.com") || allowAnyGoogleAccount){
            //print("wow nice sign in")
            //************************Firebase Auth************************
            guard let authentication = user.authentication else {
                self.viewAboveAllViews.removeFromSuperview()
                self.performSegue(withIdentifier: "failedLogin", sender: self.failedSignInButton)
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: authentication.idToken, accessToken: authentication.accessToken)
            
            Auth.auth().signInAndRetrieveData(with: credential) { (authResult, error) in
                self.viewAboveAllViews.removeFromSuperview()
                if let error = error {
                    print(error)
                    self.performSegue(withIdentifier: "failedLogin", sender: self.failedSignInButton)
                    return
                }
                
                //If Valid k12 account auto segue to main screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.getAllStartingInfoAfterSignIn()
                }
            }
        } else{
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.viewAboveAllViews.removeFromSuperview()
                self.performSegue(withIdentifier: "failedLogin", sender: self.failedSignInButton)
            }
        }
    }
    
    // Finished disconnecting |user| from the app successfully if |error| is |nil|.
    public func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!){
    }
    
    //************************************************************************************************
    func getAllStartingInfoAfterSignIn(){
        getTimeFromServer { (serverDate) in
            self.theDate = serverDate
        }

        //Set Up
        // [START setup]
        let settings = FirestoreSettings()
        ////settings.areTimestampsInSnapshotsEnabled = true
        Firestore.firestore().settings = settings
        // [END setup]
        db = Firestore.firestore()
        
        //Add refresh control
        addRefreshControl()
        
        showActivityIndicatory(container: container, actInd: actInd)
        
        //In app messaging
        InstanceID.instanceID().getID { (result, error) in
            if let error = error {
                print("Error fetching remote instange ID: \(error)")
            } else if let result = result {
                print("Remote instance ID: \(result)")
            }
        }
        
        //actual msg token
        InstanceID.instanceID().instanceID { (result, error) in
            if let error = error {
                print("Error fetching remote instance ID: \(error)")
            } else if let result = result {
                print("Remote instance ID token: \(result.token)")
                
            }
        }
        
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.font: UIFont(name: "Scada-Regular", size: 20)!]
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        //Following will push a notification when out of the app 5 seconds later
        //Purely for testing
//        let content = UNMutableNotificationContent()
//        content.title = "title"
//        content.body = "body"
//        content.sound = UNNotificationSound.default
//
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
//
//        let request = UNNotificationRequest(identifier: "testIdentifier", content: content, trigger: trigger)
//
//        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        
        //News Data
        newsTask()
        
        homeScrollView.alwaysBounceVertical = true
        
        //Brings the menu to the front on top of everything and make sure it is out of view
        homeView.bringSubviewToFront(menuView)
        homeView.bringSubviewToFront(tapOutOfMenuButton)
        
        leadingConstraint.constant = -400
        
        //Change profile picture corners to round
        //profilePicture.layer.borderWidth = 1.0
        //profilePicture.layer.masksToBounds = false
        //profilePicture.layer.borderColor = UIColor.white.cgColor
        profilePicture.layer.cornerRadius = 75/2
        profilePicture.clipsToBounds = true
        
        //Drop Shadow
        menuView.layer.shadowOpacity = 1
        menuView.layer.shadowRadius = 5
        
        //The Date
        dateToString.text = DateFormatter.localizedString(from: theDate, dateStyle: DateFormatter.Style.full, timeStyle: DateFormatter.Style.none)
        
        //Remainin Tasks
        getDayNumber()
        
        //*******************SET UP USER PROFILE ON MENU*****************
        let user = Auth.auth().currentUser
        //Name
        displayName.text = user?.displayName
        //Email
        displayEmail.text = String(user?.email?.split(separator: "@")[0] ?? "Error")
        
        //Set crash details for firebase
        Crashlytics.sharedInstance().setUserIdentifier(user?.uid)
        Crashlytics.sharedInstance().setUserName(user?.displayName)
        Crashlytics.sharedInstance().setUserEmail(user?.email)
        
        //Attempt to get user info
        db.collection("users").document((user?.uid)!).getDocument { (docSnapshot, err) in
            print("do i even reach in here to get the data")
            if let docSnapshot = docSnapshot {
               //Check if the user even exists
                if let data = docSnapshot.data() {
                    print("i get the data")
                    allUserFirebaseData.data = data
                    self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                    self.getPicture(i: data["profilePic"] as? Int ?? 0)
                    self.getClubAnncs()
                    self.updateDatabaseWithNewRemoteID()
                } else {
                    //If the user is new, then take em through the new sign in flow
                    print("its a new user")
                    self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                    self.performSegue(withIdentifier: "signInFlow", sender: self.newUserButton)
                }
            } else {
                print("wow u dont exist")
                self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                let alert = UIAlertController(title: "Error", message: "You could not be located in the database. Try again later or contact the app dev team.", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .cancel, handler: { (action) in
                    self.performSegue(withIdentifier: "failedLogin", sender: self.failedSignInButton)
                })
                alert.addAction(okAction)
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    //Every time the home screen apperars
    override func viewDidAppear(_ animated: Bool) {
        //See if you have entered the titan tag screen, if so then auto adjust brightness
        if let x = UserDefaults.standard.object(forKey: "didEnterTT") as? Bool {
            if x {
                UIScreen.animateBrightness(to: brightnessBeforeTT)
                UserDefaults.standard.set(false, forKey: "didEnterTT")
            } else {
                brightnessBeforeTT = UIScreen.main.brightness
            }
        } else {
            brightnessBeforeTT = UIScreen.main.brightness
        }
        
        //Also update the image to the latest one the user has chosen
        profilePicture.image = allUserFirebaseData.profilePic
    }
    
    func setupRemoteConfigDefaults() {
        let defaultValues = [
            "showLogoInTT": "1" as NSObject,
            "addK12ToTT": "1" as NSObject,
            "showUsersOnSongs": "1" as NSObject,
            "IOS_VERSION": "" as NSObject,
            "songRequestTheme": "" as NSObject,
            "AllowAccounts": 0 as NSObject,
            "AppOnline": 1 as NSObject,
            "primaryColor": UIColor(hex: "#8D1230") as NSObject,
            "darkerPrimary": UIColor(hex: "#460817") as NSObject,
            "accentColor": UIColor(hex: "#D8AF1C") as NSObject,
            "joiningClub": 300 as NSObject,
            "attendingEvent": 100 as NSObject,
            "startingPoints": 100 as NSObject,
            "basicPic": 30 as NSObject,
            "commonPic": 50 as NSObject,
            "rarePic": 100 as NSObject,
            "coolPic": 200 as NSObject,
            "legendaryPic": 500 as NSObject,
            "requestSong": 20 as NSObject,
            "supervoteMin": 10 as NSObject,
            "supervoteRatio": 1.0 as NSObject,
            "maxSongs": 20 as NSObject
        ]
        RemoteConfig.remoteConfig().setDefaults(defaultValues)
    }
    
    func fetchRemoteConfig(){
        RemoteConfig.remoteConfig().fetch(withExpirationDuration: 360) { [unowned self] (status, error) in
            guard error == nil else {
                print("cant get values + \(String(describing: error?.localizedDescription))")
                return
            }
            print("yay i got rc")
            RemoteConfig.remoteConfig().activateFetched()
            self.updateViewWithRCValues()
        }
    }
    
    func updateViewWithRCValues() {
        //Emergency shutdown
        let online = RemoteConfig.remoteConfig().configValue(forKey: "AppOnline").stringValue ?? "1"
        if online == "0" {
            //Disable
            self.view.isHidden = true
            
            let ac = UIAlertController(title: "The app is currently offline", message: "Sorry. Try another time.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(ac, animated: true)
        }
        
        let allowAny = RemoteConfig.remoteConfig().configValue(forKey: "AppOnline").stringValue ?? "0"
        if allowAny == "1" {
            allowAnyGoogleAccount = true
        } else {
            allowAnyGoogleAccount = false
        }
        
        //Check for a new update version
        let latestVersion = RemoteConfig.remoteConfig().configValue(forKey: "IOS_VERSION").stringValue ?? ""
        
        
        //************MANUALLY UPDATE THIS AFTER EVERY UPDATE************
        let versionHERE = "1.0.32"
        
        //Remind user
        print(latestVersion + " " + versionHERE)
        
        if latestVersion != versionHERE && latestVersion != "" && (Auth.auth().currentUser?.email) ?? "error" != "sachstesterforapple@gmail.com" {
            let ac = UIAlertController(title: "New iOS update available!", message: "The list of bug fixes and changes are on the app store. Please update!", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(ac, animated: true)
        }
        
        //apply the remote config values here
        let primary = RemoteConfig.remoteConfig().configValue(forKey: "primaryColor").stringValue ?? "#8D1230"
        let darker = RemoteConfig.remoteConfig().configValue(forKey: "darkerPrimary").stringValue ?? "#460817"
        let accent = RemoteConfig.remoteConfig().configValue(forKey: "accentColor").stringValue ?? "#D8AF1C"
        let statusTwo = RemoteConfig.remoteConfig().configValue(forKey: "statusTwoPrimary").stringValue ?? "#040405"
        
        //Only change UI colours from hex if they are EXACTLY the proper hex format
        if primary.count == 7 {
            Defaults.primaryColor = UIColor(hex: primary)
        }
        
        if darker.count == 7 {
            Defaults.darkerPrimary = UIColor(hex: darker)
        }
        
        if accent.count == 7 {
            Defaults.accentColor = UIColor(hex: accent)
        }
        
        if statusTwo.count == 7 {
            Defaults.statusTwoPrimary = UIColor(hex: statusTwo)
        }
        
        //Clubs and points
        Defaults.joiningClub = Int(RemoteConfig.remoteConfig().configValue(forKey: "joiningClub").stringValue ?? "300") ?? 300
        Defaults.attendingEvent = Int(RemoteConfig.remoteConfig().configValue(forKey: "attendingEvent").stringValue ?? "100") ?? 100
        Defaults.startingPoints = Int(RemoteConfig.remoteConfig().configValue(forKey: "startingPoints").stringValue ?? "100") ?? 100
        
        //Pic costs
        Defaults.picCosts[0] = Int(RemoteConfig.remoteConfig().configValue(forKey: "basicPic").stringValue ?? "30") ?? 30
        Defaults.picCosts[1] = Int(RemoteConfig.remoteConfig().configValue(forKey: "commonPic").stringValue ?? "50") ?? 50
        Defaults.picCosts[2] = Int(RemoteConfig.remoteConfig().configValue(forKey: "rarePic").stringValue ?? "100") ?? 100
        Defaults.picCosts[3] = Int(RemoteConfig.remoteConfig().configValue(forKey: "coolPic").stringValue ?? "200") ?? 200
        Defaults.picCosts[4] = Int(RemoteConfig.remoteConfig().configValue(forKey: "legendaryPic").stringValue ?? "500") ?? 500
        
        //Song Requests
        Defaults.maxSongs = Int(RemoteConfig.remoteConfig().configValue(forKey: "maxSongs").stringValue ?? "20") ?? 20
        Defaults.requestSong = Int(RemoteConfig.remoteConfig().configValue(forKey: "requestSong").stringValue ?? "20") ?? 20
        Defaults.supervoteMin = Int(RemoteConfig.remoteConfig().configValue(forKey: "supervoteMin").stringValue ?? "10") ?? 10
        
        Defaults.supervoteRatio = CGFloat(((RemoteConfig.remoteConfig().configValue(forKey: "supervoteRatio").stringValue ?? "1.0") as NSString).floatValue)
        
        Defaults.songRequestTheme = RemoteConfig.remoteConfig().configValue(forKey: "songRequestTheme").stringValue ?? ""
        
        let showUsers = RemoteConfig.remoteConfig().configValue(forKey: "showUsersOnSongs").stringValue ?? "1"
        if showUsers == "1" {
            Defaults.showUsersOnSongs = true
        } else {
            Defaults.showUsersOnSongs = false
        }
        
        //Titan Tag
        let addK12 = RemoteConfig.remoteConfig().configValue(forKey: "addK12ToTT").stringValue ?? "1"
        if addK12 == "1" {
            Defaults.addK12ToTT = true
        } else {
            Defaults.addK12ToTT = false
        }
        
        let showLogo = RemoteConfig.remoteConfig().configValue(forKey: "showLogoInTT").stringValue ?? "1"
        if showLogo == "1" {
            Defaults.showLogoInTT = true
        } else {
            Defaults.showLogoInTT = false
        }
        
        //Now actually change the colours
        changeMenuControllerColours()
    }
    
    func changeMenuControllerColours() {
        //Colours
        gradientSocialView.backgroundColor = Defaults.primaryColor
        dateAndDayView.backgroundColor = Defaults.accentColor
        navigationController?.navigationBar.barTintColor = Defaults.primaryColor
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        clubAnnouncementsLabel.textColor = Defaults.primaryColor
    }
    
    func updateDatabaseWithNewRemoteID() {
        InstanceID.instanceID().instanceID { (result, error) in
            if let error = error {
                print("Error fetching remote instance ID: \(error)")
            } else if let result = result {
                
                //Also get the info doc token
                self.db.collection("users").document((Auth.auth().currentUser?.uid)!).collection("info").document("vital").getDocument(completion: { (snap, err) in
                    if let err = err {
                        print(err)
                    }
                    if let snap = snap {
                        let data = snap.data()
                        let msgToken = data?["msgToken"] as? String ?? "error"
                        
                        //IF the msgToken is different reset that on the info doc
                        if result.token != msgToken {
                            self.db.collection("users").document((Auth.auth().currentUser?.uid)!).collection("info").document("vital").setData(["msgToken": result.token], merge: true)
                            
                            //Resubscribe to everything
                            for club in allUserFirebaseData.data["notifications"] as? [String] ?? ["general"] {
                                Messaging.messaging().subscribe(toTopic: club) { error in
                                    print("Subscribed to \(club) topic")
                                }
                            }
                        }
                    }
                })
            }
        }
    }
    
    func getClubAnncs(){
        clubNewsData.removeAll()
        for club in allUserFirebaseData.data["clubs"] as! [String] {
            db.collection("announcements").whereField("club", isEqualTo: club).getDocuments { (snap, err) in
                if let err = err {
                    let alert = UIAlertController(title: "Error in retrieveing some club announcements", message: "Please try again later. \(err.localizedDescription)", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                    alert.addAction(okAction)
                    self.present(alert, animated: true, completion: nil)
                }
                if let snap = snap {
                    for annc in snap.documents {
                        let data = annc.data()
                        //Check Dates
                        //Get the date the announcement was made
                        let timestamp: Timestamp = data["date"] as! Timestamp
                        let date: Date = timestamp.dateValue()
                        let weekAgoDate = Calendar.current.date(byAdding: .day, value: -7, to: self.theDate)
                        
                        if date > weekAgoDate! {
                            self.clubNewsData.append(data)
                        }
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            //print(self.clubNewsData)
            self.sortAnncByDate()
        }
    }
    
    func sortAnncByDate() {
        if clubNewsData.count == 0 {
            clubAnncHeight.constant = 0
            self.clubAnncView.reloadData()
            return
        }
        
        if clubNewsData.count > 1 {
            var thereWasASwap = true
            while thereWasASwap {
                thereWasASwap = false
                for i in 0...clubNewsData.count-2 {
                    let timestamp1: Timestamp = clubNewsData[i]["date"] as! Timestamp
                    let date1: Date = timestamp1.dateValue()
                    let timestamp2: Timestamp = clubNewsData[i + 1]["date"] as! Timestamp
                    let date2: Date = timestamp2.dateValue()
                    
                    //Swap values
                    if date2 > date1 {
                        thereWasASwap = true
                        let temp = clubNewsData[i]
                        clubNewsData[i] = clubNewsData[i+1]
                        clubNewsData[i+1] = temp
                    }
                }
            }
        }
        self.clubAnncView.reloadData()
    }
    
    func getPicture(i: Int) {
        //Image
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        // Create a reference to the file you want to download
        let imgRef = storageRef.child("profilePictures/\(i).png")
        
        imgRef.getMetadata { (metadata, error) in
            if let error = error {
                // Uh-oh, an error occurred!
                print("cant find image \(i)")
                print(error)
            } else {
                // Metadata now contains the metadata for 'images/forest.jpg' 
                if let metadata = metadata {
                    let theMetaData = metadata.dictionaryRepresentation()
                    let updated = theMetaData["updated"]
                    
                    if let updated = updated {
                        if let savedImage = self.getSavedImage(named: "\(i)=\(updated)"){
                            print("already saved \(i)=\(updated)")
                            self.profilePicture.image = savedImage
                            allUserFirebaseData.profilePic = savedImage
                        } else {
                            // Create a reference to the file you want to download
                            imgRef.downloadURL { url, error in
                                if error != nil {
                                    //print(error)
                                    print("cant find image \(i)")
                                    self.profilePicture.image = self.fillerImage
                                } else {
                                    // Get the download URL
                                    var image: UIImage?
                                    let data = try? Data(contentsOf: url!)
                                    if let imageData = data {
                                        image = UIImage(data: imageData)!
                                        self.profilePicture.image = image!
                                        allUserFirebaseData.profilePic = image!
                                        self.clearImageFolder(imageName: "\(i)=\(updated)")
                                        self.saveImageDocumentDirectory(image: image!, imageName: "\(i)=\(updated)")
                                    }
                                    print("i success now")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    //*****************************************Annoucments Table**************************************
    //Make sure when you add collection view you add data source and delegate connections on storyboard
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == clubAnncView {
            return clubNewsData.count
        } else {
            return newsData.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        //Club
        if collectionView == clubAnncView {
            let theFont = UIFont(name: "Scada-Regular", size: 18)!
            //Dynamically change the cell size depending on the announcement length
            let size = CGSize(width: view.frame.width - 8, height: 1000)
            //Get an approximation of the title size
            let attributesTitle = [NSAttributedString.Key.font: theFont]
            let estimatedFrameTitle = NSString(string: clubNewsData[indexPath.item]["title"] as! String).boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributesTitle, context: nil)
            
            //Get an approximation of the description size
            let attributesContent = [NSAttributedString.Key.font: theFont]
            let estimatedFrameContent = NSString(string: clubNewsData[indexPath.item]["content"] as! String).boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributesContent, context: nil)
            let theHeight = estimatedFrameContent.height + estimatedFrameTitle.height + 125
            
            var imgLabelHeight: CGFloat = 0
            //If there is an image attached, just tell them to go to the club page
            if clubNewsData[indexPath.item]["img"] as? String ?? "" != "" {
                imgLabelHeight = 20
            }
            
            //Also add the height of the picture and the announcements and the space inbetween
            return CGSize(width: view.frame.width, height: theHeight + imgLabelHeight)
        }
        
        //General
        else {
            //Dynamically change the cell size depending on the announcement length
            let approxWidthOfAnnouncementTextView = view.frame.width - 8
            var size = CGSize(width: approxWidthOfAnnouncementTextView, height: 1000)
            var attributes = [NSAttributedString.Key.font: UIFont(name: "Scada-Regular", size: 18)!]
            var estimatedFrame = NSString(string: newsData[indexPath.row][1]).boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            let contentHeight =  estimatedFrame.height + 8
            
            size = CGSize(width: approxWidthOfAnnouncementTextView, height: 1000)
            attributes = [NSAttributedString.Key.font: UIFont(name: "Scada-Regular", size: 19)!]
            estimatedFrame = NSString(string: newsData[indexPath.row][0]).boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            let titleHeight = estimatedFrame.height + 8
            
            return CGSize(width: view.frame.width, height: contentHeight + titleHeight + 32)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        //Dynamically adjust home screen
        //There is really no reason this should be here, i just need it to run at leats once. maybe it could be put in sizeForItemAt or even numberOfItemsInSection
        //As long as this auto adjusts to the length of the height
        calendarButton.isHidden = false
        let height = self.annoucView.contentSize.height + self.clubAnncView.contentSize.height + 340
        self.anncViewHeight.constant = self.annoucView.contentSize.height + 10
        self.clubAnncHeight.constant = self.clubAnncView.contentSize.height + 10
        
        //If the screen is too small to fit all announcements, just change the height to whatever it is
        if height > UIScreen.main.bounds.height {
            self.homeScrollViewHeight.constant = height
        } else {
            self.homeScrollViewHeight.constant = UIScreen.main.bounds.height
        }
        
        if collectionView == annoucView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! newsViewCell
            //print("i get run data \(newsData[indexPath.item][0]) replacing \(cell.depName.text)")
            
            //Allow for live links and data
            cell.anncText.isUserInteractionEnabled = true
            cell.anncText.isScrollEnabled = false
            cell.anncText.isEditable = false
            cell.anncText.tintColor = Defaults.accentColor
            cell.anncText.dataDetectorTypes = UIDataDetectorTypes.all
            
            //Add drop shadow to cell
            cell.layer.shadowColor = UIColor.lightGray.cgColor
            cell.layer.shadowOffset = CGSize(width:0,height: 2.0)
            cell.layer.shadowRadius = 2.0
            cell.layer.shadowOpacity = 1.0
            cell.layer.masksToBounds = false
            cell.layer.shadowPath = UIBezierPath(roundedRect:cell.bounds, cornerRadius:cell.contentView.layer.cornerRadius).cgPath
            
            //Fill in the real announcement data
            cell.anncDep.text = newsData[indexPath.item][0]
            cell.anncText.text = newsData[indexPath.item][1]
            cell.anncDep.centerVertically()
            cell.anncText.centerVertically()
            
            //Dynamically adjust title height
            let approxWidthOfAnnouncementTextView = cell.anncText.frame.width
            let size = CGSize(width: approxWidthOfAnnouncementTextView, height: 1000)
            let attributes = [NSAttributedString.Key.font: UIFont(name: "Scada-Regular", size: 18)!]
            let estimatedFrame = NSString(string: newsData[indexPath.row][0]).boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            
            let titleHeight = estimatedFrame.height
            cell.titleHeight.constant = titleHeight + 8
            
            //No need to do this as the cell size is already the perfect size.
            //and since the bottom constraint of the anncText view is tied to the bottom of the cell we are all good
            //Dyanmically adjust content height
//            size = CGSize(width: approxWidthOfAnnouncementTextView, height: 1000)
//            attributes = [NSAttributedString.Key.font: UIFont(name: "Scada-Regular", size: 19)!]
//            estimatedFrame = NSString(string: newsData[indexPath.row][1]).boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
//
//            let contentHeight = estimatedFrame.height
//            cell.contentHeight.constant = contentHeight + 8
            
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "clubNews", for: indexPath) as! mainClubNewsCell
            
            //Get the date the announcement was made
            let timestamp: Timestamp = clubNewsData[indexPath.row]["date"] as! Timestamp
            let date: Date = timestamp.dateValue()
            
            //Allow for live links and data
            cell.contentLabel.isUserInteractionEnabled = true
            cell.contentLabel.isScrollEnabled = false
            cell.contentLabel.isEditable = false
            cell.contentLabel.tintColor = Defaults.accentColor
            cell.contentLabel.dataDetectorTypes = UIDataDetectorTypes.all
            
            //colours
            cell.clubLabel.backgroundColor = Defaults.accentColor
            cell.dateLabel.backgroundColor = Defaults.primaryColor
            cell.titleLabel.textColor = Defaults.primaryColor
            
            //text
            cell.clubLabel.text = clubNewsData[indexPath.item]["clubName"] as? String ?? "error"
            cell.dateLabel.text = DateFormatter.localizedString(from: date, dateStyle: DateFormatter.Style.full, timeStyle: DateFormatter.Style.none)
            cell.titleLabel.text = clubNewsData[indexPath.item]["title"] as? String ?? "error"
            cell.contentLabel.text = clubNewsData[indexPath.item]["content"] as? String ?? "error"
            
            //If there is an image attached, just tell them to go to the club page
            if clubNewsData[indexPath.item]["img"] as? String ?? "" != "" {
                cell.seeImageLabelHeight.constant = 20
                cell.seeImageLabel.isHidden = false
            } else {
                cell.seeImageLabelHeight.constant = 0
                cell.seeImageLabel.isHidden = true
            }
            
            let theFont = UIFont(name: "Scada-Regular", size: 18)
            let size = CGSize(width: view.frame.width, height: 1000)
            let attributesContent = [NSAttributedString.Key.font: theFont]
            let estimatedFrameContent = NSString(string: clubNewsData[indexPath.item]["content"] as! String).boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributesContent as [NSAttributedString.Key : Any], context: nil)
            cell.contentHeight.constant = estimatedFrameContent.height + 20
            
            let estimatedtitleContent = NSString(string: clubNewsData[indexPath.item]["title"] as! String).boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributesContent as [NSAttributedString.Key : Any], context: nil)
            cell.titleHeight.constant = estimatedtitleContent.height + 20
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("you pushed \(indexPath.item)")
    }
    
    @IBAction func calendarButtonPushed(_ sender: Any) {
        var didAddCalendar = false
        
        if let x = UserDefaults.standard.object(forKey: "didAddCalendar") as? Bool {
           didAddCalendar = x
        }
        
        if didAddCalendar {
            let interval = Int(theDate.timeIntervalSinceReferenceDate)
            let url = URL(string: String(format: "calshow:%ld", interval))
            if let url = url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        } else {
            //Prompt user to add calendar
            UserDefaults.standard.set(true, forKey: "didAddCalendar")
            guard let url = URL(string: "https://calendar.google.com/calendar/r?cid=ycdsbk12.ca_f456pem6p0idarcilfuqiakaa8@group.calendar.google.com&cid=ycdsbk12.ca_4tepqngmnt9htbg435bmbpf3tg@group.calendar.google.com") else { return }
            let svc = SFSafariViewController(url: url)
            present(svc, animated: true, completion: nil)
        }
    }

    
    //*****************************************REFRESHING DATA**************************************
    func addRefreshControl(){
        refreshControl = UIRefreshControl()
        refreshControl?.tintColor = UIColor.red
        refreshControl?.addTarget(self, action: #selector(refreshList), for: .valueChanged)
        homeScrollView.addSubview(refreshControl!)
    }
    
    @objc func refreshList(){
        //Colours
        setupRemoteConfigDefaults()
        updateViewWithRCValues()
        fetchRemoteConfig()
        
        getDayNumber()
        newsTask()
        
        let user = Auth.auth().currentUser
        db.collection("users").document((user?.uid)!).getDocument { (docSnapshot, err) in
            if let docSnapshot = docSnapshot {
                //Check if the user even exists
                if let data = docSnapshot.data() {
                    print("i get the data")
                    allUserFirebaseData.data = data
                    self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                    self.getPicture(i: data["profilePic"] as? Int ?? 0)
                    self.getClubAnncs()
                    self.updateDatabaseWithNewRemoteID()
                } else {
                    print("wow 100% dont exist")
                    self.hideActivityIndicator(container: self.container, actInd: self.actInd)
                    let alert = UIAlertController(title: "Error", message: "You could not be located in the database. Please enter your details again.", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default , handler: { (action) in
                        self.performSegue(withIdentifier: "signInFlow", sender: self.newUserButton)
                    })
                    alert.addAction(okAction)
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                print("wow u dont exist")
                let alert = UIAlertController(title: "Error", message: "You could not be located in the database. Try again later.", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .cancel, handler: { (action) in
                    self.performSegue(withIdentifier: "failedLogin", sender: self.failedSignInButton)
                })
                alert.addAction(okAction)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshControl?.endRefreshing()
        }
    }
    
    //******************************************DEALING WITH THE MENU***************************************
    @IBAction func openMenu(_ sender: Any) {
        //Show the menu by changing the left constraint
        if (menuShowing) {
            leadingConstraint.constant = -400
        } else{
            leadingConstraint.constant = 0
        }
        //animate it
        UIView.animate(withDuration: 0.3, animations: {self.view.layoutIfNeeded()})
        view.layoutIfNeeded()
        menuShowing = !menuShowing
    }
    
    @IBAction func tapOutOfMenu(_ sender: Any) {
        //Hide the menu
        leadingConstraint.constant = -400
        UIView.animate(withDuration: 0.3, animations: {self.view.layoutIfNeeded()})
        view.layoutIfNeeded()
    }
    
    //User can swipe left or right to hide and show menu
    @IBAction func leftSwipe(_ sender: Any) {
        //Hide the menu
        leadingConstraint.constant = -400
        UIView.animate(withDuration: 0.3, animations: {self.view.layoutIfNeeded()})
        view.layoutIfNeeded()
    }
    
    @IBAction func rightSwipe(_ sender: Any) {
        //Show the menu
        leadingConstraint.constant = 0
        UIView.animate(withDuration: 0.3, animations: {self.view.layoutIfNeeded()})
        view.layoutIfNeeded()
    }
    
    //*************************************UPDATE THE DAY NUMBER**************************************
    func getDayNumber() {
        db.collection("info").document("dayNumber").getDocument { (snap, err) in
            if let err = err {
                self.dayNumber.text = "Error: \(err.localizedDescription)"
            }
            if let snap = snap {
                let data = snap.data() ?? ["dayNumber": "0", "haveFun": false, "snowDay": false]
                let theDayNumber = data["dayNumber"] as? String ?? "0"
                let haveFun = data["haveFun"] as? Bool ?? false
                let snowDay = data["snowDay"] as? Bool ?? false
                
                if snowDay {
                    self.snowDayLabel.isHidden = false
                    self.snowDayLabelHeight.constant = 25
                    self.snowDayLabel.textColor = Defaults.darkerPrimary
                } else {
                    self.snowDayLabelHeight.constant = 0
                }
                
                //Only display the day number if the day is 1 or 2
                if (theDayNumber == "1" || theDayNumber == "2") {
                    self.dayNumberHeight.constant = 25
                    self.dayNumber.isHidden = false
                    
                    let theDay = DateFormatter.localizedString(from: self.theDate, dateStyle: DateFormatter.Style.full, timeStyle: DateFormatter.Style.none)
                    //If its a weekend set up the "monday will be message"
                    if (theDay.range(of:"Sunday") != nil) || (theDay.range(of:"Saturday") != nil){
                        if theDayNumber == "1" {
                            self.dayNumber.text = "Monday will be a Day 2"
                        } else if theDayNumber == "2" {
                            self.dayNumber.text = "Monday will be a Day 1"
                        }
                    }
                    
                    //Otherwise just display the normal day number
                    else {
                        self.dayNumber.text = "Day \(theDayNumber)"
                    }
                } else {
                    if haveFun {
                        //directly show the text entered in db
                        self.dayNumberHeight.constant = 25
                        self.dayNumber.text = theDayNumber
                        self.dayNumber.isHidden = false
                    } else {
                        //Any other values like "O" or anything just dont show the label
                        self.dayNumber.isHidden = true
                        self.dayNumberHeight.constant = 0
                    }
                }

            }
        }
    }
    
    //*********************************************GETTING NEWS**************************************************
    func newsTask(){
        let task2 = URLSession.shared.dataTask(with: newsURL!) { (data, response, error) in
            if let error = error {
                print("error in finding news page")
                self.newsData = [["No internet connection","Can't find news"]]
                let alert = UIAlertController(title: "Error in retrieveing School News", message: "Please Try Again later. Error: \(error.localizedDescription)", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(okAction)
                self.present(alert, animated: true, completion: nil)
                DispatchQueue.main.async {
                    self.annoucView.reloadData()
                }
            } else{
                let htmlContent = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)!
                self.newsData = self.processNewsSite(content: htmlContent as String)
                DispatchQueue.main.async {
                    self.annoucView.reloadData()
                }
            }
        }
        task2.resume()
    }
    
    func processNewsSite(content: String) -> [[String]]{
        //Content is the website code
        //GET STRING BETWEEN 'ancmnt = "' and '".split(",");' AND SPLIT THE DIFFERENT NEWS ITEMS (SEPARATED BY COMMAS)
        
        //The Start and End to Get Annoucments
        let start = content.index(of: "ancmnt = \"")?.encodedOffset
        let end = content.index(of: "\".split(\",\");")?.encodedOffset
        
        if start == nil || end == nil {
            return [["No internet connection","Can't find news"]]
        }
        
        let range = (start! + 10)..<end!
        
        var notFormattedCodedNews = String(content[range]).components(separatedBy: ",")
        var finalNews = Array(repeating: Array(repeating: "", count: 2), count: notFormattedCodedNews.count)
        
        for item in 0..<notFormattedCodedNews.count {
            let temp = notFormattedCodedNews[item].components(separatedBy: "%24%25-%25%24")
            
            finalNews[item][0] = temp[0].decodeUrl() ?? "Cannot Decode Name"
            
            if finalNews[item][0].contains("No Announcements Today"){
                finalNews[item][1] = ""
            }
            else{
                finalNews[item][1] = temp[1].decodeUrl() ?? "Cannot Decode Announcement"
            }
        }
        return finalNews
    }
    
    //Make the status bar white
    func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.lightContent;
    }
    
    //Get live data from apple's servers
    var theDate: Date! = Date()
    func getTimeFromServer(completionHandler: @escaping (_ getResDate: Date?) -> Void){
        let url = URL(string: "https://www.apple.com")
        let task = URLSession.shared.dataTask(with: url!) {(data, response, error) in
            let httpResponse = response as? HTTPURLResponse
            if let contentType = httpResponse?.allHeaderFields["Date"] as? String {
                //print(httpResponse)
                let dFormatter = DateFormatter()
                dFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
                let serverTime = dFormatter.date(from: contentType)
                completionHandler(serverTime)
            } else {
                //If getting server time fails, return regular date
                completionHandler(Date())
            }
        }
        task.resume()
    }
}
