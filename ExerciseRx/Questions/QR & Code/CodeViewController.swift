//
//  CodeViewController.swift
//  ExerciseRx
//
//  Created by OCEO on 10/21/19.
//  Copyright © 2019 OCEO. All rights reserved.
//

import UIKit
import SkyFloatingLabelTextField
import FirebaseAuth
import FirebaseDatabase

class CodeViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var codeTextField: SkyFloatingLabelTextField!
    let dispatchgroup = DispatchGroup()
    var user = User()

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpUIs()
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isLogined()

        
    }
    
        func isLogined(){
            
            Auth.auth().addStateDidChangeListener { auth, user in
                if let user = user {
                    print("logged in ")
                    self.dispatchgroup.enter()
                    
                    self.getUser(with: user.uid, completion: { (user) in
                        self.user = user
                        self.dispatchgroup.leave()
                        
                    })
                    self.dispatchgroup.notify(queue: .main, execute: {
                        
                        self.performSegue(withIdentifier: "Code_To_Main", sender: self)
                        print("aalre")
                    })
                } else {
                    print("not logged in ")
                }
            }

        }
        
        
        func getUser(with userID: String, completion: @escaping ((_ user: User) -> Void)) {
            Database.database().reference().child("users").child(userID).observeSingleEvent(of: .value) { (snapshot) in
                // Get user value
                let value = snapshot.value as? [String: Any]
                let username = value?["name"] as? String ?? ""
                let user_first_name = value?["first_name"] as? String ?? ""
                let user_last_name = value?["last_name"] as? String ?? ""
                
                var user = User()
                user.name = username
                user.first_name = user_first_name
                user.last_name = user_last_name
                print(user.name)
                print(user.first_name)
                
                DispatchQueue.main.async {
                    completion(user)
                }
            }
        }


    func setUpUIs() {
        
        headerLabel.textColor = UIColor(red: 50/255, green: 62/255, blue: 72/255, alpha: 1)
        headerLabel.font = UIFont(name: "AvenirNextCondensed-UltraLight", size: 70)
        
        /* set the tool bar Items (Cancel - Space - Done) */
        let toolbar_LastDigit = UIToolbar();
        toolbar_LastDigit.sizeToFit()
        let doneButton_LastDigit = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(done_numberPad));
        let spaceButton_LastDigit = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let cancelButton_LastDigit = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancel_numberPad));
        toolbar_LastDigit.setItems([cancelButton_LastDigit,spaceButton_LastDigit,doneButton_LastDigit], animated: false)
        
        /* connect the date picker to the weightTextField */
        codeTextField.keyboardType = UIKeyboardType.numberPad
        codeTextField.inputAccessoryView = toolbar_LastDigit

        let color = UIColor(red: 51/255, green: 0/255, blue: 111/255, alpha: 1)

        codeTextField.font = UIFont(name: "AvenirNextCondensed-UltraLight", size: 15)
        codeTextField.titleFont = UIFont(name: "AvenirNextCondensed-UltraLight", size: 10)
        codeTextField.placeholder = "Activation Code"
        codeTextField.textColor = color
        codeTextField.tintColor = color
        codeTextField.lineColor = color
        codeTextField.placeholderColor = color
        codeTextField.selectedLineColor = color
        codeTextField.selectedTitleColor = color


    }
    
    /* create an object function for the cancel and done button in the number pad tool bar */
    @objc func cancel_numberPad(){
        
        codeTextField.text = ""
        self.view.endEditing(true)
    }

    
    /* create an object function for the cancel and done button in the number pad tool bar */
    @objc func done_numberPad(){
        self.view.endEditing(true)
        performSegue(withIdentifier: "222", sender: nil)

    }

    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        codeTextField.resignFirstResponder()
        
        performSegue(withIdentifier: "222", sender: nil)

        
        return true
    }



    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
