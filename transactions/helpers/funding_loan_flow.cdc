import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0xf8d6e0586b0a20c7
import ExampleToken from 0xf8d6e0586b0a20c7
import ExampleNFT from 0xf8d6e0586b0a20c7
import Flowty from 0xf8d6e0586b0a20c7

transaction(listingResourceID: UInt64, flowtyStorefrontAddress: Address) {
    let paymentVault: @FungibleToken.Vault
    let exampleNFTCollection: &ExampleNFT.Collection{NonFungibleToken.Receiver}
    let storefront: &Flowty.FlowtyStorefront{Flowty.FlowtyStorefrontPublic}
    let listing: &Flowty.Listing{Flowty.ListingPublic}

    prepare(acct: AuthAccount) {
        self.storefront = getAccount(flowtyStorefrontAddress)
            .getCapability<&Flowty.FlowtyStorefront{Flowty.FlowtyStorefrontPublic}>(
                Flowty.FlowtyStorefrontPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow FlowtyStorefront from provided address")

        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
                    ?? panic("No Offer with that ID in FlowtyStorefront")
        let price = self.listing.getDetails().fundPrice

        let mainFlowVault = acct.borrow<&ExampleToken.Vault>(from: /storage/exampleTokenVault)
            ?? panic("Cannot borrow ExampleToken vault from acct storage")
        self.paymentVault <- mainFlowVault.withdraw(amount: price)

        self.exampleNFTCollection = acct.borrow<&ExampleNFT.Collection{NonFungibleToken.Receiver}>(
            from: /storage/NFTCollection
        ) ?? panic("Cannot borrow NFT collection receiver from account")
    }

    execute {
        self.listing.fund(
            payment: <-self.paymentVault
        )

        // let item <- self.listing.fund(
        //     payment: <-self.paymentVault
        // )

        // self.exampleNFTCollection.deposit(token: <-item)

        /* //-
        error: Execution failed:
        computation limited exceeded: 100
        */
        // Be kind and recycle
        //self.storefront.cleanup(listingResourceID: listingResourceID)
    }

    //- Post to check item is in collection?
}
