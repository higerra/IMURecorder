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
	var sampleTimer: Timer = Timer()
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
	
	var imuFile: FileHandle?
	var fileURL: URL?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		self.statusLabel.text = "Standby"
		//init timer
		
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	// MARK: Actions
	@IBAction func startStopRecording(_ sender: UIButton) {
		if self.isRecording == false{
			// start recording
			customQueue.async {
				let fileName = self.filenameFromTime()
				//self.fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
				self.fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
				if self.fileURL != nil{
					self.fileURL!.appendPathComponent(fileName)
					if !FileManager.default.fileExists(atPath: self.fileURL!.path){
						if !FileManager.default.createFile(atPath: self.fileURL!.path, contents: "test".data(using: String.Encoding.utf8), attributes: nil){
							self.errorMsg(msg: "Can not create file at \(self.fileURL!.path)")
							return
						}
					}else{
						DispatchQueue.main.async {
							let activityVC = UIActivityViewController(activityItems: [self.fileURL!], applicationActivities: nil)
							self.present(activityVC, animated: true, completion: nil)
						}
					}
					self.imuFile = FileHandle(forWritingAtPath: self.fileURL!.path)
					if self.imuFile == nil{
						self.errorMsg(msg: "Can not write to path\n \(self.fileURL!.path)")
						return
					}
					
					self.motionManager.gyroUpdateInterval = 1.0 / self.sampleFrequency
					self.motionManager.accelerometerUpdateInterval = 1.0 / self.sampleFrequency
					self.motionManager.startGyroUpdates()
					self.motionManager.startAccelerometerUpdates()
					self.motionManager.startDeviceMotionUpdates()
				}else{
					self.errorMsg(msg: "fileURL evaluated to nil")
					return
				}
			}
			
			// reset timer
			self.secondCounter = 0
			self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: {
				(Timer) -> Void in
				self.secondCounter += 1
			})
			
			// Start motion update
			self.motionManager.startAccelerometerUpdates(to: OperationQueue.main, withHandler: {
				(motion: CMAccelerometerData?, error: Error?) -> Void in
				if let curmotion = motion{
					DispatchQueue.main.async {
						self.axLabel.text = String(format:"%.6f", curmotion.acceleration.x)
						self.ayLabel.text = String(format:"%.6f", curmotion.acceleration.y)
						self.azLabel.text = String(format:"%.6f", curmotion.acceleration.z)
					}
					self.customQueue.async {
						if let outputFile = self.imuFile{
							let out_str = String(format: "%.0f %.6f %.6f %.6f\n",
							                     Date().timeIntervalSince1970 * self.mulSecondToNanoSecond,
							                     curmotion.acceleration.x,
							                     curmotion.acceleration.y,
							                     curmotion.acceleration.z)
							if let data_to_write = out_str.data(using: .utf8){
								outputFile.write(data_to_write)
							}else{
								os_log("Failed to write data record", log: OSLog.default, type=.fault)
							}
						}
					}
				}
			})
			
			self.sampleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / sampleFrequency, repeats: true, block: {
				(Timer) -> Void in
				if let gyro = self.motionManager.gyroData{
					if let accer = self.motionManager.accelerometerData{
						if let outputFile = self.imuFile{
							DispatchQueue.main.async {
								self.recordCounter += 1
								self.rxLabel.text = String(format:"%.6f", gyro.rotationRate.x)
								self.ryLabel.text = String(format:"%.6f", gyro.rotationRate.y)
								self.rzLabel.text = String(format:"%.6f", gyro.rotationRate.z)
								self.axLabel.text = String(format:"%.6f", accer.acceleration.x * self.gravity)
								self.ayLabel.text = String(format:"%.6f", accer.acceleration.y * self.gravity)
								self.azLabel.text = String(format:"%.6f", accer.acceleration.z * self.gravity)
							}
							self.customQueue.async {
								let out_str = String(format: "%.6f %.6f %.6f %.6f %.6f %.6f\n",
								                    gyro.rotationRate.x, gyro.rotationRate.y, gyro.rotationRate.z,
								                    accer.acceleration.x * self.gravity, accer.acceleration.y * self.gravity, accer.acceleration.z * self.gravity)
								if let data_to_write = out_str.data(using: .utf8){
									outputFile.write(data_to_write)
								}else{
									os_log("Failed to write data record", log: OSLog.default, type: .fault)
								}
							}
						}
					}
				}
			})
			
			// update UI
			self.startButton.setTitle("Stop", for: .normal)
			
			// make sure the screen won't lock
			UIApplication.shared.isIdleTimerDisabled = true
		}else{
			// stop recording and share file
			if recordingTimer.isValid{
				recordingTimer.invalidate()
				sampleTimer.invalidate()
			}
			
			customQueue.async {
				self.motionManager.stopGyroUpdates()
				self.motionManager.stopAccelerometerUpdates()
				if let outfile = self.imuFile{
					outfile.closeFile()
					DispatchQueue.main.async {
						let activityVC = UIActivityViewController(activityItems: [self.fileURL!], applicationActivities: nil)
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
			
			
			self.startButton.setTitle("Start", for: .normal)
			self.statusLabel.text = "Standby"
			
			// resume screen lock
			UIApplication.shared.isIdleTimerDisabled = false
			
			
		}
		self.isRecording = !self.isRecording
	}
	
	// MARK: configure motion
	/*private func startRecording(){
		if self.motionManager.isDeviceMotionAvailable{
			self.motionManager.deviceMotionUpdateInterval = self.sampleInterval
			self.motionManager.startGyroUpdates(to: OperationQueue.main, withHandler: {
				
			})
			
			self.motionManager.startAccelerometerUpdates(to: OperationQueue.main, withHandler: withHandler{
			})
			
			
			self.motionManager.startDeviceMotionUpdates(using:.xArbitraryCorrectedZVertical, to: OperationQueue.main, withHandler: {
				(motion: CMDeviceMotion?, error: Error?) -> Void in
				DispatchQueue.main.async {
					if let curmotion = motion{
						self.recordCounter += 1
						self.rxLabel.text = String(format:"%.6f", curmotion.rotationRate.x)
						self.ryLabel.text = String(format:"%.6f", curmotion.rotationRate.y)
						self.rzLabel.text = String(format:"%.6f", curmotion.rotationRate.z)
						self.txLabel.text = String(format:"%.6f", curmotion.userAcceleration.x)
						self.tyLabel.text = String(format:"%.6f", curmotion.userAcceleration.y)
						self.tzLabel.text = String(format:"%.6f", curmotion.userAcceleration.z)
						self.gxLabel.text = String(format:"%.6f", curmotion.gravity.x)
						self.gyLabel.text = String(format:"%.6f", curmotion.gravity.y)
						self.gzLabel.text = String(format:"%.6f", curmotion.gravity.z)
						
						self.customQueue.async {
							if let outputFile = self.imuFile{
								let out_str = String(format: "%.0f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f\n",
								                     Date().timeIntervalSince1970 * self.mulSecondToNanoSecond,
								                     curmotion.rotationRate.x, curmotion.rotationRate.y, curmotion.rotationRate.z,
								                     curmotion.userAcceleration.x, curmotion.userAcceleration.y, curmotion.userAcceleration.z,
								                     curmotion.gravity.x, curmotion.gravity.y, curmotion.gravity.z)
								if let data_to_write = out_str.data(using: .utf8){
									outputFile.write(data_to_write)
								}else{
									os_log("Failed to write data record", log: OSLog.default, type: .fault)
								}
							}
						}
						
					}

				}
			})
		}
	}*/
	
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
	
	private func filenameFromTime() -> String{
		let date = Date()
		let calendar = Calendar.current
		let year = calendar.component(.year, from: date)
		let month = calendar.component(.month, from: date)
		let day = calendar.component(.day, from: date)
		let hour = calendar.component(.hour, from: date)
		let minute = calendar.component(.minute, from: date)
		let sec = calendar.component(.second, from: date)
		return String(format:"%04d%02d%02d_%02d%02d%02d.txt", year, month, day, hour, minute, sec)
	}
	
}

