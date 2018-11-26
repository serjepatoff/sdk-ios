//
//  Copyright: Ambrosus Technologies GmbH
//  Email: tech@ambrosus.com
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
// (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import UIKit
import AmbrosusSDK
import AVFoundation

final class ScanDataFormatter {
    func translateSymbology(from avFoundationRepresentation: String) -> String {
        return avFoundationRepresentation.components(separatedBy: ".").last?.lowercased().replacingOccurrences(of: "-", with: "")  ?? "unknown"
    }

    func getFormattedString(for barcodeStr: String?, symbology: String ) -> String {
        var dataLower = (barcodeStr ?? "").lowercased()
        
        switch symbology {
        case "qrcode":
            let baseURL = "amb.to"
            let replacementStrings = ["http://" + baseURL + "/",
                                      "https://" + baseURL + "/"]
            var formattedData: String = ""
            for replacementString in replacementStrings {
                formattedData = dataLower.replacingOccurrences(of: replacementString, with: "")

                // Make sure the strings "http://amb.to/" or "https://amb.to/" were found to send back the ambrosus id
                if formattedData != dataLower {
                    return formattedData
                }
            }
            return symbology + ":" + dataLower
            
        case "datamatrix":
            let mappingStrings: [String: String] = ["(01)": "[identifiers.gtin]=", "(21)": "&[identifiers.sn]=", "(10)": "&[identifiers.batch]=", "(17)": "&[identifiers.expiry]="]

            for key in mappingStrings.keys {
                if let value = mappingStrings[key] {
                    dataLower = dataLower.replacingOccurrences(of: key, with: value)
                }
            }
            return dataLower
            
        default:
            let queryString = "[identifiers." + symbology + "]=" + dataLower
            return queryString
        }
    }
}

final class ScanViewController: UIViewController {
    
    fileprivate let didShowInstructionsKey = "didShowInstructions"
    
    private lazy var qrReaderVC: QRCodeReaderViewController = {
        let builder = QRCodeReaderViewControllerBuilder {
            let codeTypes : [AVMetadataObject.ObjectType] = [.qr, .dataMatrix, .ean13, .ean8,
                                                             .upce, .code39, .code39Mod43, .code93,
                                                             .code128, .pdf417, .aztec, .interleaved2of5,
                                                             .itf14]
            
            $0.reader                  = QRCodeReader(metadataObjectTypes: codeTypes, captureDevicePosition: .back)
            $0.showTorchButton         = true
            $0.showSwitchCameraButton  = false
            $0.showCancelButton        = false
            $0.preferredStatusBarStyle = .default
            $0.reader.stopScanningWhenCodeIsFound = false
        }
        
        return QRCodeReaderViewController(builder: builder)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        tabBarController?.tabBar.centerItems()
        let leftBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "information"), style: .plain, target: self, action: #selector(tappedHelp))
        navigationController?.navigationBar.topItem?.leftBarButtonItem = leftBarButtonItem
        setupScanner()
        showInstructionsOnFirstLaunch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setNeedsStatusBarAppearanceUpdate()
        navigationController?.navigationBar.topItem?.title = "Scan"
        qrReaderVC.startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qrReaderVC.stopScanning()
    }
    
    @objc func tappedHelp() {
        displayInstructions()
    }
    
    private func displayInstructions() {
        UserDefaults.standard.set(true, forKey: didShowInstructionsKey)

        let presentingViewController = UIApplication.shared.keyWindow?.rootViewController
        let samplesURLString = "https://github.com/ambrosus/sdk-ios"
        let alert = UIAlertController(title: "Instructions",
                                      message: """
            Ambrosus Viewer is capable of scanning Bar Codes, QR Codes, and Datamatrix codes. Codes with Ambrosus identifiers will display details about an asset on the AMB-Net.
            
            For a set of sample of codes you can scan visit:
            
            \(samplesURLString)
            
            We recommend opening this link on a separate computer so you can scan codes with this device.
            
            To see samples already included with the app select the browse tab (folder icon in the bottom right).
            """,
            preferredStyle: .alert)
        
        let actionCopy = UIAlertAction(title: "Copy URL", style: .default) { _ in
            UIPasteboard.general.string = samplesURLString
            let alert = UIAlertController(title: "Copied",
                                          message: """
                URL to website with sample codes to scan:
                \(samplesURLString)
                was copied successfully!
                """,
                preferredStyle: .alert)
            let actionClose = UIAlertAction(title: "Close", style: .cancel) { _ in
            }
            alert.addAction(actionClose)
            presentingViewController?.present(alert, animated: true, completion: nil)
        }
        
        let actionClose = UIAlertAction(title: "Close", style: .cancel) { _ in
        }
        
        alert.addAction(actionCopy)
        alert.addAction(actionClose)
        presentingViewController?.present(alert, animated: true, completion: nil)
    }
    
    /// If the user has never seen the instructions before display them
    private func showInstructionsOnFirstLaunch() {
        let didShowInstructionsOnFirstLaunch = UserDefaults.standard.bool(forKey: didShowInstructionsKey)
        if !didShowInstructionsOnFirstLaunch {
            displayInstructions()
        }
    }

    private func setupScanner() {
        addChildViewController(qrReaderVC)
        view.addSubview(qrReaderVC.view)
        qrReaderVC.didMove(toParentViewController: self)
        qrReaderVC.delegate = self
    }

    private func presentAssetViewController(with asset: AMBAsset) {
        guard let assetDetailCollectionViewController = Interface.mainStoryboard.instantiateViewController(withIdentifier: String(describing: AssetDetailCollectionViewController.self)) as? AssetDetailCollectionViewController else {
            return
        }

        assetDetailCollectionViewController.asset = asset
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(assetDetailCollectionViewController, animated: true)
        }
    }
}

extension ScanViewController: QRCodeReaderViewControllerDelegate {
    func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        reader.stopScanning()
        let value = result.value
        let symbologyAVF = result.metadataType
        
        DispatchQueue.main.async {
            self.processIncomingBarcode(with: reader, value: value, symbologyAVF: symbologyAVF)
        }
    }
    
    func readerDidCancel(_ reader: QRCodeReaderViewController) {
        reader.stopScanning()
    }
    
    private func presentAssetScanFailureAlert(with reader: QRCodeReaderViewController, symbology: String, query: String) {
        let alert = UIAlertController(title: "Scanned \(symbology) code",
            message: "Failed to find Ambrosus Asset from request with query: " + query,
            preferredStyle: .alert)
        
        let action = UIAlertAction(title: "OK", style: .default) { _ in
            reader.startScanning()
        }
        
        alert.addAction(action)
        
        DispatchQueue.main.async {
            reader.stopScanning()
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func processIncomingBarcode(with picker: QRCodeReaderViewController, value: String, symbologyAVF: String) {
        let scanDataFormatter = ScanDataFormatter()
        let symbologyShort = scanDataFormatter.translateSymbology(from: symbologyAVF)
        let query = scanDataFormatter.getFormattedString(for: value, symbology: symbologyShort)
        
        guard !value.isEmpty else {
            presentAssetScanFailureAlert(with: picker, symbology: symbologyAVF, query: query)
            return
        }

        // If there is no symbology string the query is an id
        if symbologyShort == "qrcode" && !query.contains(symbologyShort) {

            AMBNetwork.sharedInstance.requestAsset(fromId: query, completion: { (asset) in
                guard let asset = asset else {
                    self.presentAssetScanFailureAlert(with: picker, symbology: symbologyAVF, query: query)
                    return
                }
                AMBDataStore.sharedInstance.assetStore.insert(asset)
                self.presentAssetViewController(with: asset)
                return
            })
        } else {
            AMBNetwork.sharedInstance.requestEvents(fromQuery: query, completion: { (events) in
                guard let events = events,
                    let assetId = events.first?.assetId else {
                        self.presentAssetScanFailureAlert(with: picker, symbology: symbologyAVF, query: query)
                        return
                }
                AMBDataStore.sharedInstance.eventStore.insert(events)
                AMBNetwork.sharedInstance.requestAsset(fromId: assetId, completion: { (asset) in
                    guard let asset = asset else {
                        self.presentAssetScanFailureAlert(with: picker, symbology: symbologyAVF, query: query)
                        return
                    }
                    AMBDataStore.sharedInstance.assetStore.insert(asset)
                    self.presentAssetViewController(with: asset)
                    return
                })
            })
        }
    }
}

