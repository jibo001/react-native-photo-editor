//
//  PhotoEditor.swift
//  PhotoEditor
//
//  Created by Donquijote on 27/07/2021.
//

import Foundation
import UIKit
import Photos
import SDWebImage
import AVFoundation
//import ZLImageEditor

public enum ImageLoad: Error {
    case failedToLoadImage(String)
}

@objc(PhotoEditor)
class PhotoEditor: NSObject {
    var window: UIWindow?
    var bridge: RCTBridge!

    var resolve: RCTPromiseResolveBlock!
    var reject: RCTPromiseRejectBlock!

    @objc(open:withResolver:withRejecter:)
    func open(options: NSDictionary, resolve:@escaping RCTPromiseResolveBlock,reject:@escaping RCTPromiseRejectBlock) -> Void {

        // handle path
        guard let path = options["path"] as? String else {
            reject("DONT_FIND_IMAGE", "Dont find image", nil)
            return;
        }

        getUIImage(url: path) { image in
            DispatchQueue.main.async {
                //  set config
                self.setConfiguration(options: options, resolve: resolve, reject: reject)
                self.presentController(image: image)
            }
        } reject: {_ in
            reject("LOAD_IMAGE_FAILED", "Load image failed: " + path, nil)
        }
    }

    func onCancel() {
        self.reject("USER_CANCELLED", "User has cancelled", nil)
    }

    private func setConfiguration(options: NSDictionary, resolve:@escaping RCTPromiseResolveBlock,reject:@escaping RCTPromiseRejectBlock) -> Void{
        self.resolve = resolve;
        self.reject = reject;

        // 配置编辑工具
        let config = ZLImageEditorConfiguration.default()

        // 确保tools数组中包含所需工具
        if !config.tools.contains(.draw) {
            config.tools.append(.draw)
        }
        if !config.tools.contains(.clip) {
            config.tools.append(.clip)
        }
        if !config.tools.contains(.filter) {
            config.tools.append(.filter)
        }
        if !config.tools.contains(.textSticker) {
            config.tools.append(.textSticker)
        }

        // 设置UI配置
        let uiConfig = ZLImageEditorUIConfiguration.default()
        uiConfig.editDoneBtnBgColor = UIColor.white
        uiConfig.editDoneBtnTitleColor = UIColor.black

        // 我们使用ZLImageEditor内置的滤镜，而不是尝试加载自定义滤镜
        // 这样可以避免类型转换问题
    }

    private func presentController(image: UIImage) {
        if let controller = UIApplication.getTopViewController() {
            controller.modalTransitionStyle = .crossDissolve

            ZLEditImageViewController.showEditImageVC(parentVC: controller, image: image) { [weak self] (resImage, editModel) in
                guard let self = self else { return }

                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String

                let destinationPath = URL(fileURLWithPath: documentsPath).appendingPathComponent(String(Int64(Date().timeIntervalSince1970 * 1000)) + ".png")

                do {
                    try resImage.pngData()?.write(to: destinationPath)
                    self.resolve(destinationPath.absoluteString)
                } catch {
                    debugPrint("writing file error", error)
                    self.reject("SAVE_ERROR", "Failed to save edited image", error)
                }
            }
        }
    }


    private func getUIImage (url: String ,completion:@escaping (UIImage) -> (), reject:@escaping(String)->()){
        if let path = URL(string: url) {
            SDWebImageManager.shared.loadImage(with: path, options: .continueInBackground, progress: { (recieved, expected, nil) in
            }, completed: { (downloadedImage, data, error, SDImageCacheType, true, imageUrlString) in
                DispatchQueue.main.async {
                    if(error != nil){
                        print("error", error as Any)
                        reject("false")
                        return;
                    }
                    if downloadedImage != nil{
                        completion(downloadedImage!)
                    }
                }
            })
        }else{
            reject("false")
        }
    }

}

extension UIApplication {
    class func getTopViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {

        if let nav = base as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController)
        } else if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return getTopViewController(base: selected)
        } else if let presented = base?.presentedViewController {
            return getTopViewController(base: presented)
        }

        return base
    }
}
