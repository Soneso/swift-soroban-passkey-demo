//
//  StellarService.swift
//  swift-soroban-passkey-demo
//
//  Created by Christian Rogobete on 24.02.25.
//

import Foundation
import stellarsdk

public class StellarService {
    
    public static let sorobanServer = SorobanServer(endpoint: Constants.rpcUrl)
    public static let sdk = StellarSDK(withHorizonUrl: Constants.horizonUrl)
    
    internal static func feeBumpCreateWallet(innerTx:Transaction) async throws -> Void {
        let submitterKeyPair  = try KeyPair(secretSeed: Constants.submitterSeed)
        
        let accountDetailsResponse = await sdk.accounts.getAccountDetails(accountId: submitterKeyPair.accountId)
        switch accountDetailsResponse {
        case .success(let accountDetails):
            let muxedSourceAccount = try MuxedAccount(accountId: accountDetails.accountId, sequenceNumber: accountDetails.sequenceNumber)
            let feeBumpTx = try FeeBumpTransaction(sourceAccount: muxedSourceAccount,
                                                   fee: UInt64(innerTx.fee) + 1000,
                                                   innerTransaction: innerTx)
            
            try feeBumpTx.sign(keyPair: submitterKeyPair, network: Constants.network)
            let submissionResult = await sdk.transactions.submitFeeBumpTransaction(transaction: feeBumpTx)
            switch submissionResult {
            case .success(_):
                return
            case .destinationRequiresMemo(let destinationAccountId):
                throw DemoError.runtimeError("Fee bump destinationRequiresMemo: \(destinationAccountId)")
            case .failure(let error):
                throw error
            }
        case .failure(let error):
            throw error
        }
    }
    
    internal static func getBalance(contractId:String) async throws -> Double {
        sorobanServer.enableLogging = true
        let arg = SCValXDR.address(try SCAddressXDR(contractId: contractId))
        let invokeOperation = try InvokeHostFunctionOperation.forInvokingContract(contractId: Constants.nativeSacCid,
                                                                                   functionName: "balance",
                                                                                   functionArguments: [arg])
        let response = try await invokeHostFunctionOp(op: invokeOperation)
        
        if let resultValue = response.resultValue, let i128 = resultValue.i128 {
            return Double(i128.lo / 10000000)
        } else {
            throw DemoError.runtimeError("No balance found for cid: \(contractId)")
        }
    }
    
    internal static func addFunds(contractId:String) async throws -> Void {
        if Constants.network.passphrase != "Test SDF Network ; September 2015" {
            throw DemoError.runtimeError("Only testnet wallets can be funded by the demo. Transfer XLM to your wallet address to fund it.")
        }
        let randomKeypair = try KeyPair.generateRandomKeyPair()
        let createResponseEnum = await sdk.accounts.createTestAccount(accountId: randomKeypair.accountId)
        
        switch createResponseEnum {
        case .success(_):
            break
        case .failure(_):
            throw DemoError.runtimeError("Error funding wallet, could not create test account")
        }
        let from = SCValXDR.address(try SCAddressXDR(accountId: randomKeypair.accountId))
        let to = SCValXDR.address(try SCAddressXDR(contractId: contractId))
        let amount = SCValXDR.i128(Int128PartsXDR(hi: 0, lo: 9900 * 10000000)) // 9900 XLM
        let op = try InvokeHostFunctionOperation.forInvokingContract(contractId: Constants.nativeSacCid,
                                                                     functionName: "transfer",
                                                                     functionArguments: [from, to, amount])
        let _ = try await invokeHostFunctionOp(op: op, sourceAccountKeyPair: randomKeypair)
    }
    
    internal static func getLatestLedgerSequence() async throws -> UInt32 {
        let responseEnum = await sorobanServer.getLatestLedger()
        switch responseEnum {
        case .success(let response):
            return response.sequence
        case .failure(let error):
            throw error
        }
    }
    
    private static func invokeHostFunctionOp(op:InvokeHostFunctionOperation, sourceAccountKeyPair:KeyPair? = nil) async throws -> GetTransactionResponse {
        
        var submitterKeyPair:KeyPair?
        if sourceAccountKeyPair != nil {
            submitterKeyPair = sourceAccountKeyPair!
        } else {
            submitterKeyPair = try KeyPair(secretSeed: Constants.submitterSeed)
        }
        let response = await sorobanServer.getAccount(accountId: submitterKeyPair!.accountId)
        switch response {
        case .success(let account):
            let tx = try Transaction(sourceAccount: account, operations: [op], memo: Memo.none)
            return try await simulateAndSendTx(tx: tx, signerKeypair: submitterKeyPair)
        case .failure(_):
            throw DemoError.runtimeError("Could not find submitter account: \(submitterKeyPair!.accountId)")
        }
    }
    
    internal static func simulateTx(tx:Transaction) async -> SimulateTransactionResponseEnum {
        let simulateTxRequest = SimulateTransactionRequest(transaction: tx)
        return await sorobanServer.simulateTransaction(simulateTxRequest: simulateTxRequest)
    }
    
    internal static func simulateAndSendTx(tx:Transaction, signerKeypair:KeyPair? = nil) async throws -> GetTransactionResponse {
        let simulateTxResponseEnum = await StellarService.simulateTx(tx: tx)
        switch simulateTxResponseEnum {
        case .success(let simulateResponse):
            if let err = simulateResponse.error {
                throw DemoError.runtimeError(err)
            }
            tx.setSorobanTransactionData(data: simulateResponse.transactionData!)
            tx.addResourceFee(resourceFee: simulateResponse.minResourceFee!)
            tx.setSorobanAuth(auth: simulateResponse.sorobanAuth)
            try tx.sign(keyPair: signerKeypair ?? (try KeyPair(secretSeed: Constants.submitterSeed)), network: Constants.network)
            return try await StellarService.sendAndCheckSorobanTx(transaction: tx)
        case .failure(let error):
            throw error
        }
    }
    
    internal static func sendAndCheckSorobanTx(transaction:Transaction) async throws -> GetTransactionResponse {
        let sendTxResponseEnum = await sorobanServer.sendTransaction(transaction: transaction)
        switch sendTxResponseEnum {
        case .success(let response):
            if (SendTransactionResponse.STATUS_ERROR == response.status) {
                throw DemoError.runtimeError("Soroban transaction submission failed, txId: \(response.transactionId)")
            }
            let txResponse = try await pollTxStatus(txId: response.transactionId)
            if (GetTransactionResponse.STATUS_SUCCESS != txResponse.status) {
                throw DemoError.runtimeError("Error sending tx to soroban: tx \(txResponse.txHash ?? "") not successful")
            }
            return txResponse
        case .failure(_):
            throw DemoError.runtimeError("Soroban transaction submission failed")
        }
    }
    
    // poll until success or error
    private static func pollTxStatus(txId:String) async throws -> GetTransactionResponse {
        var status = GetTransactionResponse.STATUS_NOT_FOUND
        var txResponse:GetTransactionResponse?
        while (status == GetTransactionResponse.STATUS_NOT_FOUND) {
            try! await Task.sleep(nanoseconds: UInt64(3 * Double(NSEC_PER_SEC)))
            let txResponseEnum = await sorobanServer.getTransaction(transactionHash: txId)
            switch txResponseEnum {
            case .success(let response):
                txResponse = response
                status = response.status
            case .failure(_):
                throw DemoError.runtimeError("Could not poll tx: \(txId)")
            }
        }
        return txResponse!
    }
    
    internal static func buildTransferTx(contractId:String, lumens:UInt64? = nil) async throws -> Transaction {
        let from = SCValXDR.address(try SCAddressXDR(contractId: contractId))
        let submitterKeyPair  = try KeyPair(secretSeed: Constants.submitterSeed)
        let to = SCValXDR.address(try SCAddressXDR(accountId: submitterKeyPair.accountId))
        let amount = SCValXDR.i128(Int128PartsXDR(hi: 0, lo: (lumens ?? 1) * 10000000))
        let op = try InvokeHostFunctionOperation.forInvokingContract(contractId: Constants.nativeSacCid,
                                                                 functionName: "transfer",
                                                                 functionArguments: [from, to, amount])
        let sourceAccountId = submitterKeyPair.accountId
        let accountResponseEnum = await sorobanServer.getAccount(accountId: sourceAccountId)
        switch accountResponseEnum {
        case .success(let account):
            let transaction = try Transaction(sourceAccount: account, operations: [op], memo: Memo.none)
            let simulateTxResponseEnum = await simulateTx(tx: transaction)
            switch simulateTxResponseEnum {
            case .success(let simulateResponse):
                if let error = simulateResponse.error {
                    throw DemoError.runtimeError(error)
                }
                transaction.setSorobanTransactionData(data: simulateResponse.transactionData!)
                transaction.addResourceFee(resourceFee: simulateResponse.minResourceFee!)
                transaction.setSorobanAuth(auth: simulateResponse.sorobanAuth)
                return transaction
            case .failure(let error):
                throw error
            }
        case .failure(let error):
            throw error
        }
        
    }
}
