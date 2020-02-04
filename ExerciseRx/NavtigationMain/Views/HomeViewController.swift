//
//  HomeViewController.swift
//  ExerciseRx
//
//  Created by OCEO on 10/30/19.
//  Copyright © 2019 OCEO. All rights reserved.
//

import UIKit
import UICircularProgressRing
import CoreMotion
import Dispatch
import BetterSegmentedControl
import HealthKit
import FirebaseAuth
import FirebaseFirestore

class HomeViewController: UIViewController{
    
    let dispatchgroup = DispatchGroup()

    @IBOutlet weak var goalView: BetterSegmentedControl!
    @IBOutlet weak var dailyStepLabel: UILabel!
    @IBOutlet weak var stepDailyCount: UILabel!
    
    @IBOutlet weak var stepCountLabel: UILabel!
    @IBOutlet weak var stepsLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var progressBar: UICircularProgressRing!
    
    let healthStore = HKHealthStore()
    
    var user = User()
    
    var docRefUser: DocumentReference!
    let userID = Auth.auth().currentUser!.uid

    private let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!


    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpUIs()
        print(userID)
        

        requestAccessToHealthKit()

        getData(userID: userID)
        
    }
    

    
    func getTodaysSteps(completion: @escaping (Double) -> Void) {
        
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepsQuantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                print(error.debugDescription)
                return
            }
        
            completion(sum.doubleValue(for: HKUnit.count()))

            
        }

        healthStore.execute(query)
    }

    func getData(userID: String) {
        

        let cloudRef =  Firestore.firestore().collection("ExerciseRxUserData").document(userID).collection("Dates")
        
        
        cloudRef.getDocuments { (querySnapshot, err) in
            if let err = err{
                print("error: \(err.localizedDescription)")
            }else{
                
                if querySnapshot!.documents.count == 0{
                    let date = Date()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy.MM.dd"
                    let result = formatter.string(from: date)

                    self.addData(date: result, userID: userID)
                    
                }else{
                    
                    let myData = querySnapshot!.documents[querySnapshot!.documents.count - 1].documentID
                
                    let startDate = myData

                    var dateFrom =  Date() // First date
                    let dateTo = Date()   // Last date

                    // Formatter for printing the date, adjust it according to your needs:
                    let fmt = DateFormatter()
                    fmt.dateFormat = "yyyy.MM.dd"
                    dateFrom = fmt.date(from: startDate)!
                    dateFrom = Calendar.current.date(byAdding: .day, value: 1, to: dateFrom)!

                    let diffInDays = Calendar.current.dateComponents([.day], from: dateFrom, to: dateTo).day
                    var stepGoal = false
                    
                    print(diffInDays!)
                    
                    if diffInDays! >= 13 {
                        stepGoal = true
                    }

                    self.importStepsHistory(days: diffInDays!, userID: userID, stepGoal: stepGoal, upload: true) { (average) in
                        
                        DispatchQueue.main.async {
                            var count = Int(self.increaseStepCount(percentage: 0.02, count: average / 14))
                            self.stepDailyCount.text = "\(count)"

                        }
                    }


                }
                
            }
        }
    }
    
    
    func importStepsHistory(days: Int, userID: String, stepGoal: Bool, upload: Bool , completion: @escaping (Double) -> Void) {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: now)!

        var interval = DateComponents()
        interval.day = 1

        var anchorComponents = Calendar.current.dateComponents([.day, .month, .year], from: now)
        anchorComponents.hour = 0
        let anchorDate = Calendar.current.date(from: anchorComponents)!
        
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"

        let query = HKStatisticsCollectionQuery(quantityType: stepsQuantityType,
                                            quantitySamplePredicate: nil,
                                            options: [.cumulativeSum],
                                            anchorDate: anchorDate,
                                            intervalComponents: interval)
        var average = 0.0

        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
//                log.error("Error returned form resultHandler = \(String(describing: error?.localizedDescription))")
                return
        }

            
            results.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    let steps = sum.doubleValue(for: HKUnit.count())
                    average += steps
                    print("Amount of steps: \(steps), date: \(fmt.string(from: statistics.startDate))")
                    
                    if upload{
                        self.docRefUser = Firestore.firestore().collection("ExerciseRxUserData").document(userID).collection("Dates").document(fmt.string(from: statistics.startDate))
                        let values = ["StepCount":steps]

                        self.docRefUser.setData(values as [String : Any]) { (error) in
                            if let error = error {
                                print("Got an error: \(error.localizedDescription)")
                            } else{
                                print("Success")
                            }
                        }

                    }

                }
            }
            print(average)

            if stepGoal {
                
                print("Here\(average)")
            
                self.docRefUser = Firestore.firestore().collection("ExerciseRxUserData").document(userID).collection("Step Average Date").document(fmt.string(from: now))

                let counts = self.increaseStepCount(percentage: 0.02, count: average / 14)
                let values = ["Step Count Goal" : Int(counts), "Last Date": fmt.string(from: now)] as [String : Any]
                
                self.docRefUser.setData(values as [String : Any]) { (error) in
                    if let error = error {
                        print("Got an error: \(error.localizedDescription)")
                    } else{
                        print("Success")
                    }
                }
                completion(counts)

            }

            completion(average)
                        
        }
        

        healthStore.execute(query)
    }

    func increaseStepCount(percentage: Double, count: Double) -> Double{
        let delta = count * percentage
        let result = count + delta
        
        return (result)
    }
    
    func addData(date: String, userID: String){

        print("Here \(date)")
        
        self.docRefUser = Firestore.firestore().collection("ExerciseRxUserData").document(userID).collection("Dates").document(date)
        
            self.getTodaysSteps { (count) in
                
                let values = ["StepCount":count]
                self.docRefUser.setData(values as [String : Any]) { (error) in
                    if let error = error {
                        print("Got an error: \(error.localizedDescription)")
                    } else{
                        print("Success")
                    }
                }

        }

        
    }
    func setUpUIs() {
        
        
        view.backgroundColor = .white
        
        let purple = UIColor(red: 51/255, green: 0/255, blue: 111/255, alpha: 1)
        stepCountLabel.font = UIFont(name: "AvenirNextCondensed-Bold", size: 15)
        stepCountLabel.textColor = purple

        let gray = UIColor(red: 50/255, green: 62/255, blue: 72/255, alpha: 1)
        stepsLabel.font = UIFont(name: "AvenirNextCondensed-Regular", size: 15)
        stepsLabel.textColor = gray
        stepsLabel.text = "6,421 Steps"
        
        dateLabel.font = UIFont(name: "AvenirNextCondensed-UltraLight", size: 10)
        dateLabel.textColor = gray
        dateLabel.text = "September 20 - 27"
        
        progressBar.maxValue = 100
        progressBar.resetProgress()
        progressBar.startAngle = -90
        progressBar.isClockwise = true
        
        progressBar.outerRingColor = .lightGray
        progressBar.outerRingWidth = 10
        
        progressBar.innerRingWidth = 10
        progressBar.innerCapStyle = .round
        progressBar.innerRingColor = purple
        
        progressBar.style = .bordered(width: 0, color: .black)
        progressBar.fontColor = gray
        progressBar.font = UIFont(name: "AvenirNextCondensed-UltraLight", size: 25)!
        
        goalView.segments = LabelSegment.segments(withTitles: ["Daily", "Weekly", "Montly"],
                                                  normalFont: UIFont(name: "AvenirNextCondensed-Bold", size: 13.0)!,
                                                  selectedFont: UIFont(name: "AvenirNextCondensed-Bold", size: 13.0)!)

        let color = UIColor(red: 51/255, green: 0/255, blue: 111/255, alpha: 0.5)
//
        goalView.setIndex(1)
        goalView.addTarget(self,action: #selector(navigationSegmentedControlValueChanged(_:)),for: .valueChanged)
        
        dailyStepLabel.text = "Daily Step Goal"
        dailyStepLabel.font = UIFont(name: "AvenirNextCondensed-Bold", size: 15)
        dailyStepLabel.textColor = purple
        

    }
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        progressBar.startProgress(to: 70, duration: 2.0)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
       private func requestAccessToHealthKit() {


            let healthKitTypesToWrite: Set<HKSampleType> = [
                HKObjectType.workoutType(),
                HKSeriesType.workoutRoute(),
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
                HKObjectType.quantityType(forIdentifier: .bodyMass)!,
                HKObjectType.quantityType(forIdentifier: .vo2Max)!,
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!]

            let healthKitTypesToRead: Set<HKObjectType> = [
                HKObjectType.workoutType(),
                HKSeriesType.workoutRoute(),
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
                HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
                HKObjectType.quantityType(forIdentifier: .bodyMass)!,
                HKObjectType.quantityType(forIdentifier: .vo2Max)!,
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!]

            let authorizationStatus = healthStore.authorizationStatus(for: HKSampleType.workoutType())

            switch authorizationStatus {

                case .sharingAuthorized: print("sharing authorized")
                    print("sharing authorized this message is from Watch's extension delegate")

                case .sharingDenied: print("sharing denied")

                   healthStore.requestAuthorization(toShare: healthKitTypesToWrite, read: healthKitTypesToRead) { (success, error) in
                        print("Successful HealthKit Authorization from Watch's extension Delegate")
                }

                default: print("not determined")

                healthStore.requestAuthorization(toShare: healthKitTypesToWrite, read: healthKitTypesToRead) { (success, error) in
                    print("Successful HealthKit Authorization from Watch's extension Delegate")
                }

            }
        }

    
    @objc func navigationSegmentedControlValueChanged(_ sender: BetterSegmentedControl) {
        if sender.index == 0 {
            getTodaysSteps { (step) in
                DispatchQueue.main.async {
                    self.stepCountLabel.text = "Daily Step Count"
                    self.stepsLabel.text = "\(Int(step))"
                    self.dateLabel.text = "September 20"
                }
            }
//            progressBar.startProgress(to: 20, duration: 2.0)

        } else if sender.index == 1{
            
            importStepsHistory(days: 7, userID: userID, stepGoal: false, upload: false) { (total) in
                DispatchQueue.main.async {
                    self.stepCountLabel.text = "Weekly Step Count"
                    self.stepsLabel.text = "\(Int(total))"
                    self.dateLabel.text = "September 20 - 27"
                    self.progressBar.startProgress(to: 70, duration: 2.0)
                }

            }

        } else{
            
            importStepsHistory(days: 30, userID: userID, stepGoal: false, upload: false) { (total) in
                DispatchQueue.main.async {
                    self.stepCountLabel.text = "Monthly Step Count"
                    self.stepsLabel.text = "\(Int(total))"
                    self.dateLabel.text = "September - October"
                    self.progressBar.startProgress(to: 70, duration: 2.0)
                }

            }



        }
    }

}
