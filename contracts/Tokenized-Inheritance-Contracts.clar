(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-initialized (err u101))
(define-constant err-not-initialized (err u102))
(define-constant err-invalid-heir (err u103))
(define-constant err-no-inheritance (err u104))
(define-constant err-not-heir (err u105))
(define-constant err-still-active (err u106))

(define-data-var last-activity uint u0)
(define-data-var inactivity-period uint u0)

(define-map inheritances
    { owner: principal }
    {
        heir: principal,
        amount: uint,
        asset-type: (string-ascii 10),
    }
)

(define-public (initialize-inheritance
        (heir principal)
        (amount uint)
        (asset-type (string-ascii 10))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? inheritances { owner: tx-sender }))
            err-already-initialized
        )
        (map-set inheritances { owner: tx-sender } {
            heir: heir,
            amount: amount,
            asset-type: asset-type,
        })
        (var-set last-activity burn-block-height)
        (ok true)
    )
)

(define-public (set-inactivity-period (blocks uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set inactivity-period blocks)
        (ok true)
    )
)

(define-public (update-activity)
    (begin
        (asserts! (is-some (map-get? inheritances { owner: tx-sender }))
            err-not-initialized
        )
        (var-set last-activity burn-block-height)
        (ok true)
    )
)

(define-public (update-heir (new-heir principal))
    (let ((inheritance (unwrap! (map-get? inheritances { owner: tx-sender }) err-not-initialized)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (map-set inheritances { owner: tx-sender }
                (merge inheritance { heir: new-heir })
            )
            (ok true)
        )
    )
)

(define-public (update-amount (new-amount uint))
    (let ((inheritance (unwrap! (map-get? inheritances { owner: tx-sender }) err-not-initialized)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (map-set inheritances { owner: tx-sender }
                (merge inheritance { amount: new-amount })
            )
            (ok true)
        )
    )
)

(define-read-only (get-inheritance (owner principal))
    (map-get? inheritances { owner: owner })
)

(define-read-only (check-inactivity (owner principal))
    (let (
            (inheritance (unwrap! (map-get? inheritances { owner: owner }) err-not-initialized))
            (inactive-blocks (- burn-block-height (var-get last-activity)))
        )
        (if (>= inactive-blocks (var-get inactivity-period))
            (ok true)
            err-still-active
        )
    )
)

(define-public (claim-inheritance (owner principal))
    (let (
            (inheritance (unwrap! (map-get? inheritances { owner: owner }) err-no-inheritance))
            (inactive-blocks (- burn-block-height (var-get last-activity)))
        )
        (begin
            (asserts! (is-eq (get heir inheritance) tx-sender) err-not-heir)
            (asserts! (>= inactive-blocks (var-get inactivity-period))
                err-still-active
            )
            (map-delete inheritances { owner: owner })
            (ok true)
        )
    )
)
