//
//  User.swift
//  swift-soroban-passkey-demo
//
//  Created by Christian Rogobete on 24.02.25.
//

import Foundation
import SwiftPasskeyKit

public class User {
    
    public let keyId:Data
    public let contractId:String
    public let passkeyKit:PasskeyKit
    
    internal init(keyId: Data, contractId: String, passkeyKit:PasskeyKit) {
        self.keyId = keyId
        self.contractId = contractId
        self.passkeyKit = passkeyKit
    }
}
