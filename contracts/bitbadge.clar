;; implementing our trait with the `impl-trait` line. This is pointing to the deployed trait that was listed earlier. 
;; This tells our contract it has to have the defined functions to be considered valid.
(impl-trait 'ST3QFME3CANQFQNR86TYVKQYCFT7QX4PRXM1V9W6H.sip009-nft-trait.sip009-nft-trait)

;; defining a bunch of constants responsible for handling different errors in our functions.
;; we assign a number as an error type to a specific constant so we can easily reference it in our code
;; If we were to call a function and it encountered one of these errors, that number would be returned to 
;; us so we can react appropriately in our UI.
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-not-found (err u102))
(define-constant err-unsupported-tx (err u103))
(define-constant err-out-not-found (err u104))
(define-constant err-in-not-found (err u105))
(define-constant err-tx-not-mined (err u106))

;; defining our NFT with the `define-non-fungible-token` function call. 
;; This is one of the built-in functions for working with NFTs.
(define-non-fungible-token bitbadge uint)

;; defining a variable called `last-token-id` which is responsible for maintaining the id of the last token 
;; that was minted. This is necessary to ensure that each token has a unique identifier and is what we'll 
;; be referencing in order to implement the `get-last-token-id` function from our trait.
(define-data-var last-token-id uint u0)

;; This is a basic getter function that retrieves the value of that variable using `var-get`.
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

;; The first would normally be used to get the URI of our actual NFT. 
(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

;; getting the owner using Clarity's built-in `nft-get-owner?` function. That function takes in the 
;; identifier and the specific token id and will return a principal of the current owner.
(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? bitbadge token-id))
)

;; This function takes in the token-id, sender, and recipient.
;; The first thing it does is open a begin block so we can pass multiple expressions. 
;; It next checks that the person sending the transaction is the person sending the NFT and returns 
;; an error if not. This prevents someone who does not own the NFT from transferring it to someone else.
;; Finally it runs the built-in `nft-transfer?` function which takes the token name, id, sender and recipient.
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? bitbadge token-id sender recipient)
    )
)

;; basic mint function which simply takes in the recipient and mints the NFT.
;; This `let` line functions much like `begin`, except that it first allows us to set a 
;; context-dependent variable to use throughout the function. In this case we are determining 
;; which id this NFT should be minted with by adding 1 to the last id.
;; Then we are using a `try!` function to call Clarity's built-in `nft-mint?` function and mint a 
;; new NFT to whoever was passed in as the recipient.
;; Finally we set the new last-token-id and return a success response with the new id.
(define-public (mint (recipient principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (nft-mint? bitbadge token-id recipient))
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

;; we've modified our function parameters to include some information about our Bitcoin transaction.
;; The other crucial line is that we've added another new variable to our `let` declaration called `tx-was-mined`. 
;; This calls the Clarity Bitcoin library `was-tx-mined` function and will be set to true if the transaction was 
;; mined, and false if it wasn't.
(define-public (_mint (recipient principal) (height uint) (tx (buff 1024)) (header (buff 80)) (proof { tx-index: uint, hashes: (list 14 (buff 32)), tree-depth: uint}))
    (let
    ;; We then check for this as the first line after the `let` declarations to make sure the transaction actually 
    ;; occurred before allowing the user to mint.
    ;; We're passing in the block height to tell the library what Bitcoin block it should be looking at, the raw 
    ;; transaction hex, the header hash, and the Merkle proof of the transaction itself.
    ;; We are specifically using the `was-tx-mined-compact` function, which allows us to pass in the header hash 
    ;; instead of the header data individually.
        (
            (token-id (+ (var-get last-token-id) u1))
            (tx-was-mined (try! (contract-call? 'ST3QFME3CANQFQNR86TYVKQYCFT7QX4PRXM1V9W6H.clarity-bitcoin-bitbadge-v3 was-tx-mined-compact height tx header proof)))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq tx-was-mined true) err-tx-not-mined)
        (try! (nft-mint? bitbadge token-id recipient))
        (var-set last-token-id token-id)
        (ok token-id)
    )
    ;; we've just added the ability to verify a Bitcoin transaction occurred before minting our NFT using only 
    ;; a few lines of code.
)