//
//  TableViewController.swift
//  sbhacks
//
//  Created by Hengyu Liu on 1/11/20.
//  Copyright © 2020 Hengyu Liu. All rights reserved.
//

import UIKit
import SafariServices
import Firebase
import AVFoundation
import CoreVideo
import Mapbox
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation

class TableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 3
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			let origin = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.9131752, longitude: -77.0324047), name: "Mapbox")
			let destination = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), name: "White House")
			let options = NavigationRouteOptions(waypoints: [origin, destination])
			Directions.shared.calculate(options) { (waypoints, routes, error) in
				guard let route = routes?.first else { return }
				let navigationService = MapboxNavigationService(route: route, simulating: .always)
				let navigationOptions = NavigationOptions(navigationService: navigationService)
				let viewController = NavigationViewController(for: route, options: navigationOptions)
				viewController.modalPresentationStyle = .fullScreen
				self.present(viewController, animated: true, completion: nil)
			}
		case 1:
			let url = URL(string: "https://www.dmv.ca.gov/portal/dmv/?1dmy&urile=wcm:path:/dmv_content_en/dmv/dl/driversafety/dsalcohol")!
			let safariController = SFSafariViewController(url: url)
			present(safariController, animated: true, completion: nil)
		case 2:
			let alertController = UIAlertController(title: "Failed", message: "You have to keep the safety cam on to drive safely.", preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
			present(alertController, animated: true, completion: nil)
		default:
			fatalError()
		}
	}
}
