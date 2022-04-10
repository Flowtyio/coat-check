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

    // Tickets are used to fungible tokens, non-fungible tokens, or both.
    // A ticket can be created by the CoatCheck valet, and can be redeemed only by
    // capabilities owned by the designated redeemer of a ticket
    pub resource Ticket: TicketPublic {
        // a ticket can have Fungible Tokens AND NonFungibleTokens
        access(self) var fungibleTokenVaults: @[FungibleToken.Vault]?
        access(self) var nonFungibleTokens: @[NonFungibleToken.NFT]?
        
        // when a ticket is redeemed, we take back the storage fee that 
        // was recorded when the ticket was made so that it can be returned
        access(contract) let feeRefundReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

        // only this address's capabilities can be used to redeem this ticket
        pub let redeemer: Address

        // The following variables are maintained by the CoatCheck contract
        access(self) var redeemed: Bool // a ticket can only be redeemed once. It also cannot be destroyed unless redeemed is set to true
        access(self) var storageFee: UFix64 // the storage fee taken to hold this ticket in storage. It is returned when the ticket is redeemed.

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

        // redeem the ticket using an optional receiver for fungible tokens and non-fungible tokens. The supplied receivers must be
        // owned by the redeemer of this ticket.
        pub fun redeem(fungibleTokenReceiver: &{FungibleToken.Receiver}?, nonFungibleTokenReceiver: &{NonFungibleToken.Receiver}?) {
            pre {
                fungibleTokenReceiver == nil || (fungibleTokenReceiver!.owner!.address == self.redeemer) : "incorrect owner"
                nonFungibleTokenReceiver == nil || (nonFungibleTokenReceiver!.owner!.address == self.redeemer) : "incorrect owner"
                self.fungibleTokenVaults == nil || fungibleTokenReceiver != nil: "must provide fungibleTokenReceiver when there is a vault to claim"
                self.nonFungibleTokens == nil || nonFungibleTokenReceiver != nil: "must provide nonFungibleTokenReceiver when there is a vault to claim"
            }

            self.redeemed = true

            let vaults <- self.fungibleTokenVaults <- nil
            let tokens <- self.nonFungibleTokens <- nil

            // do we have vaults to distribute?
            if vaults != nil && vaults?.length! > 0 {
                while vaults?.length! > 0 {
                    // pop them off our list of vaults one by one and deposit them
                    let vault <- vaults?.remove(at: 0)!
                    fungibleTokenReceiver!.deposit(from: <-vault)
                }
            }

            // do we have nfts to distribute?
            if tokens != nil && tokens?.length! > 0 {
                while tokens?.length! > 0 {
                    // pop them off our list of tokens one by one and deposit them
                    let token <- tokens?.remove(at: 0)!
                    nonFungibleTokenReceiver!.deposit(token: <-token)
                }
            }

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

    // ValetPublic contains our main entry-point methods that
    // anyone can use to make/redeem tickets.
    pub resource interface ValetPublic {
        // Create a new ticket containing a list of vaults, nfts, or both.
        // The creator of a ticket must also include a vault to pay fees with,
        // and a receiver to refund the fee taken once a ticket is redeemed.
        // Any extra tokens sent for the storage fee are sent back when the ticket is made
        pub fun createTicket(
            redeemer: Address, 
            vaults: @[FungibleToken.Vault]?, 
            tokens: @[NonFungibleToken.NFT]?, 
            feeVault: @FlowToken.Vault, 
            redemptionReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
        )

        // redeem a ticket, supplying an optional receiver to use for depositing
        // any fts or nfts in the ticket
        pub fun redeemTicket(
            ticketID: UInt64, 
            fungibleTokenReceiver: &{FungibleToken.Receiver}?,
            nonFungibleTokenReceiver: &{NonFungibleToken.Receiver}?,
        )
        pub fun borrowTicket(ticketID: UInt64): &Ticket{TicketPublic}?
        
    }

    pub resource Valet: ValetPublic {
        access(self) var tickets: @{UInt64: Ticket}

        // we store the fees taken when a ticket is made so that the exact amount is withdrawn
        // when a ticket is redeemed
        access(self) var feesByTicketID: {UInt64: UFix64}

        init() {
            self.tickets <- {}
            self.feesByTicketID = {}
        }

        // Create a new ticket containing a list of vaults, nfts, or both.
        // The creator of a ticket must also include a vault to pay fees with,
        // and a receiver to refund the fee taken once a ticket is redeemed.
        // Any extra tokens sent for the storage fee are sent back when the ticket is made
        pub fun createTicket(
            redeemer: Address, 
            vaults: @[FungibleToken.Vault]?, 
            tokens: @[NonFungibleToken.NFT]?, 
            feeVault: @FlowToken.Vault,
            redemptionReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
        ) {
            // calculate the balance in flow that we have before storing this new ticket
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

            // calculate how much storage was taken up now that the ticket has been stored
            let afterBalance = FlowStorageFees.defaultTokenAvailableBalance(coatCheckAddr)
            CoatCheck.flowTokenReceiver.borrow()!
            // the difference in flow balance is taken as a fee
            let storageFee = beforeBalance - afterBalance

            // return the rest
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

        // redeem the ticket using supplied receivers.
        // if a ticket has fungible tokens, the fungibleTokenReceiver is required.
        // if a ticket has nfts, the nonFungibleTokenReceiver is required.
        pub fun redeemTicket(
            ticketID: UInt64, 
            fungibleTokenReceiver: &{FungibleToken.Receiver}?,
            nonFungibleTokenReceiver: &{NonFungibleToken.Receiver}?
        ) {
            pre {
                self.tickets[ticketID] != nil : "ticket does not exist"
            }
            // take the ticket out of storage and redeem it
            let ticket <-! self.tickets[ticketID] <- nil
            ticket?.redeem(fungibleTokenReceiver: fungibleTokenReceiver, nonFungibleTokenReceiver: nonFungibleTokenReceiver)

            // calculate the difference in storage fees now that the ticket has been taken out of storage
            // and return it to the ticket creator
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
 