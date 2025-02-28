//
//  ContentView.swift
//  swift-soroban-passkey-demo
//
//  Created by Christian Rogobete on 21.02.25.
//

import SwiftUI
import SwiftPasskeyKit

struct ContentView: View {
    
    @State private var user:User? = nil
    private var passkeyKit:PasskeyKit?
    
    var body: some View {
        VStack {
            if let user = user {
                WalletView(user: user, logoutUser: logoutUser)
            } else {
                AuthView(userLoggedIn: userLoggedIn(_:))
            }
        }
        .padding()
    }
    
    public func userLoggedIn(_ user:User) -> Void {
        self.user = user
    }
    
    public func logoutUser() -> Void {
        self.user = nil
    }
    
}

#Preview {
    ContentView()
}
