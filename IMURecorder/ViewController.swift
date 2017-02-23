//
//  ViewController.swift
//  IMURecorder
//
//  Created by Yan Hang on 12/27/16.
//  Copyright © 2016 Washington Universtiy. All rights reserved.
//

import UIKit
import CoreMotion
import os.log

class ViewController: UIViewController {
	
	let kSensor = 6
	let GYROSCOPE = 0
	let ACCELEROMETER = 1
	let LINEAR_ACCELERATION = 2
	let GRAVITY = 3
	let MAGNETOMETER = 4
	let ROTATION_VECTOR = 5
	
	// MARK: properties
	@IBOutlet weak var startButton: UIButton!
	@IBOutlet weak var statusLabel: UILabel!
	@IBOutlet weak var counterLabel: UILabel!
	@IBOutlet weak var rxLabel: UILabel!
	@IBOutlet weak var ryLabel: UILabel!
	@IBOutlet weak var rzLabel: UILabel!
	@IBOutlet weak var axLabel: UILabel!
	@IBOutlet weak var ayLabel: UILabel!
	@IBOutlet weak var azLabel: UILabel!
	@IBOutlet weak var gxLabel: UILabel!
	@IBOutlet weak var gyLabel: UILabel!
	@IBOutlet weak var gzLabel: UILabel!
	@IBOutlet weak var lxLabel: UILabel!
	@IBOutlet weak var lyLabel: UILabel!
	@IBOutlet weak var lzLabel: UILabel!
	@IBOutlet weak var mxLabel: UILabel!
	@IBOutlet weak var myLabel: UILabel!
	@IBOutlet weak var mzLabel: UILabel!
	@IBOutlet weak var oxLabel: UILabel!
	@IBOutlet weak var oyLabel: UILabel!
	@IBOutlet weak var ozLabel: UILabel!
	
	let sampleInterval: TimeInterval = 1.0 / 30.0;
	let sampleFrequency: TimeInterval = 100
	let gravity: Double = 9.81
	
	let motionManager: CMMotionManager = CMMotionManager()
	let customQueue: DispatchQueue = DispatchQueue(label: "edu.wustl.cse.IMURecorder.customQueue")
	var recordingTimer: Timer = Timer()
	var secondCounter:Int64 = 0{
		didSet{
			statusLabel.text = interfaceIntTime(second: secondCounter)
		}
	}
	var recordCounter:Int64 = 0{
		didSet{
			counterLabel.text = "\(self.recordCounter)"
		}
	}
	
	let mulSecondToNanoSecond: Double = 1000000000
	
	var isRecording: Bool = false
	let defaultValue: Double = 0.0
	
	var fileHandlers = [FileHandle]()
	var fileURLs = [URL]()
	var fileNames: [String] = ["gyro.txt", "acce.txt", "linacce.txt", "gravity.txt", "magnet.txt", "orientation.txt"]
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		self.statusLabel.text = "Standby"
		
		self.customQueue.async {
			self.startIMUUpdate()
		}
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		self.customQueue.sync {
			self.stopIMUUpdate()
		}
	}
	
	// MARK: Actions
	@IBAction func startStopRecording(_ sender: UIButton) {
		if self.isRecording == false{
			// start recording
			customQueue.async {
				if self.createFiles(){
					DispatchQueue.main.async {
						// reset timer
						self.secondCounter = 0
						self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: {
							(Timer) -> Void in
							self.secondCounter += 1
						})
						
						// update UI
						self.startButton.setTitle("Stop", for: .normal)
						
						// make sure the screen won't lock
						UIApplication.shared.isIdleTimerDisabled = true
					}
					
					self.isRecording = true;
				}else{
					self.errorMsg(msg: "Failed to create the file")
					return
				}
			}
		}else{
			// stop recording and share file
			if recordingTimer.isValid{
				recordingTimer.invalidate()
			}
			
			customQueue.async {
				self.isRecording = false;
				if self.fileHandlers.count == self.kSensor{
					for handler in self.fileHandlers{
						handler.closeFile()
					}
					DispatchQueue.main.async {
						let activityVC = UIActivityViewController(activityItems: self.fileURLs, applicationActivities: nil)
						self.present(activityVC, animated: true, completion: nil)
					}
				}
			}
			
			// update UI
			self.rxLabel.text = String(format:"%.6f", self.defaultValue)
			self.ryLabel.text = String(format:"%.6f", self.defaultValue)
			self.rzLabel.text = String(format:"%.6f", self.defaultValue)
			self.axLabel.text = String(format:"%.6f", self.defaultValue)
			self.ayLabel.text = String(format:"%.6f", self.defaultValue)
			self.azLabel.text = String(format:"%.6f", self.defaultValue)
			self.gxLabel.text = String(format:"%.6f", self.defaultValue)
			self.gyLabel.text = String(format:"%.6f", self.defaultValue)
			self.gzLabel.text = String(format:"%.6f", self.defaultValue)
			self.lxLabel.text = String(format:"%.6f", self.defaultValue)
			self.lyLabel.text = String(format:"%.6f", self.defaultValue)
			self.lzLabel.text = String(format:"%.6f", self.defaultValue)
			self.mxLabel.text = String(format:"%.6f", self.defaultValue)
			self.myLabel.text = String(format:"%.6f", self.defaultValue)
			self.mzLabel.text = String(format:"%.6f", self.defaultValue)
			self.oxLabel.text = String(format:"%.6f", self.defaultValue)
			self.oyLabel.text = String(format:"%.6f", self.defaultValue)
			self.ozLabel.text = String(format:"%.6f", self.defaultValue)
			
			self.startButton.setTitle("Start", for: .normal)
			self.statusLabel.text = "Standby"
			
			// resume screen lock
			UIApplication.shared.isIdleTimerDisabled = false
		}
	}
	
	private func startIMUUpdate(){
		self.motionManager.gyroUpdateInterval = 1.0 / self.sampleFrequency
		self.motionManager.accelerometerUpdateInterval = 1.0 / self.sampleFrequency
		self.motionManager.deviceMotionUpdateInterval = 1.0 / self.sampleFrequency
		self.motionManager.magnetometerUpdateInterval = 1.0 / self.sampleFrequency
		
		// Start motion update
		if !motionManager.isAccelerometerActive{
			self.motionManager.startAccelerometerUpdates(to: OperationQueue.main, withHandler: {
				(motion: CMAccelerometerData?, error: Error?) -> Void in
				if let curmotion = motion{
					let x = curmotion.acceleration.x * self.gravity
					let y = curmotion.acceleration.y * self.gravity
					let z = curmotion.acceleration.z * self.gravity
					DispatchQueue.main.async {
						self.axLabel.text = String(format:"%.6f", x)
						self.ayLabel.text = String(format:"%.6f", y)
						self.azLabel.text = String(format:"%.6f", z)
					}
					self.customQueue.async {
						if self.fileHandlers.count == self.kSensor && self.isRecording{
							let out_str = String(format: "%.0f %.6f %.6f %.6f\n",
							                     Date().timeIntervalSince1970 * self.mulSecondToNanoSecond,
							                     x, y, z)
							if let data_to_write = out_str.data(using: .utf8){
								self.fileHandlers[self.ACCELEROMETER].write(data_to_write)
							}else{
								os_log("Failed to write data record", log: OSLog.default, type: .fault)
							}
						}
					}
				}
			})
		}
		
		if !motionManager.isGyroActive{
			self.motionManager.startGyroUpdates(to: OperationQueue.main, withHandler: {
				(motion: CMGyroData?, error: Error?) -> Void in
				if let curmotion = motion{
					let x = curmotion.rotationRate.x
					let y = curmotion.rotationRate.y
					let z = curmotion.rotationRate.z
					DispatchQueue.main.async {
						self.rxLabel.text = String(format:"%.6f", x)
						self.ryLabel.text = String(format:"%.6f", y)
						self.rzLabel.text = String(format:"%.6f", z)
					}
					self.customQueue.async {
						if self.fileHandlers.count == self.kSensor && self.isRecording{
							let out_str = String(format: "%.0f %.6f %.6f %.6f\n",
							                     Date().timeIntervalSince1970 * self.mulSecondToNanoSecond,
							                     x, y, z)
							if let data_to_write = out_str.data(using: .utf8){
								self.fileHandlers[self.GYROSCOPE].write(data_to_write)
							}else{
								os_log("Failed to write data record", log: OSLog.default, type: .fault)
							}
						}
					}
				}
			})
		}
		
		if !motionManager.isDeviceMotionActive{
			self.motionManager.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: {
				(motion: CMDeviceMotion?, error: Error?) -> Void in
				if let curmotion = motion{
					DispatchQueue.main.async {
						self.lxLabel.text = String(format:"%.6f", curmotion.userAcceleration.x)
						self.lyLabel.text = String(format:"%.6f", curmotion.userAcceleration.y)
						self.lzLabel.text = String(format:"%.6f", curmotion.userAcceleration.z)
						
						self.gxLabel.text = String(format:"%.6f", curmotion.gravity.x * self.gravity)
						self.gyLabel.text = String(format:"%.6f", curmotion.gravity.y * self.gravity)
						self.gzLabel.text = String(format:"%.6f", curmotion.gravity.z * self.gravity)
						
						self.oxLabel.text = String(format:"%.6f", curmotion.attitude.roll)
						self.oyLabel.text = String(format:"%.6f", curmotion.attitude.yaw)
						self.ozLabel.text = String(format:"%.6f", curmotion.attitude.pitch)
					}
					self.customQueue.async {
						if self.fileHandlers.count == self.kSensor && self.isRecording{
							var out_str = String(format: "%.0f %.6f %.6f %.6f\n",
							                     Date().timeIntervalSince1970 * self.mulSecondToNanoSecond,
							                     curmotion.userAcceleration.x, curmotion.userAcceleration.y, curmotion.userAcceleration.z)
							if let data_to_write = out_str.data(using: .utf8){
								self.fileHandlers[self.LINEAR_ACCELERATION].write(data_to_write)
							}else{
								os_log("Failed to write data record", log: OSLog.default, type: .fault)
							}
							
							out_str = String(format: "%.0f %.6f %.6f %.6f\n",
							                 Date().timeIntervalSince1970 * self.mulSecondToNanoSecond,
							                 curmotion.gravity.x, curmotion.gravity.y, curmotion.gravity.z)
							if let data_to_write = out_str.data(using: .utf8){
								self.fileHandlers[self.GRAVITY].write(data_to_write)
							}else{
								os_log("Failed to write data record", log: OSLog.default, type: .fault)
							}
							
							// Notice that for attitude, the eular angle is displayed, but the quaternion form is recorded
							out_str = String(format: "%.0f %.6f %.6f %.6f %.6f\n",
							                 Date().timeIntervalSince1970 * self.mulSecondToNanoSecond,
							                 curmotion.attitude.quaternion.x, curmotion.attitude.quaternion.y, curmotion.attitude.quaternion.z, curmotion.attitude.quaternion.w)
							if let data_to_write = out_str.data(using: .utf8){
								self.fileHandlers[self.ROTATION_VECTOR].write(data_to_write)
							}else{
								os_log("Failed to write data record", log: OSLog.default, type: .fault)
							}
						}
					}
				}
			})
		}
		
		if !motionManager.isMagnetometerActive{
			self.motionManager.startMagnetometerUpdates(to: OperationQueue.main, withHandler: {
				(motion: CMMagnetometerData?, error: Error?) -> Void in
				if let curmotion = motion{
					let x = curmotion.magneticField.x
					let y = curmotion.magneticField.y
					let z = curmotion.magneticField.z
					DispatchQueue.main.async {
						self.mxLabel.text = String(format:"%.6f", x)
						self.myLabel.text = String(format:"%.6f", y)
						self.mzLabel.text = String(format:"%.6f", z)
					}
					self.customQueue.async {
						if self.fileHandlers.count == self.kSensor && self.isRecording{
							let out_str = String(format: "%.0f %.6f %.6f %.6f\n",
							                     Date().timeIntervalSince1970 * self.mulSecondToNanoSecond,
							                     x, y, z)
							if let data_to_write = out_str.data(using: .utf8){
								self.fileHandlers[self.MAGNETOMETER].write(data_to_write)
							}else{
								os_log("Failed to write data record", log: OSLog.default, type: .fault)
							}
						}
					}
				}
			})

		}

	}
	
	private func stopIMUUpdate(){
		if self.motionManager.isGyroActive{
			self.motionManager.stopGyroUpdates()
		}
		if self.motionManager.isAccelerometerActive{
			self.motionManager.stopAccelerometerUpdates()
		}
		if self.motionManager.isMagnetometerActive{
			self.motionManager.stopMagnetometerUpdates()
		}
		if self.motionManager.isDeviceMotionActive{
			self.motionManager.stopDeviceMotionUpdates()
		}
	}
	
	// MARK: Utility functions
	private func interfaceIntTime(second: Int64) -> String{
		var input = second;
		let hours: Int64 = input / 3600;
		input = input % 3600;
		let mins: Int64 = input / 60;
		let secs: Int64 = input % 60;
		
		guard second >= 0 else{
			fatalError("Second can not be negative: \(second)");
		}
		return String(format: "%02d:%02d:%02d", hours, mins, secs)
	}
	
	private func errorMsg(msg: String){
		DispatchQueue.main.async {
			let fileAlert = UIAlertController(title: "IMURecorder", message: msg, preferredStyle: .alert)
			fileAlert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
			self.present(fileAlert, animated: true, completion: nil)
		}
	}
	
	private func timeToString() -> String{
		let date = Date()
		let calendar = Calendar.current
		let year = calendar.component(.year, from: date)
		let month = calendar.component(.month, from: date)
		let day = calendar.component(.day, from: date)
		let hour = calendar.component(.hour, from: date)
		let minute = calendar.component(.minute, from: date)
		let sec = calendar.component(.second, from: date)
		return String(format:"%04d%02d%02d_%02d%02d%02dt", year, month, day, hour, minute, sec)
	}
	
	private func createFiles() -> Bool{
		self.fileHandlers.removeAll()
		self.fileURLs.removeAll()
		let header = "Created at \(self.timeToString())"
		for i in 0...5{
			var url = URL(fileURLWithPath: NSTemporaryDirectory())
			url.appendPathComponent(fileNames[i])
			self.fileURLs.append(url)
			// Delete previous file
			if FileManager.default.fileExists(atPath: url.path){
				do{
					try FileManager.default.removeItem(at: url)
				}catch{
					os_log("Can not remove previous file", log:.default, type:.error)
					return false
				}
				
			}
			
			if !FileManager.default.createFile(atPath: url.path, contents: header.data(using: String.Encoding.utf8), attributes: nil){
				self.errorMsg(msg: "Can not create file \(self.fileNames[i])")
				return false
			}
			
			let fileHandle: FileHandle? = FileHandle(forWritingAtPath: url.path)
			if let handle = fileHandle{
				self.fileHandlers.append(handle)
			}else{
				return false
			}
		}
		return true
	}
}

