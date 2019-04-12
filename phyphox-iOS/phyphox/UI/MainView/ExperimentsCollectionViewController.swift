//
//  ExperimentsCollectionViewController.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit
import ZipZap

private let minCellWidth: CGFloat = 320.0


protocol ExperimentController {
    func launchExperimentByURL(_ url: URL) -> Bool
    func addExperimentsToCollection(_ list: [Experiment])
}

final class ExperimentsCollectionViewController: CollectionViewController, ExperimentController {
    private var cellsPerRow: Int = 1
    private var infoButton: UIButton? = nil
    private var addButton: UIBarButtonItem? = nil
    
    private var collections: [ExperimentCollection] = []

    override class var viewClass: CollectionContainerView.Type {
        return MainView.self
    }
    
    override class var customCells: [String : UICollectionViewCell.Type]? {
        return ["ExperimentCell" : ExperimentCell.self]
    }
    
    override class var customHeaders: [String : UICollectionReusableView.Type]? {
        return ["Header" : ExperimentHeaderView.self]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.barTintColor = kBackgroundColor
        self.navigationController?.navigationBar.isTranslucent = true
    }
    
    @objc func showHelpMenu(_ item: UIBarButtonItem) {
        let alert = UIAlertController(title: NSLocalizedString("help", comment: ""), message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("credits", comment: ""), style: .default, handler: infoPressed))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("experimentsPhyphoxOrg", comment: ""), style: .default, handler:{ _ in
            UIApplication.shared.openURL(URL(string: NSLocalizedString("experimentsPhyphoxOrgURL", comment: ""))!)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("faqPhyphoxOrg", comment: ""), style: .default, handler:{ _ in
            UIApplication.shared.openURL(URL(string: NSLocalizedString("faqPhyphoxOrgURL", comment: ""))!)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("remotePhyphoxOrg", comment: ""), style: .default, handler:{ _ in
            UIApplication.shared.openURL(URL(string: NSLocalizedString("remotePhyphoxOrgURL", comment: ""))!)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("translationInfo", comment: ""), style: .default, handler:{ _ in
            let al = UIAlertController(title: NSLocalizedString("translationInfo", comment: ""), message: NSLocalizedString("translationText", comment: ""), preferredStyle: .alert)
            
            al.addAction(UIAlertAction(title: NSLocalizedString("translationToWebsite", comment: ""), style: .default, handler: { _ in
                UIApplication.shared.openURL(URL(string: NSLocalizedString("translationToWebsiteURL", comment: ""))!)
            }))
            
            al.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            
            self.navigationController!.present(al, animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = infoButton!
            popover.sourceRect = infoButton!.frame
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "phyphox"

        reload()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: NSNotification.Name(rawValue: ExperimentsReloadedNotification), object: nil)

        infoButton = UIButton(type: .infoDark)
        infoButton!.addTarget(self, action: #selector(showHelpMenu(_:)), for: .touchUpInside)
        infoButton!.sizeToFit()
        
        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addExperiment))
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: infoButton!)
        navigationItem.rightBarButtonItem = addButton!
        
        let defaults = UserDefaults.standard
        let key = "donotshowagain"
        if (!defaults.bool(forKey: key)) {
            let alert = UIAlertController(title: NSLocalizedString("warning", comment: ""), message: NSLocalizedString("damageWarning", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("donotshowagain", comment: ""), style: .default, handler: { _ in
                defaults.set(true, forKey: key)
            }))
        
            alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
        
            navigationController!.present(alert, animated: true, completion: nil)
        }
    }
    
    private func showOpenSourceLicenses() {
        let alert = UIAlertController(title: "Open Source Licenses", message: PTFile.stringWithContentsOfFile(Bundle.main.path(forResource: "Licenses", ofType: "ptf")!), preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("close", comment: ""), style: .cancel, handler: nil))
        
        navigationController!.present(alert, animated: true, completion: nil)
    }
    
    func infoPressed(_ action: UIAlertAction) {
        let vc = UIViewController()
        vc.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        vc.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        
        let v = CreditsView()
        v.onCloseCallback = {
            vc.dismiss(animated: true, completion: nil)
        }
        v.onLicenceCallback = {
            vc.dismiss(animated: true, completion: nil)
            self.showOpenSourceLicenses()
        }
        vc.view = v
        
        navigationController!.present(vc, animated: true, completion: nil)
    }

    @objc func reload() {
        collections = ExperimentManager.shared.experimentCollections
        selfView.collectionView.reloadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    let overlayTransitioningDelegate = CreateViewControllerTransitioningDelegate()
    
    @objc func addExperiment() {
        let alert = UIAlertController(title: NSLocalizedString("newExperiment", comment: ""), message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("newExperimentQR", comment: ""), style: .default, handler: launchScanner))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("newExperimentSimple", comment: ""), style: .default, handler: createSimpleExperiment))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = addButton!
        }
        
        present(alert, animated: true, completion: nil)
    }

    func launchScanner(_ action: UIAlertAction) {
        let vc = ScannerViewController()
        vc.experimentLauncher = self
        let nav = UINavigationController(rootViewController: vc)
        
        if iPad {
            nav.modalPresentationStyle = .formSheet
        }
        else {
            nav.transitioningDelegate = overlayTransitioningDelegate
            nav.modalPresentationStyle = .custom
        }
        
        navigationController!.parent!.present(nav, animated: true, completion: nil)
    }

    
    func createSimpleExperiment(_ action: UIAlertAction) {
        let vc = CreateExperimentViewController()
        let nav = UINavigationController(rootViewController: vc)
        
        if iPad {
            nav.modalPresentationStyle = .formSheet
        }
        else {
            nav.transitioningDelegate = overlayTransitioningDelegate
            nav.modalPresentationStyle = .custom
        }
        
        navigationController!.parent!.present(nav, animated: true, completion: nil)
    }
    
    //MARK: - UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return collections.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collections[section].experiments.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var cells: CGFloat = 1.0
        
        var width = self.view.frame.size.width
        
        while self.view.frame.size.width/(cells+1.0) >= minCellWidth {
            cells += 1.0
            width = self.view.frame.size.width/cells
        }
        
        cellsPerRow = Int(cells)
        
        let h = ceil(UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline).lineHeight + UIFont.preferredFont(forTextStyle: UIFontTextStyle.caption1).lineHeight + 12)
        
        return CGSize(width: width, height: h)
    }
    
    private func showDeleteConfirmationForExperiment(_ experiment: Experiment, button: UIButton) {
        let alert = UIAlertController(title: NSLocalizedString("confirmDeleteTitle", comment: ""), message: NSLocalizedString("confirmDelete", comment: ""), preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("delete", comment: "") + experiment.displayTitle, style: .destructive, handler: { [unowned self] action in
            do {
                try ExperimentManager.shared.deleteExperiment(experiment)
            }
            catch let error as NSError {
                let hud = JGProgressHUD(style: .dark)
                hud.interactionType = .blockTouchesOnHUDView
                hud.indicatorView = JGProgressHUDErrorIndicatorView()
                hud.textLabel.text = "Failed to delete experiment: \(error.localizedDescription)"
                
                hud.show(in: self.view)
                
                hud.dismiss(afterDelay: 3.0)
            }
            }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.navigationController!.view
            popover.sourceRect = button.convert(button.bounds, to: self.navigationController!.view)
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    private func showOptionsForExperiment(_ experiment: Experiment, button: UIButton) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("delete", comment: ""), style: .destructive, handler: { [unowned self] action in
            self.showDeleteConfirmationForExperiment(experiment, button: button)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.navigationController!.view
            popover.sourceRect = button.convert(button.bounds, to: self.navigationController!.view)
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ExperimentCell", for: indexPath) as! ExperimentCell
        
        let collection = collections[indexPath.section]
        let experiment = collection.experiments[indexPath.row]
        
        cell.experiment = experiment.experiment
        
        if experiment.custom {
            cell.showsOptionsButton = true
            let exp = experiment.experiment
            cell.optionsButtonCallback = { [unowned exp, unowned self] button in
                self.showOptionsForExperiment(exp, button: button)
            }
        }
        else {
            cell.showsOptionsButton = false
            cell.optionsButtonCallback = nil
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: self.view.frame.size.width, height: 36.0)
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! ExperimentHeaderView

            let collection = collections[indexPath.section]

            view.title = collection.title
            var colorsInCollection = [UIColor : (Int, UIColor)]()
            for experiment in collection.experiments {
                if let count = colorsInCollection[experiment.experiment.color]?.0 {
                    colorsInCollection[experiment.experiment.color]!.0 = count + 1
                } else {
                    colorsInCollection[experiment.experiment.color] = (1, experiment.experiment.fontColor)
                }
            }
            var max = 0
            var catColor = kHighlightColor
            var catFontColor = UIColor.white
            for (color, (count, fontColor)) in colorsInCollection {
                if count > max {
                    max = count
                    catColor = color
                    catFontColor = fontColor
                }
            }
            view.color = catColor
            view.fontColor = catFontColor

            return view
        }

        fatalError("Invalid supplementary view: \(kind)")
    }
    
    //MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let experiment = collections[indexPath.section].experiments[indexPath.row]

        if experiment.experiment.appleBan {
            let controller = UIAlertController(title: NSLocalizedString("warning", comment: ""), message: NSLocalizedString("apple_ban", comment: ""), preferredStyle: .alert)
            
            /* Apple does not want us to reveal to the user that the experiment has been deactivated by their request. So we may not even show an info button...
             controller.addAction(UIAlertAction(title: NSLocalizedString("appleBanWarningMoreInfo", comment: ""), style: .default, handler:{ _ in
             UIApplication.shared.openURL(URL(string: NSLocalizedString("appleBanWarningMoreInfoURL", comment: ""))!)
             }))
             */

            controller.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .cancel, handler:nil))
            
            present(controller, animated: true, completion: nil)
            
            return
        }
        
        for sensor in experiment.experiment.sensorInputs {
            do {
                try sensor.verifySensorAvailibility()
            }
            catch SensorError.sensorUnavailable(let type) {
                let controller = UIAlertController(title: NSLocalizedString("sensorNotAvailableWarningTitle", comment: ""), message: NSLocalizedString("sensorNotAvailableWarningText1", comment: "") + " \(type) " + NSLocalizedString("sensorNotAvailableWarningText2", comment: ""), preferredStyle: .alert)
                
                controller.addAction(UIAlertAction(title: NSLocalizedString("sensorNotAvailableWarningMoreInfo", comment: ""), style: .default, handler:{ _ in
                    UIApplication.shared.openURL(URL(string: NSLocalizedString("sensorNotAvailableWarningMoreInfoURL", comment: ""))!)
                }))
                controller.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .cancel, handler:nil))
                
                present(controller, animated: true, completion: nil)
                
                return
            }
            catch {}
        }

        let vc = ExperimentPageViewController(experiment: experiment.experiment)

        navigationController?.pushViewController(vc, animated: true)
    }
    
    enum FileType {
        case unknown
        case phyphox
        case zip
    }
    
    func detectFileType(data: Data) -> FileType {
        if data[0] == 0x50 && data[1] == 0x4b && data[2] == 0x03 && data[3] == 0x04 {
            //Look for ZIP signature
            return .zip
        }
        if data.range(of: "<phyphox".data(using: .utf8)!) != nil {
            //Naive method to roughly check if this is a phyphox file without actually parsing it.
            //A false positive will be caught be the parser, but we do not want to parse anything that is obviously not a phyphox file.
            return .phyphox
        }
        return .unknown
    }
    
    func handleZipFile(_ url: URL) throws {
        let tmp = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("temp")
        try? FileManager.default.removeItem(at: tmp)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: false, attributes: nil)
        
        let archive = try ZZArchive(url: url)
        var files: [URL] = []
        for entry in archive.entries {
            if (entry.fileMode & S_IFDIR) > 0 {
                continue
            }
            if entry.fileName.hasSuffix(".phyphox") {
                let fileName = tmp.appendingPathComponent(entry.fileName)
                try FileManager.default.createDirectory(at: fileName.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try entry.newData().write(to: fileName, options: .atomic)
                files.append(fileName)
            }
        }
        
        guard files.count > 0 else {
            throw SerializationError.genericError(message: "No phyphox file found in zip archive.")
        }
        
        if files.count == 1 {
            _ = launchExperimentByURL(files.first!)
        } else {
            var experiments: [URL] = []
            for file in files {
                experiments.append(file)
            }
            
            let dialog = ExperimentPickerDialogView(title: NSLocalizedString("open_zip_title", comment: ""), message: NSLocalizedString("open_zip_dialog_instructions", comment: ""), experiments: files, delegate: self)
            dialog.show(animated: true)
        }
    }
    
    func launchExperimentByURL(_ url: URL) -> Bool {

        var fileType = FileType.unknown
        var experiment: Experiment?
        var finalURL = url
        
        var experimentLoadingError: Error?
        
        let tmp = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("temp.phyphox")
        
        //TODO: Replace all instances of Data(contentsOf:...) with non-blocking requests
        if url.scheme == "phyphox" {
            //phyphox:// allow to retreive the experiment via https or http. Try both.
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.scheme = "https"
                do {
                    let data = try Data(contentsOf: components.url!)
                    fileType = detectFileType(data: data)
                    if fileType == .phyphox || fileType == .zip {
                        try data.write(to: tmp, options: .atomic)
                        finalURL = tmp
                    }
                } catch {
                }
                if fileType == .unknown {
                    components.scheme = "http"
                    do {
                        let data = try Data(contentsOf: components.url!)
                        fileType = detectFileType(data: data)
                        if fileType == .phyphox || fileType == .zip {
                            try data.write(to: tmp, options: .atomic)
                            finalURL = tmp
                        }
                    } catch let error {
                        experimentLoadingError = error
                    }
                }
            }
            else {
                experimentLoadingError = SerializationError.invalidFilePath
            }
        }
        else if url.scheme == "http" || url.scheme == "https" {
            //Specific http or https. We need to download it first as InputStream/XMLParser only handles URLs to local files properly. (See todo above)
            do {
                let data = try Data(contentsOf: url)
                fileType = detectFileType(data: data)
                if fileType == .phyphox {
                    try data.write(to: tmp, options: .atomic)
                    finalURL = tmp
                }
            } catch let error {
                experimentLoadingError = error
            }
        } else if url.isFileURL {
            //Local file
            do {
                let data = try Data(contentsOf: url)
                fileType = detectFileType(data: data)
                finalURL = url
            }
            catch let error {
                experimentLoadingError = error
            }
        } else {
            experimentLoadingError = SerializationError.invalidFilePath
        }
        
        if experimentLoadingError == nil {
            switch fileType {
            case .phyphox:
                    do {
                        experiment = try ExperimentSerialization.readExperimentFromURL(finalURL)
                    } catch let error {
                        experimentLoadingError = error
                    }
            case .zip:
                do {
                    try handleZipFile(finalURL)
                    return true
                } catch let error {
                    experimentLoadingError = error
                }
            case .unknown:
                experimentLoadingError = SerializationError.invalidExperimentFile(message: "Unkown file format.")
            }
        }
        
        if experimentLoadingError != nil {
            let message: String
            if let sError = experimentLoadingError as? SerializationError {
                switch sError {
                case .emptyData:
                    message = "Empty data."
                case .genericError(let emessage):
                    message = emessage
                case .invalidExperimentFile(let emessage):
                    message = "Invalid experiment file. \(emessage)"
                case .invalidFilePath:
                    message = "Invalid file path"
                case .newExperimentFileVersion(let phyphoxFormat, let fileFormat):
                    message = "New phyphox file format \(fileFormat) found. Your phyphox version supports up to \(phyphoxFormat) and might be outdated."
                case .writeFailed:
                    message = "Write failed."
                }
            } else {
                message = String(describing: experimentLoadingError!)
            }
            let controller = UIAlertController(title: "Experiment error", message: "Could not load experiment: \(message)", preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .cancel, handler:nil))
            navigationController?.present(controller, animated: true, completion: nil)
            return false
        }
        
        guard let loadedExperiment = experiment else { return false }
        
        if loadedExperiment.appleBan {
            let controller = UIAlertController(title: NSLocalizedString("warning", comment: ""), message: NSLocalizedString("apple_ban", comment: ""), preferredStyle: .alert)
            
            /* Apple does not want us to reveal to the user that the experiment has been deactivated by their request. So we may not even show an info button...
             controller.addAction(UIAlertAction(title: NSLocalizedString("appleBanWarningMoreInfo", comment: ""), style: .default, handler:{ _ in
             UIApplication.shared.openURL(URL(string: NSLocalizedString("appleBanWarningMoreInfoURL", comment: ""))!)
             }))
             */
            controller.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .cancel, handler:nil))
            
            navigationController?.present(controller, animated: true, completion: nil)
            
            return false
        }
        
        for sensor in loadedExperiment.sensorInputs {
            do {
                try sensor.verifySensorAvailibility()
            }
            catch SensorError.sensorUnavailable(let type) {
                let controller = UIAlertController(title: NSLocalizedString("sensorNotAvailableWarningTitle", comment: ""), message: NSLocalizedString("sensorNotAvailableWarningText1", comment: "") + " \(type) " + NSLocalizedString("sensorNotAvailableWarningText2", comment: ""), preferredStyle: .alert)
                
                controller.addAction(UIAlertAction(title: NSLocalizedString("sensorNotAvailableWarningMoreInfo", comment: ""), style: .default, handler:{ _ in
                    UIApplication.shared.openURL(URL(string: NSLocalizedString("sensorNotAvailableWarningMoreInfoURL", comment: ""))!)
                }))
                controller.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .cancel, handler:nil))
                navigationController?.present(controller, animated: true, completion: nil)
                return false
            }
            catch {}
        }
        
        let controller = ExperimentPageViewController(experiment: loadedExperiment)
        navigationController?.pushViewController(controller, animated: true)
        
        return true
    }
    
    func addExperimentsToCollection(_ list: [Experiment]) {
        for experiment in list {
            print("Copying \(experiment.localizedTitle)")
            do {
                try experiment.saveLocally(quiet: true, presenter: nil)
            } catch let error {
                print("Error for \(experiment.localizedTitle): \(error.localizedDescription)")
                let hud = JGProgressHUD(style: .dark)
                hud.indicatorView = JGProgressHUDErrorIndicatorView()
                hud.indicatorView?.tintColor = .white
                hud.textLabel.text = "Failed to copy experiment \(experiment.localizedTitle)"
                hud.detailTextLabel.text = error.localizedDescription
                
                (UIApplication.shared.keyWindow?.rootViewController?.view).map {
                    hud.show(in: $0)
                    hud.dismiss(afterDelay: 3.0)
                }
            }
        }
        ExperimentManager.shared.reloadUserExperiments()

        
    }
}