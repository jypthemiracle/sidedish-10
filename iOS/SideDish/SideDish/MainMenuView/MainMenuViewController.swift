//
//  MainMenuViewController.swift
//  SideDish
//
//  Created by 신한섭 on 2020/04/21.
//  Copyright © 2020 신한섭. All rights reserved.
//

import UIKit
import Toaster

class MainMenuViewController: UIViewController {
    
    @IBOutlet weak var mainMenuTableView: UITableView!
    
    private var mainMenuDataSource =  MainMenuViewDataSource()
    
    let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        popUpLoginView()
        setupTableView()
        setupObserver()
        setupDataSource()
    }
    
    private func setupDataSource() {
        mainMenuDataSource.handler = { cell, urlString in
            guard let requestURL = URL(string: urlString) else {
                self.errorHandling(error: .InvalidURL)
                return
            }
            let imageURL = self.localFilePath(for: requestURL)
            
            if FileManager.default.fileExists(atPath: imageURL.path) {
                self.setImage(into: cell, from: imageURL)
            } else {
                ImageUseCase.loadImage(with: NetworkManager(), from: requestURL, failureHandler: {self.errorHandling(error: $0)}) { resultURL in
                    self.setImage(into: cell, from: resultURL)
                    try? FileManager.default.moveItem(at: resultURL, to: imageURL)
                }
            }
        }
    }
    
    private func setImage(into cell: MainMenuTableViewCell, from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            DispatchQueue.main.async {
                cell.setImageFromData(data: data)
            }
        } catch {
            self.errorHandling(error: .DecodeError)
        }
    }
    
    private func localFilePath(for url: URL) -> URL {
        return cachesDirectory.appendingPathComponent(url.lastPathComponent)
    }
    
    private func popUpLoginView() {
        guard let loginViewController = self.storyboard?.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController else {return}
        present(loginViewController, animated: true)
    }
    
    private func setupObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadSection(_:)),
                                               name: .ModelInserted,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(loadData),
                                               name: .LoginSuccess,
                                               object: nil)
    }
    
    private func setupTableView() {
        mainMenuTableView.delegate = self
        mainMenuTableView.register(MainMenuHeader.self, forHeaderFooterViewReuseIdentifier: "MenuHeaderView")
        mainMenuTableView.dataSource = mainMenuDataSource
    }
    
    private func configureUseCase() {
        SideDishUseCase.loadMainDish(with: NetworkManager(), failureHandler: {self.errorHandling(error: $0)}) {model, index in
            DispatchQueue.main.async {
                self.mainMenuDataSource.sideDishManager.insert(into: index, rows: model)
            }
        }
        
        SideDishUseCase.loadSideDish(with: NetworkManager(), failureHandler: {self.errorHandling(error: $0)}) {model, index in
            DispatchQueue.main.async {
                self.mainMenuDataSource.sideDishManager.insert(into: index, rows: model)
            }
        }
        
        SideDishUseCase.loadSoupDish(with: NetworkManager(), failureHandler: {self.errorHandling(error: $0)}) {model, index in
            DispatchQueue.main.async {
                self.mainMenuDataSource.sideDishManager.insert(into: index, rows: model)
            }
        }
    }
    
    private func alertError(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "문제가 생겼어요", message: message, preferredStyle: .alert)
            let ok = UIAlertAction(title: "넵...", style: .default)
            alert.addAction(ok)
            self.present(alert, animated: true)
        }
    }
    
    private func errorHandling(error: NetworkManager.NetworkError) {
        alertError(message: error.message())
    }
    
    @objc func reloadSection(_ notification: Notification) {
        guard let index = notification.userInfo?["index"] as? Int else {return}
        mainMenuTableView.reloadSections(IndexSet(index...index), with: .automatic)
    }
    
    @objc func loadData() {
        configureUseCase()
    }
}

extension MainMenuViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "MenuHeaderView") as? MainMenuHeader else {return UIView()}
        let sectionInfo = mainMenuDataSource.sideDishManager.sectionName(at: section)
        let contents = sectionInfo.components(separatedBy: "/")
        headerView.setTitleLabel(text: contents[0])
        headerView.setContentLabel(text: contents[1])
        headerView.index = section
        headerView.delegate = self
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dish = mainMenuDataSource.sideDishManager.sideDish(indexPath: indexPath)
        guard let detailViewController = self.storyboard?.instantiateViewController(withIdentifier: "DetailViewController") as? DetailViewController else {return}
        detailViewController.id = dish.id
        let text = "타이틀 메뉴 : \(dish.title)\n\(dish.specialPrice)"
        Toast(text: text).show()
        self.navigationController?.pushViewController(detailViewController, animated: true)
    }
}

extension Notification.Name {
    static let InjectionModel = Notification.Name("InjectionModel")
}

extension MainMenuViewController: SectionTapped {
    func sectionTapped(headerView: MainMenuHeader, at section: Int, title: String) {
        let numOfRows = mainMenuDataSource.sideDishManager.numOfRows(at: section)
        Toast(text: "\(title): \(numOfRows)개").show()
    }
}
