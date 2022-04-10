import FlowToken from "./standard/FlowToken.cdc"
import FlowStorageFees from "./standard/FlowStorageFees.cdc"
import FungibleToken from "./standard/FungibleToken.cdc"
import NonFungibleToken from "./standard/NonFungibleToken.cdc"


// CoatCheck
//
// A Smart contract Meant to hold items for another address should they not be able to receive them.
// this contract is essentially an escrow that no one holds the keys to. It will support holding any Fungible and NonFungible Tokens
// with a specified address that is allowed to claim them. In this way, dapps which need to ensure that accounts are able to "Receive" assets
// have a way of putting them into a holding resource that the intended receiver can redeem.
pub contract CoatCheck {

    // | ---------------- Events ----------------- |
    pub event Initialized()

    pub event TicketCreated(ticketResourceID: UInt64, redeemer: Address, storageFee: UFix64)

    pub event TicketRedeemed(ticketResourceID: UInt64, redeemer: Address, storageFeeReturned: UFix64)

    pub event ValetDestroyed(resourceID: UInt64)

    // | -------- Contract level Variables -------- |
    access(contract) let flowTokenReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
    access(contract) let flowTokenProvider: Capability<&FlowToken.Vault{FungibleToken.Provider}>

    // | -------- Paths -------- |
    pub let ValetStoragePath: StoragePath
    pub let ValetPublicPath: PublicPath


    // A CoatCheck has been initialized. This resource can now be watched for deposited items that accounts can redeem
    pub event CoatCheckInitialized(resourceID: UInt64)

    pub resource interface TicketPublic {
        pub fun redeem(fungibleTokenReceiver: &{FungibleToken.Receiver}?, nonFungibleTokenReceiver: &{NonFungibleToken.Receiver}?)
    }

    pub resource Ticket: TicketPublic {
        // a ticket can have Fungible Tokens AND NonFungibleTokens
        access(self) var fungibleTokenVaults: @[FungibleToken.Vault]?
        access(self) var nonFungibleTokens: @[NonFungibleToken.NFT]?
        access(contract) let feeRefundReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

        pub let redeemer: Address

        // The following variables are maintained by the CoatCheck contract
        access(self) var redeemed: Bool
        access(self) var storageFee: UFix64

        init(
            fungibleTokenVaults: @[FungibleToken.Vault]?,
            nonFungibleTokens: @[NonFungibleToken.NFT]?,
            feeRefundReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>,
            redeemer: Address
        ) {
            assert(
                fungibleTokenVaults != nil || nonFungibleTokens != nil, 
                message: "must provide either FungibleToken vaults or NonFungibleToken NFTs"
            )
            self.fungibleTokenVaults <- fungibleTokenVaults
            self.nonFungibleTokens <- nonFungibleTokens
            self.feeRefundReceiver = feeRefundReceiver
            self.redeemer = redeemer

            self.redeemed = false
            self.storageFee = 0.0
        }

        pub fun redeem(fungibleTokenReceiver: &{FungibleToken.Receiver}?, nonFungibleTokenReceiver: &{NonFungibleToken.Receiver}?) {
            pre {
                fungibleTokenReceiver == nil || (fungibleTokenReceiver!.owner!.address == self.redeemer) : "incorrect owner"
                nonFungibleTokenReceiver == nil || (nonFungibleTokenReceiver!.owner!.address == self.redeemer) : "incorrect owner"
                self.fungibleTokenVaults == nil || fungibleTokenReceiver != nil: "must provide fungibleTokenReceiver when there is a vault to claim"
                self.nonFungibleTokens == nil || nonFungibleTokenReceiver != nil: "must provide nonFungibleTokenReceiver when there is a vault to claim"
            }

            self.redeemed = true

            let coatCheckAddr = CoatCheck.account.address
            let beforeBalance = FlowStorageFees.defaultTokenAvailableBalance(coatCheckAddr) 

            let vaults <- self.fungibleTokenVaults <- nil
            let tokens <- self.nonFungibleTokens <- nil

            if vaults != nil && vaults?.length! > 0 {
                while vaults?.length! > 0 {
                    let vault <- vaults?.remove(at: 0)!
                    fungibleTokenReceiver!.deposit(from: <-vault)
                }
            }

            if tokens != nil && tokens?.length! > 0 {
                while tokens?.length! > 0 {
                    let token <- tokens?.remove(at: 0)!
                    nonFungibleTokenReceiver!.deposit(token: <-token)
                }
            }

            let afterBalance = FlowStorageFees.defaultTokenAvailableBalance(coatCheckAddr) 

            destroy vaults
            destroy tokens
        }

        destroy () {
            pre {
                self.redeemed : "not redeemed"
            }
        
            destroy self.fungibleTokenVaults
            destroy self.nonFungibleTokens
        }
    }

    pub resource interface ValetPublic {
        pub fun createTicket(
            redeemer: Address, 
            vaults: @[FungibleToken.Vault]?, 
            tokens: @[NonFungibleToken.NFT]?, 
            feeVault: @FlowToken.Vault, 
            redemptionReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
        )
        pub fun borrowTicket(ticketID: UInt64): &Ticket{TicketPublic}?
        pub fun redeemTicket(
            ticketID: UInt64, 
            fungibleTokenReceiver: &{FungibleToken.Receiver}?,
            nonFungibleTokenReceiver: &{NonFungibleToken.Receiver}?,
        )
    }

    pub resource Valet: ValetPublic {
        access(self) var tickets: @{UInt64: Ticket}
        access(self) var feesByTicketID: {UInt64: UFix64}

        init() {
            self.tickets <- {}
            self.feesByTicketID = {}
        }

        pub fun createTicket(
            redeemer: Address, 
            vaults: @[FungibleToken.Vault]?, 
            tokens: @[NonFungibleToken.NFT]?, 
            feeVault: @FlowToken.Vault,
            redemptionReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
        ) {
            let coatCheckAddr = CoatCheck.account.address
            let beforeBalance = FlowStorageFees.defaultTokenAvailableBalance(coatCheckAddr)

            let ticket <- create Ticket(
                fungibleTokenVaults: <-vaults,
                nonFungibleTokens: <-tokens,
                feeRefundReceiver: redemptionReceiver,
                redeemer: redeemer,
            )

            let ticketID = ticket.uuid
            let oldTicket <- self.tickets[ticketID] <- ticket
            destroy oldTicket

            // calculate how much storage was taken up
            let afterBalance = FlowStorageFees.defaultTokenAvailableBalance(coatCheckAddr)
            CoatCheck.flowTokenReceiver.borrow()!
            let storageFee = beforeBalance - afterBalance
            let storageFeeVault <- feeVault.withdraw(amount: storageFee)
            CoatCheck.flowTokenReceiver.borrow()!.deposit(from: <-storageFeeVault)

            // record the fees taken
            self.feesByTicketID[ticketID] = storageFee

            // return the remainder
            redemptionReceiver.borrow()!.deposit(from: <-feeVault)

            emit TicketCreated(ticketResourceID: ticketID, redeemer: redeemer, storageFee: storageFee)
        }

        pub fun borrowTicket(ticketID: UInt64): &Ticket{TicketPublic}? {
             if self.tickets[ticketID] != nil {
                return &self.tickets[ticketID] as! &Ticket{TicketPublic}
            } else {
                return nil
            }
        }

        pub fun redeemTicket(
            ticketID: UInt64, 
            fungibleTokenReceiver: &{FungibleToken.Receiver}?,
            nonFungibleTokenReceiver: &{NonFungibleToken.Receiver}?
        ) {
            pre {
                self.tickets[ticketID] != nil : "ticket does not exist"
            }
            let ticket <-! self.tickets[ticketID] <- nil
            ticket?.redeem(fungibleTokenReceiver: fungibleTokenReceiver, nonFungibleTokenReceiver: nonFungibleTokenReceiver)

            let storageFee = self.feesByTicketID.remove(key: ticket?.uuid!)
            let refundVault <- CoatCheck.flowTokenProvider.borrow()!.withdraw(amount: storageFee!)
            ticket?.feeRefundReceiver!.borrow()!.deposit(from: <-refundVault)

            emit TicketRedeemed(ticketResourceID: ticket?.uuid!, redeemer: ticket?.redeemer!, storageFeeReturned: storageFee!)
            destroy ticket
        }

        destroy () {
            emit ValetDestroyed(resourceID: self.uuid)
            destroy self.tickets
        }
    }

    pub fun getValetPublic(): Capability<&CoatCheck.Valet{CoatCheck.ValetPublic}> {
        return self.account.getCapability<&CoatCheck.Valet{CoatCheck.ValetPublic}>(self.ValetPublicPath)
    }

    init() {
        self.flowTokenReceiver = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        self.account.link<&FlowToken.Vault{FungibleToken.Provider}>(/private/coatCheckFlowTokenProvider, target: /storage/flowTokenVault)
        self.flowTokenProvider = self.account.getCapability<&FlowToken.Vault{FungibleToken.Provider}>(/private/coatCheckFlowTokenProvider)

        self.ValetStoragePath = /storage/coatCheckValet
        self.ValetPublicPath = /public/coatCheckValet

        let valet <- create Valet()
        self.account.save(<-valet, to: self.ValetStoragePath)
        self.account.link<&CoatCheck.Valet{CoatCheck.ValetPublic}>(self.ValetPublicPath, target: self.ValetStoragePath)
    }
}
 