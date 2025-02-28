//
//  AuthView.swift
//  swift-soroban-passkey-demo
//
//  Created by Christian Rogobete on 24.02.25.
//

import SwiftUI
import AuthenticationServices
import stellarsdk
import SwiftPasskeyKit

struct AuthView: View {
    
    private let userLoggedIn:((_ user:User) -> Void)
    
    internal init(userLoggedIn: @escaping ((User) -> Void)) {
        self.userLoggedIn = userLoggedIn
    }
    
    @State private var username = ""
    @State private var infoText:String = ""
    @State private var infoColor:Color = .blue
    
    // Get an instance of AuthorizationController using SwiftUI's @Environment
    // property wrapper.
    @Environment(\.authorizationController) private var authorizationController
    
    var body: some View {
        VStack {
            Text("Soroban Passkey Demo").bold().font(.title).padding(EdgeInsets(top: 0, leading: 0, bottom: 50, trailing: 0)).foregroundColor(.blue)
            
            TextField("Username", text: $username).textFieldStyle(.roundedBorder).padding().onSubmit {
                Task {
                    await createWallet()
                }
            }
            
            Text("Provide a username and press enter to create a new wallet!").italic().foregroundColor(.blue).padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
            
            LabelledDivider(label: "or")
            
            Text("Allready have a wallet?").italic().foregroundColor(.blue)
            
            Button("Connect Wallet", action:   {
                Task {
                    await connectWallet()
                }
            }).buttonStyle(.borderedProminent).tint(.green).padding(EdgeInsets(top: 20, leading: 0, bottom: 50, trailing: 0))
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    Text(infoText).foregroundColor(infoColor)
                }
                .padding()
            }
        }
        .padding()
    }
    
    private func createCredentials(_ userName:String, _ userId:Data, _ challenge:Data, _ rpId:String) async throws -> PasskeyCredentialResponse {
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: userName, userID: userId)
        let result = try await authorizationController.performRequest(registrationRequest)
        switch result {
        case .passkeyRegistration(let credentialRegistration):
            guard let rawAttestationObject =  credentialRegistration.rawAttestationObject else {
                throw DemoError.runtimeError("rawAttestationObject missing")
            }
            return PasskeyCredentialResponse(credentialID: credentialRegistration.credentialID, rawAttestationObject: rawAttestationObject)
        default:
            throw DemoError.runtimeError("unexpected authorizationController response")
        }
        
    }
    
    private func createWallet() async -> Void {
        showInfo(info: "creating wallet ...")
        let passkeyKit = PasskeyKit(rpId: Constants.rpId,
                                    rpcUrl: Constants.rpcUrl,
                                    wasmHash: Constants.walletWasmHash,
                                    network: Constants.network)
        do{
            let createWalletResponse = try await passkeyKit.createWallet(userName: username,
                                                                         createCredentials: createCredentials)
            
            try await StellarService.feeBumpCreateWallet(innerTx: createWalletResponse.transaction)
            let connectWalletResponse = try await passkeyKit.connectWallet(keyId: createWalletResponse.keyId)
            let user = User(keyId: connectWalletResponse.keyId, contractId:connectWalletResponse.contractId, passkeyKit: passkeyKit)
            userLoggedIn(user)
        } catch {
            showError(err: error.localizedDescription)
        }
    }
    
    private func connectWallet() async -> Void {
        showInfo(info: "connecting wallet ...")
        let passkeyKit = PasskeyKit(rpId: Constants.rpId,
                                    rpcUrl: Constants.rpcUrl,
                                    wasmHash: Constants.walletWasmHash,
                                    network: Constants.network)
        do{
            let connectWalletResponse = try await passkeyKit.connectWallet(keyId: nil, passkeySignIn: passkeySignIn)
            let user = User(keyId: connectWalletResponse.keyId, contractId:connectWalletResponse.contractId, passkeyKit: passkeyKit)
            userLoggedIn(user)
        } catch {
            showError(err: error.localizedDescription)
        }
    }
    
    private func passkeySignIn(_ challenge:Data, _ rpId:String) async throws -> Data {
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let registrationRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)
        let result = try await authorizationController.performRequest(registrationRequest)
    
        switch result {
        case .passkeyAssertion(let credentialAssertion):
            return credentialAssertion.credentialID
        default:
            throw DemoError.runtimeError("unexpected authorizationController response")
        }
        
    }
    
    
    private func showInfo(info:String) {
        infoText = info
        infoColor = .blue
    }
    
    private func showError(err:String) {
        infoText = err
        infoColor = .red
    }
    
}

struct LabelledDivider: View {

    let label: String
    let horizontalPadding: CGFloat
    let color: Color

    init(label: String, horizontalPadding: CGFloat = 20, color: Color = .gray) {
        self.label = label
        self.horizontalPadding = horizontalPadding
        self.color = color
    }

    var body: some View {
        HStack {
            line
            Text(label).foregroundColor(color)
            line
        }
    }

    var line: some View {
        VStack { Divider().background(color) }.padding(horizontalPadding)
    }
}

public func userLoggedInPreview(_ user:User) -> Void {}

#Preview {
    AuthView(userLoggedIn:userLoggedInPreview)
}
