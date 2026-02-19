//
//  ViewController.swift
//  LimelinkIOSSDK
//
//  Created by hellovelope@gmail.com on 05/10/2024.
//  Copyright (c) 2024 hellovelope@gmail.com. All rights reserved.
//

import UIKit
import LimelinkIOSSDK

public class ViewController: UIViewController, LimeLinkListener {

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "LimeLink SDK Example"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 24)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let resultLabel: UILabel = {
        let label = UILabel()
        label.text = "Waiting for deep link..."
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .gray
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Listener 등록
        LimeLinkSDK.shared.addLinkListener(self)

        // Stats 추적
        let url = URL(string: "https://www.example.com/test/product/value")
        LimeLinkSDK.shared.trackLinkStatus(url: url)

        setupUI()
    }

    private func setupUI() {
        view.addSubview(statusLabel)
        view.addSubview(resultLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),

            resultLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - LimeLinkListener

    public func onDeeplinkReceived(result: LimeLinkResult) {
        let deferred = result.isDeferred ? " (Deferred)" : ""
        resultLabel.text = "URI: \(result.resolvedUri ?? "nil")\(deferred)"
        resultLabel.textColor = .systemGreen
        print("[Example] Deep link received: \(result.resolvedUri ?? "nil")")
    }

    public func onDeeplinkError(error: LimeLinkError) {
        resultLabel.text = "Error [\(error.code)]: \(error.message)"
        resultLabel.textColor = .systemRed
        print("[Example] Deep link error: \(error.message)")
    }
}
