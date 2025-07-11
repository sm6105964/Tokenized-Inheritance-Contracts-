(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-initialized (err u101))
(define-constant err-not-initialized (err u102))
(define-constant err-invalid-heir (err u103))
(define-constant err-no-inheritance (err u104))
(define-constant err-not-heir (err u105))
(define-constant err-still-active (err u106))
(define-constant err-invalid-percentage (err u107))
(define-constant err-not-beneficiary (err u108))

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

(define-map multi-beneficiaries
    { owner: principal, beneficiary: principal }
    {
        percentage: uint,
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

(define-public (setup-multi-beneficiary
        (beneficiary principal)
        (percentage uint)
        (amount uint)
        (asset-type (string-ascii 10))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (and (>= percentage u1) (<= percentage u100)) err-invalid-percentage)
        (map-set multi-beneficiaries 
            { owner: tx-sender, beneficiary: beneficiary }
            {
                percentage: percentage,
                amount: amount,
                asset-type: asset-type,
            }
        )
        (var-set last-activity burn-block-height)
        (ok true)
    )
)

(define-public (update-beneficiary-percentage 
        (beneficiary principal)
        (new-percentage uint)
    )
    (let ((beneficiary-data (unwrap! (map-get? multi-beneficiaries { owner: tx-sender, beneficiary: beneficiary }) err-not-beneficiary)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (asserts! (and (>= new-percentage u1) (<= new-percentage u100)) err-invalid-percentage)
            (map-set multi-beneficiaries 
                { owner: tx-sender, beneficiary: beneficiary }
                (merge beneficiary-data { percentage: new-percentage })
            )
            (ok true)
        )
    )
)

(define-public (claim-multi-beneficiary-inheritance (owner principal))
    (let (
            (beneficiary-data (unwrap! (map-get? multi-beneficiaries { owner: owner, beneficiary: tx-sender }) err-not-beneficiary))
            (inactive-blocks (- burn-block-height (var-get last-activity)))
        )
        (begin
            (asserts! (>= inactive-blocks (var-get inactivity-period)) err-still-active)
            (map-delete multi-beneficiaries { owner: owner, beneficiary: tx-sender })
            (ok true)
        )
    )
)

(define-read-only (get-beneficiary-info (owner principal) (beneficiary principal))
    (map-get? multi-beneficiaries { owner: owner, beneficiary: beneficiary })
)

(define-read-only (calculate-beneficiary-amount (owner principal) (beneficiary principal) (total-amount uint))
    (let ((beneficiary-data (unwrap! (map-get? multi-beneficiaries { owner: owner, beneficiary: beneficiary }) err-not-beneficiary)))
        (ok (/ (* total-amount (get percentage beneficiary-data)) u100))
    )
)
