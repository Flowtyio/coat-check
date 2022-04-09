import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

import CoatCheck from 0xf8d6e0586b0a20c7
import ExampleToken from 0xf8d6e0586b0a20c7

transaction(amount: UFix64, redeemer: Address) {
    let exampleTokenProvider: Capability<&ExampleToken.Vault{FungibleToken.Provider}>
    let coatCheckPublic: Capability<&CoatCheck.Valet{CoatCheck.ValetPublic}>
    let feeVault: @FlowToken.Vault
    let flowTokenReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

    prepare(acct: AuthAccount) {
        let exampleTokenProviderPath = /private/exampleNFTProviderForCoatCheck
        let flowTokenReceiverPath = /public/flowTokenReceiverForCoatCheck

        if !acct.getCapability<&ExampleToken.Vault{FungibleToken.Provider}>(exampleTokenProviderPath).check() {
            acct.link<&ExampleToken.Vault{FungibleToken.Provider}>(exampleTokenProviderPath, target: /storage/exampleTokenVault)
        }

        if !acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(flowTokenReceiverPath).check() {
            acct.link<&FlowToken.Vault{FungibleToken.Receiver}>(flowTokenReceiverPath, target: /storage/flowTokenVault)
        }

        self.exampleTokenProvider = acct.getCapability<&ExampleToken.Vault{FungibleToken.Provider}>(exampleTokenProviderPath)
        assert(self.exampleTokenProvider.borrow() != nil, message: "Missing or mis-typed ExampleToken.Vault Provider")

        self.flowTokenReceiver = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(flowTokenReceiverPath)
        assert(self.flowTokenReceiver.borrow() != nil, message: "Missing or mis-typed FlowToken.Vault Receiver")

        self.coatCheckPublic = CoatCheck.getValetPublic()
        assert(self.coatCheckPublic.borrow() != nil, message: "Missing or mis-typed CoatCheck.ValetPublic")

        self.feeVault <- acct.borrow<&FlowToken.Vault{FungibleToken.Provider}>(from: /storage/flowTokenVault)!.withdraw(amount: amount) as! @FlowToken.Vault
    }

    execute {
        let vaults <- [] as @[FungibleToken.Vault]
        vaults.append(<- self.exampleTokenProvider.borrow()!.withdraw(amount: amount))
        
        self.coatCheckPublic.borrow()!.createTicket(
            redeemer: redeemer, 
            vaults: <-vaults, 
            tokens: nil, 
            feeVault: <-self.feeVault, 
            redemptionReceiver: self.flowTokenReceiver
        )

    }
}