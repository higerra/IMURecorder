//
//  IMUModel.swift
//  IMURecorder
//
//  Created by Yan Hang on 12/27/16.
//  Copyright © 2016 Washington Universtiy. All rights reserved.
//

import Foundation
import os.log

struct IMURecord{
	var rotation = [Double]()
	var acceleration = [Double]()
	var gravity = [Double]()
	
	init(rx:Double, ry:Double, rz:Double,
	     tx:Double, ty:Double, tz:Double,
	     gx:Double, gy:Double, gz:Double) {
		rotation = [rx,ry,rz]
		acceleration = [tx,ty,tz]
		gravity = [gx,gy,gz]
	}
}

class IMUStream{
	// MARK: properties
	var filePath_: URL!
	var identifier_: String!
	// MARK: functions
	
	init?(filename: String, id: String) {
		self.identifier_ = id
		if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first{
			self.filePath_ = dir.appendingPathComponent(filename)
			do{
				let date = Date()
				let timestamp:String = "Created at \(date)"
				try timestamp.write(to: filePath_, atomically: false, encoding: String.Encoding.utf8)
			}catch{
				return nil
			}
		}else{
			return nil
		}
	}
	
	func addRecord(rx:Double, ry:Double, rz:Double,
	               tx:Double, ty:Double, tz:Double,
	               gx:Double, gy:Double, gz:Double) -> Bool{
		return true
	}
	
}
