//
//  StatusMenuController.swift
//  weatherbar
//
//  Created by Dan Hill on 10/10/17.
//  Copyright © 2017 Dan Hill. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject {
    let INSERTION_INDEX = 2

    @IBOutlet weak var statusMenu: NSMenu!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    let defaults: Defaults
    let phab: Phabricator
    var user: User? = nil
    var diffs: [Diff]? = nil

    @IBAction func refreshClicked(_ sender: Any) {
        refreshDiffs()
    }

    @IBAction func quitClicked(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }

    override init() {
        self.defaults = Defaults()

        // TODO: prompt user for url and api token if not set
        let phabUrl = defaults.phabricatorUrl ?? Constants.PHABRICATOR_URL
        let apiToken = defaults.apiToken ?? Constants.API_TOKEN
        self.phab = Phabricator(phabricatorUrl: phabUrl, apiToken: apiToken)
        
        super.init()
    }

    override func awakeFromNib() {
        let icon = NSImage(named: NSImage.Name(rawValue: "knife"))
        icon?.isTemplate = true
        statusItem.image = icon
        statusItem.menu = statusMenu
        
        ensureUser()
        refreshDiffs()
    }
    
    private func ensureUser() {
        phab.fetchUser() { response in
            self.user = response.result
            self.refreshUi(user: self.user, diffs: self.diffs ?? [])
        }
    }

    private func refreshDiffs() {
        phab.fetchActiveDiffs() { response in
            self.diffs = response.result.data
            self.refreshUi(user: self.user, diffs: response.result.data)

            // TODO: have time be configurable
            let seconds = self.defaults.refreshInterval ?? 60
            let deadlineTime = DispatchTime.now() + .seconds(seconds)
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                self.refreshDiffs()
            }
        }
    }

    private func refreshUi(user: User?, diffs: [Diff]) {
        // update title on main thread
        DispatchQueue.main.async(execute: {
            self.statusItem.title = "\(diffs.count)"
        })
        
        print("Fetched \(diffs.count) active diffs for \(user?.realName ?? "unknown")")
        
        // clear out last update's menu items
        while (statusMenu.items.count > INSERTION_INDEX + 1) {
            statusMenu.removeItem(at: INSERTION_INDEX)
        }
        
        
        // assemble by status
        var categories = [String: [Diff]]()
        for diff in diffs {
            let status = diff.fields.status.value
            if categories[status] == nil {
                categories[status] = [Diff]()
            }
            categories[status]?.append(diff)
        }
        
        // insert new ones
        for (_, diffs) in categories {
            let title = diffs[0].fields.status.name
            let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            insertMenuItem(menuItem: header)

            for diff in diffs {
                let row = NSMenuItem(title: diff.fields.title, action: #selector(launchUrl), keyEquivalent: "")
                row.target = self
                row.representedObject = diff
                insertMenuItem(menuItem: row)
            }
            insertMenuItem(menuItem: NSMenuItem.separator())
        }
    }
    
    @objc private func launchUrl(_ menuItem: NSMenuItem) {
        let diff = menuItem.representedObject as! Diff
        let urlString = "https://phabricator.robinhood.com/D\(diff.id)"
        let url = URL(string: urlString)
        NSWorkspace.shared.open(url!)
    }
    
    private func insertMenuItem(menuItem: NSMenuItem) {
        statusMenu.insertItem(menuItem, at: statusMenu.items.count - 1)
    }
}
