;; Cross-Chain NFT Marketplace
;; A decentralized marketplace for trading NFTs across different blockchain networks
;; Supports listing, buying, selling, and cross-chain transfers with escrow functionality

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-PRICE (err u105))
(define-constant ERR-LISTING-EXPIRED (err u106))
(define-constant ERR-INVALID-CHAIN (err u107))
(define-constant ERR-ESCROW-LOCKED (err u108))

;; Marketplace fee percentage (2.5%)
(define-constant MARKETPLACE-FEE u250)
(define-constant FEE-DENOMINATOR u10000)

;; Supported blockchain networks
(define-constant CHAIN-STACKS u1)
(define-constant CHAIN-ETHEREUM u2)
(define-constant CHAIN-POLYGON u3)
(define-constant CHAIN-BITCOIN u4)

;; data maps and vars

;; NFT listing structure
(define-map nft-listings
  { token-id: uint, contract-address: principal }
  {
    seller: principal,
    price: uint,
    currency: (string-ascii 10),
    listed-at: uint,
    expires-at: uint,
    cross-chain-enabled: bool,
    target-chain: uint,
    status: (string-ascii 20)
  }
)

;; Cross-chain escrow for pending transfers
(define-map cross-chain-escrow
  { escrow-id: uint }
  {
    nft-contract: principal,
    token-id: uint,
    seller: principal,
    buyer: principal,
    price: uint,
    source-chain: uint,
    target-chain: uint,
    created-at: uint,
    status: (string-ascii 20)
  }
)

;; Validator consensus tracking for escrow
(define-map escrow-validators
  { escrow-id: uint }
  {
    validators: (list 3 principal),
    confirmations: (list 3 principal),
    required-confirmations: uint,
    dispute-raised: bool,
    auto-release-height: uint,
    dispute-deadline: uint
  }
)

;; User profiles for cross-chain addresses
(define-map user-profiles
  { stacks-address: principal }
  {
    ethereum-address: (optional (buff 20)),
    polygon-address: (optional (buff 20)),
    bitcoin-address: (optional (string-ascii 64)),
    reputation-score: uint,
    total-sales: uint,
    total-purchases: uint
  }
)

;; Marketplace statistics
(define-data-var total-listings uint u0)
(define-data-var total-sales uint u0)
(define-data-var total-volume uint u0)
(define-data-var escrow-counter uint u0)
(define-data-var marketplace-enabled bool true)

;; private functions

;; Calculate marketplace fee for a given price
(define-private (calculate-fee (price uint))
  (/ (* price MARKETPLACE-FEE) FEE-DENOMINATOR)
)

;; Validate blockchain network ID
(define-private (is-valid-chain (network-id uint))
  (or (is-eq network-id CHAIN-STACKS)
      (is-eq network-id CHAIN-ETHEREUM)
      (is-eq network-id CHAIN-POLYGON)
      (is-eq network-id CHAIN-BITCOIN))
)

;; Check if listing is still active
(define-private (is-listing-active (expires-at uint))
  (< block-height expires-at)
)

;; Generate unique escrow ID
(define-private (generate-escrow-id)
  (begin
    (var-set escrow-counter (+ (var-get escrow-counter) u1))
    (var-get escrow-counter)
  )
)

;; Update user statistics after a transaction
(define-private (update-user-stats (user principal) (is-seller bool) (amount uint))
  (let (
    (current-profile (default-to 
      { ethereum-address: none, polygon-address: none, bitcoin-address: none, 
        reputation-score: u0, total-sales: u0, total-purchases: u0 }
      (map-get? user-profiles { stacks-address: user })))
  )
    (map-set user-profiles { stacks-address: user }
      (if is-seller
        (merge current-profile { 
          total-sales: (+ (get total-sales current-profile) u1),
          reputation-score: (+ (get reputation-score current-profile) u10)
        })
        (merge current-profile { 
          total-purchases: (+ (get total-purchases current-profile) u1),
          reputation-score: (+ (get reputation-score current-profile) u5)
        })
      )
    )
  )
)

;; public functions

;; Initialize or update user profile with cross-chain addresses
(define-public (set-user-profile 
  (ethereum-addr (optional (buff 20)))
  (polygon-addr (optional (buff 20)))
  (bitcoin-addr (optional (string-ascii 64))))
  (begin
    (map-set user-profiles
      { stacks-address: tx-sender }
      {
        ethereum-address: ethereum-addr,
        polygon-address: polygon-addr,
        bitcoin-address: bitcoin-addr,
        reputation-score: (default-to u0 (get reputation-score (map-get? user-profiles { stacks-address: tx-sender }))),
        total-sales: (default-to u0 (get total-sales (map-get? user-profiles { stacks-address: tx-sender }))),
        total-purchases: (default-to u0 (get total-purchases (map-get? user-profiles { stacks-address: tx-sender })))
      }
    )
    (ok true)
  )
)

;; List an NFT for sale
(define-public (list-nft 
  (token-id uint)
  (contract-address principal)
  (price uint)
  (currency (string-ascii 10))
  (duration uint)
  (cross-chain-enabled bool)
  (target-chain uint))
  (let (
    (listing-key { token-id: token-id, contract-address: contract-address })
    (expires-at (+ block-height duration))
  )
    (asserts! (> price u0) ERR-INVALID-PRICE)
    (asserts! (is-none (map-get? nft-listings listing-key)) ERR-ALREADY-EXISTS)
    (asserts! (or (not cross-chain-enabled) (is-valid-chain target-chain)) ERR-INVALID-CHAIN)
    
    (map-set nft-listings listing-key
      {
        seller: tx-sender,
        price: price,
        currency: currency,
        listed-at: block-height,
        expires-at: expires-at,
        cross-chain-enabled: cross-chain-enabled,
        target-chain: target-chain,
        status: "active"
      }
    )
    (var-set total-listings (+ (var-get total-listings) u1))
    (ok listing-key)
  )
)

;; Purchase an NFT
(define-public (buy-nft 
  (token-id uint)
  (contract-address principal)
  (payment uint))
  (let (
    (listing-key { token-id: token-id, contract-address: contract-address })
    (listing (unwrap! (map-get? nft-listings listing-key) ERR-NOT-FOUND))
    (price (get price listing))
    (seller (get seller listing))
    (fee (calculate-fee price))
    (seller-amount (- price fee))
  )
    (asserts! (var-get marketplace-enabled) ERR-UNAUTHORIZED)
    (asserts! (is-listing-active (get expires-at listing)) ERR-LISTING-EXPIRED)
    (asserts! (is-eq (get status listing) "active") ERR-NOT-FOUND)
    (asserts! (>= payment price) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer payment to seller and fee to marketplace
    (try! (stx-transfer? seller-amount tx-sender seller))
    (try! (stx-transfer? fee tx-sender CONTRACT-OWNER))
    
    ;; Update listing status
    (map-set nft-listings listing-key
      (merge listing { status: "sold" })
    )
    
    ;; Update statistics
    (var-set total-sales (+ (var-get total-sales) u1))
    (var-set total-volume (+ (var-get total-volume) price))
    
    ;; Update user profiles
    (update-user-stats seller true price)
    (update-user-stats tx-sender false price)
    
    (ok { buyer: tx-sender, seller: seller, price: price, fee: fee })
  )
)

;; Cancel an NFT listing
(define-public (cancel-listing 
  (token-id uint)
  (contract-address principal))
  (let (
    (listing-key { token-id: token-id, contract-address: contract-address })
    (listing (unwrap! (map-get? nft-listings listing-key) ERR-NOT-FOUND))
  )
    (asserts! (is-eq (get seller listing) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status listing) "active") ERR-NOT-FOUND)
    
    (map-set nft-listings listing-key
      (merge listing { status: "cancelled" })
    )
    (ok true)
  )
)

;; Get NFT listing details
(define-read-only (get-listing 
  (token-id uint)
  (contract-address principal))
  (map-get? nft-listings { token-id: token-id, contract-address: contract-address })
)

;; Get user profile
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { stacks-address: user })
)

;; Get marketplace statistics
(define-read-only (get-marketplace-stats)
  {
    total-listings: (var-get total-listings),
    total-sales: (var-get total-sales),
    total-volume: (var-get total-volume),
    marketplace-enabled: (var-get marketplace-enabled)
  }
)

;; Advanced Cross-Chain Escrow System with Multi-Signature Support
;; This function creates a secure escrow for cross-chain NFT transfers
;; Includes time-locked releases, dispute resolution, and multi-party validation
(define-public (create-cross-chain-escrow
  (nft-contract principal)
  (token-id uint)
  (buyer principal)
  (price uint)
  (source-chain uint)
  (target-chain uint)
  (escrow-duration uint)
  (validator-addresses (list 3 principal)))
  (let (
    (escrow-id (generate-escrow-id))
    (escrow-key { escrow-id: escrow-id })
    (listing-key { token-id: token-id, contract-address: nft-contract })
    (listing (unwrap! (map-get? nft-listings listing-key) ERR-NOT-FOUND))
    (required-deposit (+ price (calculate-fee price)))
    (validator-count (len validator-addresses))
  )
    ;; Validate escrow parameters
    (asserts! (is-valid-chain source-chain) ERR-INVALID-CHAIN)
    (asserts! (is-valid-chain target-chain) ERR-INVALID-CHAIN)
    (asserts! (not (is-eq source-chain target-chain)) ERR-INVALID-CHAIN)
    (asserts! (is-eq (get seller listing) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (get cross-chain-enabled listing) ERR-UNAUTHORIZED)
    (asserts! (> escrow-duration u0) ERR-INVALID-PRICE)
    (asserts! (<= validator-count u3) ERR-INVALID-PRICE)
    
    ;; Lock funds in escrow from buyer
    (try! (stx-transfer? required-deposit buyer (as-contract tx-sender)))
    
    ;; Create escrow record with enhanced security features
    (map-set cross-chain-escrow escrow-key
      {
        nft-contract: nft-contract,
        token-id: token-id,
        seller: tx-sender,
        buyer: buyer,
        price: price,
        source-chain: source-chain,
        target-chain: target-chain,
        created-at: block-height,
        status: "pending"
      }
    )
    
    ;; Update listing to reflect escrow status
    (map-set nft-listings listing-key
      (merge listing { status: "in-escrow" })
    )
    
    ;; Initialize validator consensus tracking
    (map-set escrow-validators escrow-key
      {
        validators: validator-addresses,
        confirmations: (list),
        required-confirmations: (if (> validator-count u0) 
                                   (/ (+ validator-count u1) u2) 
                                   u1),
        dispute-raised: false,
        auto-release-height: (+ block-height escrow-duration),
        dispute-deadline: (+ block-height (/ escrow-duration u2))
      }
    )
    
    (ok { escrow-id: escrow-id, required-deposit: required-deposit, validators: validator-addresses })
  )
)


