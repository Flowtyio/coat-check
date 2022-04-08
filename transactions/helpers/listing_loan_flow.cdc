import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0xf8d6e0586b0a20c7
import ExampleToken from 0xf8d6e0586b0a20c7
import ExampleNFT from 0xf8d6e0586b0a20c7
import Flowty from 0xf8d6e0586b0a20c7

transaction(listItemID: UInt64, listItemPrice: UFix64, flowtyAddress: Address) {
    let flowReceiver: Capability<&ExampleToken.Vault{FungibleToken.Receiver}>
    let flowtyReceiver: Capability<&ExampleToken.Vault{FungibleToken.Receiver}>
    let exampleNFTProvider: Capability<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &Flowty.FlowtyStorefront

    prepare(acct: AuthAccount) {
        // We need a provider capability, but one is not provided by default so we create one if needed.
        let exampleNFTCollectionProviderPrivatePath = /private/exampleNFTCollectionProviderForFlowtyStorefront

        self.flowReceiver = acct.getCapability<&ExampleToken.Vault{FungibleToken.Receiver}>(/public/exampleTokenReceiver)!
        assert(self.flowReceiver.borrow() != nil, message: "Missing or mis-typed ExampleToken receiver")

        self.flowtyReceiver = getAccount(flowtyAddress).getCapability<&ExampleToken.Vault{FungibleToken.Receiver}>(/public/exampleTokenReceiver)!
        assert(self.flowtyReceiver.borrow() != nil, message: "Missing or mis-typed ExampleToken receiver")

        if !acct.getCapability<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(exampleNFTCollectionProviderPrivatePath)!.check() {
            acct.link<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(exampleNFTCollectionProviderPrivatePath, target: /storage/NFTCollection)
        }

        self.exampleNFTProvider = acct.getCapability<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(exampleNFTCollectionProviderPrivatePath)!
        assert(self.exampleNFTProvider.borrow() != nil, message: "Missing or mis-typed ExampleNFT.Collection provider")

        self.storefront = acct.borrow<&Flowty.FlowtyStorefront>(from: Flowty.FlowtyStorefrontStoragePath)
            ?? panic("Missing or mis-typed Flowty FlowtyStorefront")
    }

    execute {
        let paymentCut = Flowty.PaymentCut(
            receiver: self.flowReceiver,
            amount: listItemPrice / 2.0
        )

        let flowtyCut = Flowty.PaymentCut(
            receiver: self.flowtyReceiver,
            amount: listItemPrice / 2.0
        )

        self.storefront.createListing(
            nftProviderCapability: self.exampleNFTProvider,
            nftType: Type<@ExampleNFT.NFT>(),
            nftID: listItemID,
            fundPaymentVaultType: Type<@ExampleToken.Vault>(),
            paymentCuts: [paymentCut, flowtyCut]
        )
    }
}
