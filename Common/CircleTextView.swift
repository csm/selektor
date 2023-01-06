//
//  CircleTextView.swift
//  Selektor
//
//  Created by Casey Marshall on 12/20/22.
//

import UIKit

class CircleTextView: UIView {
    let text: String
    let font: UIFont
    
    init(text: String, font: UIFont = UIFont.systemFont(ofSize: 14)) {
        self.text = text
        self.font = font
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /*override func draw(_ rect: CGRect) {
        
    }*/
}
