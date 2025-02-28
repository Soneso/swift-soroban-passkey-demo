# Swift Passkey Kit Demo App

A demo app using the [SwiftPasskeyKit](https://github.com/Soneso/SwiftPasskeyKit) functionality to create and manage smart wallets on soroban.

## Getting Started

First, clone this repo.

Then, to use the demo app, you must first build the smart wallet contract from the `/contracts` folder of the passkey kit project, that can be found [here](https://github.com/Soneso/SwiftPasskeyKit/contracts):

```shell
cd contracts
make build
```

Next, install the contract using the stellar-cli. E.g.:

```shell
cd out
stellar contract install --source-account alice --wasm smart_wallet.optimized.wasm --rpc-url https://soroban-testnet.stellar.org --network-passphrase 'Test SDF Network ; September 2015'
```

You will obtain the `wasm_hash` of the installed contract that will look similar to this:

```shell
6e7d01475c89eee531a91ec0f8f5348beda9d9e232a4d383da02fc9afc3c221b
```

### Constants.swift

In the source code of the app, navigate to `Constants.swift` and update the constant `walletWasmHash` by filling the value with the obtained `wasm_hash`.
Also update the other constant in `Constants.swift` as described in the following chapters.

#### rpId

`rpId` is the name of the domain hosting your apple-app-site-association (AASA) file. You can read more about how to create and deploy your AASA file [here](https://developer.apple.com/documentation/xcode/supporting-associated-domains).

Hint: Replace also the domain in the associated domains entitlement of your cloned app.

#### rpcUrl

`rpcUrl` is the url of the soroban rpc server to be used for requests and to send transactions to soroban.

E.g. `https://soroban-testnet.stellar.org`

#### horizonUrl

`horizonUrl` is the url of the horizon instance to be used for requests and to send transactions to the stellar network. E.g. `https://horizon-testnet.stellar.org` 

#### network

`network` is the network to be used. E.g. for testnet: `Network.testnet`

#### submitterSeed

`submitterSeed` is the secret seed of the stellar account that is used to sign and send transactions. Make sure that the account is funded.

#### nativeSacCid

`nativeSacCid` is the contract id of the XLM SAC to make transfers (payments). For example `CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC`on testnet.

#### ed25519SignerSecret

`ed25519SignerSecret` is the secret seed of a stellar account keypair to be used as a signer for the ed25519Signer demo.

#### samplePolicyCid

`samplePolicyCid` is the contract id of a deployed policy contract to be used in the policy demo. An example policy contract can be found in in the `/contracts` folder of the [SwiftPasskeyKit](https://github.com/Soneso/SwiftPasskeyKit) project.


### Smart Contracts

Make yourself familiar with the smart wallet contracts from the `/contracts` folder of the [SwiftPasskeyKit](https://github.com/Soneso/SwiftPasskeyKit) project. They were implemented by kalepail as a part of the [TypeScript PasskeyKit](https://github.com/kalepail/passkey-kit), also provided by kalepail.

### Start the app

After deploying your AASA file and filling the `Constants.swift` values, start the app and create a new wallet. After the app connects to the new created wallet, you will find the demo functionality to interact with the wallet.

Use the source code, to understand how the demo app uses the [SwiftPasskeyKit](https://github.com/Soneso/SwiftPasskeyKit).

