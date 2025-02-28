//
//  Constants.swift
//  swift-soroban-passkey-demo
//
//  Created by Christian Rogobete on 24.02.25.
//

import Foundation
import stellarsdk

public class Constants {
    public static let rpId:String = "soneso.com"
    public static let rpcUrl = "https://soroban-testnet.stellar.org"
    public static let horizonUrl = "https://horizon-testnet.stellar.org"
    public static let walletWasmHash = "6e7d01475c89eee531a91ec0f8f5348beda9d9e232a4d383da02fc9afc3c221b"
    public static let network = Network.testnet
    public static let submitterSeed = "SANNZJ7GKITURTEKMJNKZX6G2DCCF7GV2QH56HLHJVX364TM5GSMHSDC" // GBU4UJIMVLEVPH5Y74BUOSU4I3YSYDGAJUMLMXW3RTMXADBD33SXSQSE
    public static let nativeSacCid = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC"
    public static let ed25519SignerSecret = "SCNJH4G2SGFAD7KMET57O2GLBENF5IPB552ZDHIYWUVSFJIEOOXTGGPA" // GAHAL6FKBITWXSOPW7BJLFRI3EBCEFG2F7CLMJQYVRNCY4QMYGOHJMWE
    public static let samplePolicyCid = "CBQZU3JQ2HEBQHSUSADNXQAKKEGU3EZDWMSPX2Y5RGTLX6ICVXZMUQB3"
}
