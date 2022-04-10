import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

import CoatCheck from 0xf8d6e0586b0a20c7

transaction(ticketID: UInt64) {
    let fungibleTokenReceiver: &{FungibleToken.Receiver}?
    let valet: Capability<&CoatCheck.Valet{CoatCheck.ValetPublic}>


    prepare(acct: AuthAccount) {
        self.valet = CoatCheck.getValetPublic()
        self.fungibleTokenReceiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver).borrow()!
    }

    execute {
        self.valet.borrow()!.redeemTicket(ticketID: ticketID, fungibleTokenReceiver: self.fungibleTokenReceiver, nonFungibleTokenReceiver: nil)
    }
}