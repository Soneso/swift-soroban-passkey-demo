//
//  WalletView.swift
//  swift-soroban-passkey-demo
//
//  Created by Christian Rogobete on 24.02.25.
//

import SwiftUI
import stellarsdk
import SwiftPasskeyKit
import AuthenticationServices
import AlertToast

struct WalletView: View {
    
    public let user:User
    private let logoutUser:(() -> Void)
    
    internal init(user: User, logoutUser: @escaping (() -> Void)) {
        self.user = user
        self.logoutUser = logoutUser
    }
    
    // Get an instance of AuthorizationController using SwiftUI's @Environment
    // property wrapper.
    @Environment(\.authorizationController) private var authorizationController
    
    @State private var balance:String = ""
    @State private var loadingBalance:Bool = false
    @State private var balanceLoadingError:String?
    
    @State private var fundingWallet:Bool = false
    @State private var fundingWalletError:String?
    
    @State private var addingEd25519Signer:Bool = false
    @State private var addingEd25519SignerError:String?
    
    @State private var ed25519Transfering:Bool = false
    @State private var ed25519TransferingError:String?
    
    @State private var addingPolicy:Bool = false
    @State private var addingPolicyError:String?
    
    @State private var policyTransfering:Bool = false
    @State private var policyTransferingError:String?
    
    @State private var multisigTransfering:Bool = false
    @State private var multisigTransferingError:String?
    
    @State private var addingSecp256r1Signer:Bool = false
    @State private var addingSecp256r1SignerError:String?
    
    @State private var showToast = false
    @State private var toastMessage:String = ""
    
    @State private var signername = ""
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                closeButton
                Text("\(user.contractId)").font(.subheadline).foregroundStyle(.blue)
                divider
                balanceView
                divider
                addFundsView
                divider
                addEd255129SignerView
                ed255129TransferView
                divider
                addPolicyView
                policyTransferView
                divider
                multisigTransferView
                divider
                addSecp256r1SignerView
                divider
            }
            .padding()
            .toast(isPresenting: $showToast){
                // `.alert` is the default displayMode
                AlertToast(type: .regular, title: "\(toastMessage)")
                
                //Choose .hud to toast alert from the top of the screen
                //AlertToast(displayMode: .hud, type: .regular, title: "Message Sent!")
                
                //Choose .banner to slide/pop alert from the bottom of the screen
                //AlertToast(displayMode: .banner(.slide), type: .regular, title: "Message Sent!")
            }
        }.onAppear {
            Task {
                await loadBalance()
            }
        }
        
    }
    

    private func loadBalance() async -> Void{
        loadingBalance = true
        do {
            balance = String(try await StellarService.getBalance(contractId: user.contractId))
            balanceLoadingError = nil
        } catch {
            balance = ""
            balanceLoadingError = error.localizedDescription
        }
        loadingBalance = false
    }
    
    private func addFunds() async -> Void{
        fundingWallet = true
        do {
            try await StellarService.addFunds(contractId: user.contractId)
            fundingWalletError = nil
        } catch {
            fundingWalletError = error.localizedDescription
        }
        fundingWallet = false
    }
    
    private func addEd25519Signer() async -> Void{
        addingEd25519Signer = true
        do {
            let newSignerKp = try KeyPair(secretSeed: Constants.ed25519SignerSecret)
            let submitterKp = try KeyPair(secretSeed: Constants.submitterSeed)
            
            // You can restrict the signer by adding policy limits here.
            
            /*let limits = PasskeyAddressLimits(address: try SCAddressXDR(contractId: Constants.nativeSacCid),
                                              limits: [PolicyPasskeySignerKey(policyAddress: try SCAddressXDR(contractId: Constants.samplePolicyCid))])*/
            
            
            var tx = try await user.passkeyKit.addEd25519(txSourceAccountId: submitterKp.accountId,
                                                          newSignerAccountId: newSignerKp.accountId,
                                                          // limits: [limits],
                                                          storage: PasskeySignerStorage.temporary)
            
            
            let signatureExpirationLedger = try await StellarService.getLatestLedgerSequence() + 60
            try await user.passkeyKit.signTxAuthEntriesWithPasskey(tx: &tx, signWithPasskey: signWithPasskey, signatureExpirationLayer: signatureExpirationLedger)
            
            let _ = try await StellarService.simulateAndSendTx(tx: tx, signerKeypair: submitterKp)
            showInfo("Signer added")
            addingEd25519SignerError = nil
        } catch {
            addingEd25519SignerError = error.localizedDescription
        }
        addingEd25519Signer = false
    }
    
    private func ed25519Transfer() async -> Void{
        ed25519Transfering = true
        do {
            var tx = try await StellarService.buildTransferTx(contractId: user.contractId, lumens: 2) // this will be blocked by the policy if you add the limit to sthe signer, 1 xlm will be accepted
            let signerKp = try KeyPair(secretSeed: Constants.ed25519SignerSecret)
            let signatureExpirationLedger = try await StellarService.getLatestLedgerSequence() + 60
            
            try user.passkeyKit.signTxAuthEntriesWithKeyPair(tx: &tx,
                                                             signerKeyPair: signerKp,
                                                             signatureExpirationLayer: signatureExpirationLedger)
            
            let _ = try await StellarService.simulateAndSendTx(tx: tx)
            showInfo("Transfer success")
            ed25519TransferingError = nil
        } catch {
            ed25519TransferingError = error.localizedDescription
        }
        ed25519Transfering = false
    }
    
    private func addPolicy() async -> Void{
        addingPolicy = true
        do {
            let signerKp = try KeyPair(secretSeed: Constants.ed25519SignerSecret)
            let policyContractAddress = try SCAddressXDR(contractId: Constants.samplePolicyCid)
            let limits = [PasskeyAddressLimits(address: policyContractAddress,
                                               limits: [Ed25519PasskeySignerKey(publicKey: Data(signerKp.publicKey.bytes))])]
            let submitterKp = try KeyPair(secretSeed: Constants.submitterSeed)
            
            var tx = try await user.passkeyKit.addPolicy(txSourceAccountId: submitterKp.accountId,
                                                         policyContractId: Constants.samplePolicyCid,
                                                         limits: limits,
                                                         storage: PasskeySignerStorage.temporary)
            
            let signatureExpirationLedger = try await StellarService.getLatestLedgerSequence() + 60
            try await user.passkeyKit.signTxAuthEntriesWithPasskey(tx: &tx, 
                                                                   signWithPasskey: signWithPasskey,
                                                                   signatureExpirationLayer: signatureExpirationLedger)
            
            let _ = try await StellarService.simulateAndSendTx(tx: tx)
            showInfo("Policy added")
            addingPolicyError = nil
        } catch {
            addingPolicyError = error.localizedDescription
        }
        addingPolicy = false
    }
    
    private func policyTransfer() async -> Void{
        policyTransfering = true
        do {
            var tx = try await StellarService.buildTransferTx(contractId: user.contractId, lumens: 1) // 2 XLM will be blocked by policy
            let signerKp = try KeyPair(secretSeed: Constants.ed25519SignerSecret)
            let signatureExpirationLedger = try await StellarService.getLatestLedgerSequence() + 60
            
            try user.passkeyKit.signTxAuthEntriesWithPolicy(tx: &tx,
                                                            policyContractId: Constants.samplePolicyCid,
                                                            signatureExpirationLayer: signatureExpirationLedger)
            
            
            try user.passkeyKit.signTxAuthEntriesWithKeyPair(tx: &tx,
                                                             signerKeyPair: signerKp,
                                                             signatureExpirationLayer: signatureExpirationLedger)
            
            let _ = try await StellarService.simulateAndSendTx(tx: tx)
            showInfo("Transfer success")
            policyTransferingError = nil
        } catch {
            policyTransferingError = error.localizedDescription
        }
        policyTransfering = false
    }
    
    private func multisigTransfer() async -> Void{
        multisigTransfering = true
        do {
            var tx = try await StellarService.buildTransferTx(contractId: user.contractId, lumens: 1) // 2 XLM will be blocked by policy
            let signerKp = try KeyPair(secretSeed: Constants.ed25519SignerSecret)
            let signatureExpirationLedger = try await StellarService.getLatestLedgerSequence() + 60
            
            try user.passkeyKit.signTxAuthEntriesWithPolicy(tx: &tx,
                                                            policyContractId: Constants.samplePolicyCid,
                                                            signatureExpirationLayer: signatureExpirationLedger)
            
            
            try user.passkeyKit.signTxAuthEntriesWithKeyPair(tx: &tx,
                                                             signerKeyPair: signerKp,
                                                             signatureExpirationLayer: signatureExpirationLedger)
            
            try await user.passkeyKit.signTxAuthEntriesWithPasskey(tx: &tx,
                                                                   signWithPasskey: signWithPasskey,
                                                                   signatureExpirationLayer: signatureExpirationLedger)
            
            let _ = try await StellarService.simulateAndSendTx(tx: tx)
            showInfo("Transfer success")
            multisigTransferingError = nil
        } catch {
            multisigTransferingError = error.localizedDescription
        }
        multisigTransfering = false
    }
    
    
    private func addSecp256r1Signer() async -> Void{
        addingSecp256r1Signer = true
        do {
            if signername.isEmpty {
                throw DemoError.runtimeError("Please provide a signer name")
            }
            let createKeyResponse = try await user.passkeyKit.createKey(userName: signername, createCredentials: createCredentials)
            
            let sequence = try await StellarService.getLatestLedgerSequence()
            let submitterKp = try KeyPair(secretSeed: Constants.submitterSeed)
            
            var tx = try await user.passkeyKit.addSecp256r1(txSourceAccountId: submitterKp.accountId,
                                                            keyId: createKeyResponse.keyId,
                                                            publicKey: createKeyResponse.publicKey,
                                                            storage: PasskeySignerStorage.temporary,
                                                            expiration: sequence + 518400)
            
            let signatureExpirationLedger = sequence + 60
            
            try await user.passkeyKit.signTxAuthEntriesWithPasskey(tx: &tx,
                                                                   signWithPasskey: signWithPasskey,
                                                                   signatureExpirationLayer: signatureExpirationLedger)
            
            let _ = try await StellarService.simulateAndSendTx(tx: tx)
            showInfo("Secp256r1 signer added")
            addingSecp256r1SignerError = nil
        } catch {
            addingSecp256r1SignerError = error.localizedDescription
        }
        addingSecp256r1Signer = false
    }
    
    private func signWithPasskey(_ challenge:Data, _ rpId:String) async throws -> PasskeyCredentialSigningResponse {
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let registrationRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)
        let result = try await authorizationController.performRequest(registrationRequest)
        switch result {
        case .passkeyAssertion(let credentialAssertion):
            return PasskeyCredentialSigningResponse(credentialID: credentialAssertion.credentialID,
                                                    signature: credentialAssertion.signature,
                                                    authenticatorData: credentialAssertion.rawAuthenticatorData,
                                                    clientDataJSON: credentialAssertion.rawClientDataJSON)
        default:
            throw DemoError.runtimeError("unexpected authorizationController response")
        }
        
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
    
    var progressView: some View {
        return ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .blue))
    }
    
    var divider: some View {
        return Divider()
    }
    
    private func showInfo(_ text:String) -> Void {
        toastMessage = text
        showToast = true
    }
    
    var balanceView: some View {
        VStack {
            HStack {
                Text("Balance").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .leading)
                if loadingBalance {
                    Text("loading").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .center)
                    progressView
                } else {
                    Text("\(balance)").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .center)
                    Button("", systemImage: "arrow.clockwise") {
                        Task {
                            await loadBalance()
                        }
                    }
                }
            }
            if let error = balanceLoadingError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    var addFundsView: some View {
        VStack {
            HStack {
                Text("Add funds (testnet)").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .leading)
                if fundingWallet {
                    progressView
                } else {
                    Button("", systemImage: "plus") {
                        Task {
                            await addFunds()
                            await loadBalance()
                        }
                    }
                }
            }
            if let error = fundingWalletError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    var addEd255129SignerView: some View {
        VStack {
            HStack {
                Text("Add Ed25519 Signer").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .leading)
                if addingEd25519Signer {
                    progressView
                } else {
                    Button("", systemImage: "plus") {
                        Task {
                            await addEd25519Signer()
                        }
                    }
                }
            }
            if let error = addingEd25519SignerError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    var ed255129TransferView: some View {
        VStack {
            HStack {
                Text("Ed25519 Transfer").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .leading)
                if ed25519Transfering {
                    progressView
                } else {
                    Button("", systemImage: "arrow.right") {
                        Task {
                            await ed25519Transfer()
                            await loadBalance()
                        }
                    }
                }
            }
            if let error = ed25519TransferingError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    var addPolicyView: some View {
        VStack {
            HStack {
                Text("Add Policy").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .leading)
                if addingPolicy {
                    progressView
                } else {
                    Button("", systemImage: "plus") {
                        Task {
                            await addPolicy()
                        }
                    }
                }
            }
            if let error = addingPolicyError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    var policyTransferView: some View {
        VStack {
            HStack {
                Text("Policy Transfer").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .leading)
                if policyTransfering {
                    progressView
                } else {
                    Button("", systemImage: "arrow.right") {
                        Task {
                            await policyTransfer()
                            await loadBalance()
                        }
                    }
                }
            }
            if let error = policyTransferingError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    var multisigTransferView: some View {
        VStack {
            HStack {
                Text("Multisig Transfer").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .leading)
                if multisigTransfering {
                    progressView
                } else {
                    Button("", systemImage: "arrow.right") {
                        Task {
                            await multisigTransfer()
                            await loadBalance()
                        }
                    }
                }
            }
            if let error = multisigTransferingError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    var addSecp256r1SignerView: some View {
        VStack {
            HStack {
                Text("Add Secp256r1 signer").foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .leading)
                if addingSecp256r1Signer {
                    progressView
                } else {
                    Button("", systemImage: "plus") {
                        Task {
                            await addSecp256r1Signer()
                        }
                    }
                }
            }
            TextField("Signer name", text: $signername).textFieldStyle(.roundedBorder).padding().onSubmit {
                Task {
                    await addSecp256r1Signer()
                }
            }
            if let error = addingSecp256r1SignerError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    var closeButton: some View {
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        logoutUser()
                    }) {
                        Image(systemName: "xmark.circle")
                            .padding(10)
                    }
                }
                .padding(.top, 5)
                Spacer()
            }
        }
}

public func logoutUserPreview() -> Void {}

#Preview {
    WalletView(user: User(keyId: Data(), contractId: "CBLL7ULRLV3W2HUWXJZ2L7IHEEJ5ETGF4R6M2MM6CS4IHTVTQAZFG5ZR", passkeyKit: PasskeyKit(rpId: "", rpcUrl: "", wasmHash: "", network: Network.testnet)), logoutUser: logoutUserPreview)
}
