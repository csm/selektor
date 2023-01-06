//
//  ConfigListViewController.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/5/23.
//

import AppKit

class ConfigListViewController: NSViewController {
    @IBOutlet
    weak var arrayController: NSArrayController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        arrayController.managedObjectContext = PersistenceController.shared.container.viewContext
        arrayController.sortDescriptors = [NSSortDescriptor(keyPath: \Config.index, ascending: true)]
    }
}
