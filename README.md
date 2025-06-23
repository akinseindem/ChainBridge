# ChainBridge

Decentralized marketplace for buying, selling, and trading Non-Fungible Tokens (NFTs) across various blockchain networks.

---

## Table of Contents

* About
* Features
* Smart Contract Details
    * Constants
    * Data Maps and Variables
    * Private Functions
    * Public Functions
    * Error Codes
* Getting Started
* Usage
* Contributing
* License
* Contact
* Acknowledgments

---

## About

**ChainBridge** is a decentralized marketplace for buying, selling, and trading Non-Fungible Tokens (NFTs) across various blockchain networks. Built on Clarity, this smart contract introduces robust cross-chain capabilities with a secure escrow system, multi-signature support, and dispute resolution mechanisms. Our goal is to provide a seamless and trustworthy environment for NFT enthusiasts to transact, regardless of the underlying blockchain.

---

## Features

* **Cross-Chain NFT Trading**: Facilitates the listing and trading of NFTs that can originate from or be transferred to different blockchain networks (Stacks, Ethereum, Polygon, Bitcoin).
* **Secure Escrow System**: Implements a dedicated escrow for cross-chain transfers, ensuring funds are held securely until transaction completion or resolution.
* **Multi-Signature Validation**: The escrow system incorporates validator consensus with multi-signature support, enhancing security and trust for cross-chain transactions.
* **Dispute Resolution**: Includes mechanisms for raising disputes and defining dispute deadlines within the escrow process.
* **Automated Release**: Escrowed funds can be automatically released after a defined period if no disputes are raised or confirmations are met.
* **User Profiles**: Allows users to link their cross-chain addresses (Ethereum, Polygon, Bitcoin) to their Stacks address, improving user experience for multi-chain interactions.
* **Marketplace Fees**: A transparent fee structure (2.5%) is applied to sales, contributing to the marketplace's sustainability.
* **Comprehensive Statistics**: Tracks total listings, sales, and volume, providing insights into marketplace activity.
* **Cancellable Listings**: Sellers retain the ability to cancel active NFT listings.

---

## Smart Contract Details

This section provides a deeper dive into the architecture and components of the `ChainBridge` smart contract.

### Constants

* `CONTRACT-OWNER`: Defines the principal address of the contract owner, used for administrative functions and fee collection.
* `ERR-OWNER-ONLY` (u100): Returned when an action can only be performed by the contract owner.
* `ERR-NOT-FOUND` (u101): Indicates that the requested item (e.g., NFT listing) was not found.
* `ERR-UNAUTHORIZED` (u102): Returned when the transaction sender is not authorized to perform the action.
* `ERR-ALREADY-EXISTS` (u103): Signifies an attempt to create an entity that already exists.
* `ERR-INSUFFICIENT-FUNDS` (u104): Returned when the provided payment is less than the required amount.
* `ERR-INVALID-PRICE` (u105): Indicates an invalid price (e.g., zero or negative).
* `ERR-LISTING-EXPIRED` (u106): Returned when an attempt is made to interact with an expired listing.
* `ERR-INVALID-CHAIN` (u107): Signifies an unsupported or invalid blockchain network ID.
* `ERR-ESCROW-LOCKED` (u108): Returned when an action cannot be performed because an escrow is locked.
* `MARKETPLACE-FEE`: The percentage fee charged by the marketplace (2.5%, represented as `u250`).
* `FEE-DENOMINATOR`: Denominator for fee calculation (`u10000`).
* `CHAIN-STACKS` (u1): Represents the Stacks blockchain network ID.
* `CHAIN-ETHEREUM` (u2): Represents the Ethereum blockchain network ID.
* `CHAIN-POLYGON` (u3): Represents the Polygon blockchain network ID.
* `CHAIN-BITCOIN` (u4): Represents the Bitcoin blockchain network ID.

### Data Maps and Variables

* **`nft-listings` (map)**: Stores details of active, sold, or cancelled NFT listings.
    * **Key**: `{ token-id: uint, contract-address: principal }`
    * **Value**: `{ seller: principal, price: uint, currency: (string-ascii 10), listed-at: uint, expires-at: uint, cross-chain-enabled: bool, target-chain: uint, status: (string-ascii 20) }`
* **`cross-chain-escrow` (map)**: Manages details of pending cross-chain NFT transfers held in escrow.
    * **Key**: `{ escrow-id: uint }`
    * **Value**: `{ nft-contract: principal, token-id: uint, seller: principal, buyer: principal, price: uint, source-chain: uint, target-chain: uint, created-at: uint, status: (string-ascii 20) }`
* **`escrow-validators` (map)**: Tracks validator consensus for each escrow, including confirmations and dispute status.
    * **Key**: `{ escrow-id: uint }`
    * **Value**: `{ validators: (list 3 principal), confirmations: (list 3 principal), required-confirmations: uint, dispute-raised: bool, auto-release-height: uint, dispute-deadline: uint }`
* **`user-profiles` (map)**: Stores user-specific cross-chain addresses and reputation scores.
    * **Key**: `{ stacks-address: principal }`
    * **Value**: `{ ethereum-address: (optional (buff 20)), polygon-address: (optional (buff 20)), bitcoin-address: (optional (string-ascii 64)), reputation-score: uint, total-sales: uint, total-purchases: uint }`
* **`total-listings` (data-var)**: Counts the total number of NFTs ever listed.
* **`total-sales` (data-var)**: Tracks the total number of successful NFT sales.
* **`total-volume` (data-var)**: Accumulates the total value of all NFTs sold.
* **`escrow-counter` (data-var)**: Used to generate unique IDs for cross-chain escrows.
* **`marketplace-enabled` (data-var)**: A boolean flag to enable or disable marketplace operations.

### Private Functions

* `(calculate-fee (price uint))`: Calculates the marketplace fee for a given price.
* `(is-valid-chain (network-id uint))`: Checks if a given network ID corresponds to a supported blockchain.
* `(is-listing-active (expires-at uint))`: Determines if an NFT listing is still active based on the current block height.
* `(generate-escrow-id)`: Generates a unique identifier for new escrow records.
* `(update-user-stats (user principal) (is-seller bool) (amount uint))`: Updates the `reputation-score`, `total-sales`, and `total-purchases` for a user profile.

### Public Functions

* `(set-user-profile (ethereum-addr (optional (buff 20))) (polygon-addr (optional (buff 20))) (bitcoin-addr (optional (string-ascii 64))))`: Allows users to set or update their cross-chain addresses in their profile.
* `(list-nft (token-id uint) (contract-address principal) (price uint) (currency (string-ascii 10)) (duration uint) (cross-chain-enabled bool) (target-chain uint))`: Enables users to list an NFT for sale, specifying its price, currency, listing duration, and cross-chain capabilities.
* `(buy-nft (token-id uint) (contract-address principal) (payment uint))`: Facilitates the purchase of an NFT, handling payment transfers to the seller and marketplace fees to the contract owner.
* `(cancel-listing (token-id uint) (contract-address principal))`: Allows the seller to cancel an active NFT listing.
* `(get-listing (token-id uint) (contract-address principal))`: Retrieves the details of a specific NFT listing.
* `(get-user-profile (user principal))`: Fetches the profile information for a given user.
* `(get-marketplace-stats)`: Provides overall statistics for the marketplace, including total listings, sales, and volume.
* `(create-cross-chain-escrow (nft-contract principal) (token-id uint) (buyer principal) (price uint) (source-chain uint) (target-chain uint) (escrow-duration uint) (validator-addresses (list 3 principal)))`: Initiates a cross-chain escrow for an NFT, locking funds from the buyer and setting up validator consensus requirements.

### Error Codes

* `u100`: ERR-OWNER-ONLY
* `u101`: ERR-NOT-FOUND
* `u102`: ERR-UNAUTHORIZED
* `u103`: ERR-ALREADY-EXISTS
* `u104`: ERR-INSUFFICIENT-FUNDS
* `u105`: ERR-INVALID-PRICE
* `u106`: ERR-LISTING-EXPIRED
* `u107`: ERR-INVALID-CHAIN
* `u108`: ERR-ESCROW-LOCKED

---

## Getting Started

To interact with the `ChainBridge` contract, you'll need a Stacks development environment set up.

1.  **Clone the Repository**: (Assuming this contract is part of a larger project, or you'll host it somewhere)
    ```bash
    git clone [your-repository-url]
    cd chainbridge-nft-marketplace
    ```
2.  **Install Clarity Tools**: Ensure you have the Stacks CLI and Clarity development tools installed. Refer to the [Stacks documentation](https://docs.stacks.co/) for detailed instructions.
3.  **Deploy the Contract**: You can deploy this contract to a local devnet, testnet, or mainnet using the Stacks CLI or a suitable deployment tool.

---

## Usage

Here's a brief overview of how users and developers might interact with the `ChainBridge` contract:

1.  **Set Your Profile**:
    Before engaging in cross-chain trades, users can set their external blockchain addresses:
    ```clarity
    (set-user-profile (some 0x...) (some 0x...) (some "bc1q..."))
    ```
2.  **List an NFT**:
    Sellers can list their NFTs, specifying if they are cross-chain enabled and the target chain:
    ```clarity
    (list-nft u123 .my-nft-contract u1000 "STX" u1000 true u2)
    ```
    (This example lists NFT with ID `u123` from `.my-nft-contract` for `u1000` STX, for a duration of `u1000` blocks, enabled for cross-chain to Ethereum (`u2`)).
3.  **Buy an NFT**:
    Buyers can purchase listed NFTs:
    ```clarity
    (buy-nft u123 .my-nft-contract u1000)
    ```
4.  **Create a Cross-Chain Escrow**:
    For cross-chain transfers, the seller initiates an escrow:
    ```clarity
    (create-cross-chain-escrow
        .my-nft-contract   ;; NFT Contract
        u123               ;; Token ID
        ST1BJGTS8P6E5X447B9M6X7M9J54R5P7Q7B4Z3Y4T.buyer-principal ;; Buyer's Stacks address
        u900               ;; Price
        u1                 ;; Source Chain (Stacks)
        u2                 ;; Target Chain (Ethereum)
        u5000              ;; Escrow Duration (blocks)
        (list               ;; Validator Addresses
            ST1BJGTS8P6E5X447B9M6X7M9J54R5P7Q7B4Z3Y4T.validator-1
            ST1BJGTS8P6E5X447B9M6X7M9J54R5P7Q7B4Z3Y4T.validator-2
        )
    )
    ```
    (Note: Further functions for validator confirmations, dispute resolution, and escrow release would typically be built around this `create-cross-chain-escrow` function for a complete system.)

---

## Contributing

We welcome contributions to the ChainBridge project! If you're interested in improving the contract or adding new features, please follow these steps:

1.  **Fork the repository**.
2.  **Create a new branch** for your feature or bug fix: `git checkout -b feature/your-feature-name`.
3.  **Make your changes** and ensure they adhere to the Clarity best practices.
4.  **Write comprehensive tests** for your changes.
5.  **Commit your changes** with clear and concise messages.
6.  **Push your branch** to your forked repository.
7.  **Open a pull request** to the `main` branch of this repository, describing your changes in detail.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Contact

For any questions or inquiries, please open an issue in this repository.

---

## Acknowledgments

* The Clarity language and Stacks blockchain for providing the foundation.
* The open-source community for inspiration and tools.
