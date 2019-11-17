//
//  DefaultConstants.swift
//  St Augustine CHS
//
//  Created by Kenny Miu on 2019-01-03.
//  Copyright © 2019 St Augustine CHS. All rights reserved.
//

import Foundation
import UIKit

struct Defaults {
    static var darkerPrimary:UIColor = UIColor(hex: "#460817")
    static var primaryColor:UIColor = UIColor(hex: "#8D1230")
    static var accentColor:UIColor = UIColor(hex: "#D8AF1C")
    static var statusTwoPrimary:UIColor = UIColor(hex: "#040405")
    
    static var joiningClub: Int = 300
    static var attendingEvent: Int = 100
    static var startingPoints: Int = 100
    
    static var picCosts: [Int] = [30,50,100,200,500]
    
    static var maxSongs: Int = 20
    static var requestSong: Int = 20
    static var supervoteMin: Int = 10
    static var supervoteRatio: CGFloat = 1.0
    
    static var songRequestTheme: String = ""
    static var showUsersOnSongs: Bool = true
    
    static var addK12ToTT: Bool = true
    static var showLogoInTT: Bool = true
}

