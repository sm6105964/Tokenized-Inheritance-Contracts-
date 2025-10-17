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
(define-constant err-not-emergency-contact (err u109))
(define-constant err-challenge-period-active (err u110))
(define-constant err-no-challenge-exists (err u111))
(define-constant err-no-vesting-schedule (err u112))
(define-constant err-vesting-not-active (err u113))
(define-constant err-no-claimable-amount (err u114))
(define-constant err-not-recovery-agent (err u115))
(define-constant err-recovery-period-not-met (err u116))
(define-constant err-escrow-not-found (err u117))
(define-constant err-not-escrow-party (err u118))
(define-constant err-escrow-already-released (err u119))
(define-constant err-escrow-conditions-not-met (err u120))
(define-constant err-invalid-escrow-amount (err u121))
(define-constant err-escrow-expired (err u122))
(define-constant err-escrow-not-expired (err u123))
(define-constant recovery-period-multiplier u3)

(define-data-var last-activity uint u0)
(define-data-var inactivity-period uint u0)
(define-data-var challenge-period uint u144)
(define-data-var escrow-counter uint u0)

(define-map inheritances
    { owner: principal }
    {
        heir: principal,
        amount: uint,
        asset-type: (string-ascii 10),
    }
)

(define-map multi-beneficiaries
    {
        owner: principal,
        beneficiary: principal,
    }
    {
        percentage: uint,
        amount: uint,
        asset-type: (string-ascii 10),
    }
)

(define-map emergency-contacts
    {
        owner: principal,
        contact: principal,
    }
    { active: bool }
)

(define-map inheritance-challenges
    {
        owner: principal,
        challenger: principal,
    }
    {
        challenge-block: uint,
        heir: principal,
        challenge-reason: (string-ascii 50),
    }
)

(define-map vesting-schedules
    { owner: principal }
    {
        total-amount: uint,
        start-block: uint,
        cliff-period: uint,
        vesting-period: uint,
        claimed-amount: uint,
        asset-type: (string-ascii 10),
        heir: principal,
    }
)

(define-map recovery-agents
    {
        owner: principal,
        agent: principal,
    }
    { active: bool }
)

;; Asset Escrow System Maps
(define-map escrow-agreements
    { escrow-id: uint }
    {
        payer: principal,
        payee: principal,
        amount: uint,
        asset-type: (string-ascii 20),
        conditions: (string-ascii 100),
        expiry-block: uint,
        status: (string-ascii 10),
        created-block: uint,
        released-block: (optional uint)
    }
)

(define-map escrow-disputes
    { escrow-id: uint }
    {
        disputer: principal,
        reason: (string-ascii 100),
        dispute-block: uint,
        resolved: bool
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
        (asserts! (and (>= percentage u1) (<= percentage u100))
            err-invalid-percentage
        )
        (map-set multi-beneficiaries {
            owner: tx-sender,
            beneficiary: beneficiary,
        } {
            percentage: percentage,
            amount: amount,
            asset-type: asset-type,
        })
        (var-set last-activity burn-block-height)
        (ok true)
    )
)

(define-public (update-beneficiary-percentage
        (beneficiary principal)
        (new-percentage uint)
    )
    (let ((beneficiary-data (unwrap!
            (map-get? multi-beneficiaries {
                owner: tx-sender,
                beneficiary: beneficiary,
            })
            err-not-beneficiary
        )))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (asserts! (and (>= new-percentage u1) (<= new-percentage u100))
                err-invalid-percentage
            )
            (map-set multi-beneficiaries {
                owner: tx-sender,
                beneficiary: beneficiary,
            }
                (merge beneficiary-data { percentage: new-percentage })
            )
            (ok true)
        )
    )
)

(define-public (claim-multi-beneficiary-inheritance (owner principal))
    (let (
            (beneficiary-data (unwrap!
                (map-get? multi-beneficiaries {
                    owner: owner,
                    beneficiary: tx-sender,
                })
                err-not-beneficiary
            ))
            (inactive-blocks (- burn-block-height (var-get last-activity)))
        )
        (begin
            (asserts! (>= inactive-blocks (var-get inactivity-period))
                err-still-active
            )
            (map-delete multi-beneficiaries {
                owner: owner,
                beneficiary: tx-sender,
            })
            (ok true)
        )
    )
)

(define-read-only (get-beneficiary-info
        (owner principal)
        (beneficiary principal)
    )
    (map-get? multi-beneficiaries {
        owner: owner,
        beneficiary: beneficiary,
    })
)

(define-read-only (calculate-beneficiary-amount
        (owner principal)
        (beneficiary principal)
        (total-amount uint)
    )
    (let ((beneficiary-data (unwrap!
            (map-get? multi-beneficiaries {
                owner: owner,
                beneficiary: beneficiary,
            })
            err-not-beneficiary
        )))
        (ok (/ (* total-amount (get percentage beneficiary-data)) u100))
    )
)

(define-public (designate-emergency-contact (contact principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set emergency-contacts {
            owner: tx-sender,
            contact: contact,
        } { active: true }
        )
        (ok true)
    )
)

(define-public (revoke-emergency-contact (contact principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete emergency-contacts {
            owner: tx-sender,
            contact: contact,
        })
        (ok true)
    )
)

(define-public (challenge-inheritance
        (owner principal)
        (reason (string-ascii 50))
    )
    (let (
            (inheritance (unwrap! (map-get? inheritances { owner: owner }) err-not-initialized))
            (contact-data (unwrap!
                (map-get? emergency-contacts {
                    owner: owner,
                    contact: tx-sender,
                })
                err-not-emergency-contact
            ))
        )
        (begin
            (asserts! (get active contact-data) err-not-emergency-contact)
            (map-set inheritance-challenges {
                owner: owner,
                challenger: tx-sender,
            } {
                challenge-block: burn-block-height,
                heir: (get heir inheritance),
                challenge-reason: reason,
            })
            (ok true)
        )
    )
)

(define-public (resolve-challenge
        (owner principal)
        (challenger principal)
    )
    (let ((challenge-data (unwrap!
            (map-get? inheritance-challenges {
                owner: owner,
                challenger: challenger,
            })
            err-no-challenge-exists
        )))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (map-delete inheritance-challenges {
                owner: owner,
                challenger: challenger,
            })
            (var-set last-activity burn-block-height)
            (ok true)
        )
    )
)

(define-public (claim-inheritance-with-deadman-switch (owner principal))
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

(define-read-only (get-active-challenge (owner principal))
    (ok none)
)

(define-read-only (get-emergency-contact
        (owner principal)
        (contact principal)
    )
    (map-get? emergency-contacts {
        owner: owner,
        contact: contact,
    })
)

(define-read-only (get-challenge-info
        (owner principal)
        (challenger principal)
    )
    (map-get? inheritance-challenges {
        owner: owner,
        challenger: challenger,
    })
)

(define-public (create-vesting-schedule
        (heir principal)
        (total-amount uint)
        (cliff-period uint)
        (vesting-period uint)
        (asset-type (string-ascii 10))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? vesting-schedules { owner: tx-sender }))
            err-already-initialized
        )
        (map-set vesting-schedules { owner: tx-sender } {
            total-amount: total-amount,
            start-block: burn-block-height,
            cliff-period: cliff-period,
            vesting-period: vesting-period,
            claimed-amount: u0,
            asset-type: asset-type,
            heir: heir,
        })
        (var-set last-activity burn-block-height)
        (ok true)
    )
)

(define-read-only (calculate-vested-amount (owner principal))
    (let (
            (schedule (unwrap! (map-get? vesting-schedules { owner: owner })
                err-no-vesting-schedule
            ))
            (inactive-blocks (- burn-block-height (var-get last-activity)))
            (elapsed-blocks (- burn-block-height (get start-block schedule)))
            (cliff-blocks (get cliff-period schedule))
            (vesting-blocks (get vesting-period schedule))
            (total-amount (get total-amount schedule))
        )
        (if (>= inactive-blocks (var-get inactivity-period))
            (if (< elapsed-blocks cliff-blocks)
                (ok u0)
                (if (>= elapsed-blocks (+ cliff-blocks vesting-blocks))
                    (ok total-amount)
                    (let ((vesting-progress (- elapsed-blocks cliff-blocks)))
                        (ok (/ (* total-amount vesting-progress) vesting-blocks))
                    )
                )
            )
            err-vesting-not-active
        )
    )
)

(define-read-only (get-claimable-amount (owner principal))
    (let (
            (schedule (unwrap! (map-get? vesting-schedules { owner: owner })
                err-no-vesting-schedule
            ))
            (vested-amount (unwrap! (calculate-vested-amount owner) err-vesting-not-active))
            (claimed-amount (get claimed-amount schedule))
        )
        (if (> vested-amount claimed-amount)
            (ok (- vested-amount claimed-amount))
            (ok u0)
        )
    )
)

(define-public (claim-vested-inheritance (owner principal))
    (let (
            (schedule (unwrap! (map-get? vesting-schedules { owner: owner })
                err-no-vesting-schedule
            ))
            (claimable-amount (unwrap! (get-claimable-amount owner) err-no-claimable-amount))
            (current-claimed (get claimed-amount schedule))
        )
        (begin
            (asserts! (is-eq (get heir schedule) tx-sender) err-not-heir)
            (asserts! (> claimable-amount u0) err-no-claimable-amount)
            (map-set vesting-schedules { owner: owner }
                (merge schedule { claimed-amount: (+ current-claimed claimable-amount) })
            )
            (ok claimable-amount)
        )
    )
)

(define-read-only (get-vesting-schedule (owner principal))
    (map-get? vesting-schedules { owner: owner })
)

(define-public (designate-recovery-agent (agent principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set recovery-agents {
            owner: tx-sender,
            agent: agent,
        } { active: true }
        )
        (ok true)
    )
)

(define-public (revoke-recovery-agent (agent principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete recovery-agents {
            owner: tx-sender,
            agent: agent,
        })
        (ok true)
    )
)

(define-read-only (check-recovery-eligibility (owner principal))
    (let (
            (inheritance (unwrap! (map-get? inheritances { owner: owner }) err-not-initialized))
            (inactive-blocks (- burn-block-height (var-get last-activity)))
            (required-period (* (var-get inactivity-period) recovery-period-multiplier))
        )
        (if (>= inactive-blocks required-period)
            (ok true)
            err-recovery-period-not-met
        )
    )
)

(define-public (recovery-claim-inheritance (owner principal))
    (let (
            (inheritance (unwrap! (map-get? inheritances { owner: owner }) err-no-inheritance))
            (agent-data (unwrap!
                (map-get? recovery-agents {
                    owner: owner,
                    agent: tx-sender,
                })
                err-not-recovery-agent
            ))
            (inactive-blocks (- burn-block-height (var-get last-activity)))
            (required-period (* (var-get inactivity-period) recovery-period-multiplier))
        )
        (begin
            (asserts! (get active agent-data) err-not-recovery-agent)
            (asserts! (>= inactive-blocks required-period)
                err-recovery-period-not-met
            )
            (map-delete inheritances { owner: owner })
            (ok true)
        )
    )
)

(define-public (recovery-claim-vesting (owner principal))
    (let (
            (schedule (unwrap! (map-get? vesting-schedules { owner: owner })
                err-no-vesting-schedule
            ))
            (agent-data (unwrap!
                (map-get? recovery-agents {
                    owner: owner,
                    agent: tx-sender,
                })
                err-not-recovery-agent
            ))
            (inactive-blocks (- burn-block-height (var-get last-activity)))
            (required-period (* (var-get inactivity-period) recovery-period-multiplier))
        )
        (begin
            (asserts! (get active agent-data) err-not-recovery-agent)
            (asserts! (>= inactive-blocks required-period)
                err-recovery-period-not-met
            )
            (map-delete vesting-schedules { owner: owner })
            (ok (get total-amount schedule))
        )
    )
)

(define-read-only (get-recovery-agent
        (owner principal)
        (agent principal)
    )
    (map-get? recovery-agents {
        owner: owner,
        agent: agent,
    })
)

;; Asset Escrow System Functions
(define-public (create-escrow-agreement
        (payee principal)
        (amount uint)
        (asset-type (string-ascii 20))
        (conditions (string-ascii 100))
        (expiry-blocks uint)
    )
    (let ((new-escrow-id (+ (var-get escrow-counter) u1)))
        (begin
            (asserts! (> amount u0) err-invalid-escrow-amount)
            (asserts! (> expiry-blocks u0) err-invalid-escrow-amount)
            (asserts! (not (is-eq tx-sender payee)) err-invalid-heir)
            (map-set escrow-agreements { escrow-id: new-escrow-id } {
                payer: tx-sender,
                payee: payee,
                amount: amount,
                asset-type: asset-type,
                conditions: conditions,
                expiry-block: (+ burn-block-height expiry-blocks),
                status: "active",
                created-block: burn-block-height,
                released-block: none
            })
            (var-set escrow-counter new-escrow-id)
            (ok new-escrow-id)
        )
    )
)

(define-public (release-escrow (escrow-id uint))
    (let ((escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id })
            err-escrow-not-found
        )))
        (begin
            (asserts! (or (is-eq tx-sender (get payer escrow-data))
                         (is-eq tx-sender (get payee escrow-data)))
                err-not-escrow-party
            )
            (asserts! (is-eq (get status escrow-data) "active")
                err-escrow-already-released
            )
            (map-set escrow-agreements { escrow-id: escrow-id }
                (merge escrow-data {
                    status: "released",
                    released-block: (some burn-block-height)
                })
            )
            (ok true)
        )
    )
)

(define-public (claim-expired-escrow (escrow-id uint))
    (let ((escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id })
            err-escrow-not-found
        )))
        (begin
            (asserts! (is-eq tx-sender (get payer escrow-data)) err-not-escrow-party)
            (asserts! (is-eq (get status escrow-data) "active") err-escrow-already-released)
            (asserts! (>= burn-block-height (get expiry-block escrow-data))
                err-escrow-not-expired
            )
            (map-set escrow-agreements { escrow-id: escrow-id }
                (merge escrow-data {
                    status: "expired",
                    released-block: (some burn-block-height)
                })
            )
            (ok true)
        )
    )
)

(define-public (dispute-escrow
        (escrow-id uint)
        (reason (string-ascii 100))
    )
    (let ((escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id })
            err-escrow-not-found
        )))
        (begin
            (asserts! (or (is-eq tx-sender (get payer escrow-data))
                         (is-eq tx-sender (get payee escrow-data)))
                err-not-escrow-party
            )
            (asserts! (is-eq (get status escrow-data) "active")
                err-escrow-already-released
            )
            (map-set escrow-disputes { escrow-id: escrow-id } {
                disputer: tx-sender,
                reason: reason,
                dispute-block: burn-block-height,
                resolved: false
            })
            (map-set escrow-agreements { escrow-id: escrow-id }
                (merge escrow-data { status: "disputed" })
            )
            (ok true)
        )
    )
)

(define-public (resolve-escrow-dispute
        (escrow-id uint)
        (release-to-payee bool)
    )
    (let (
            (escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id })
                err-escrow-not-found
            ))
            (dispute-data (unwrap! (map-get? escrow-disputes { escrow-id: escrow-id })
                err-escrow-not-found
            ))
        )
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (asserts! (is-eq (get status escrow-data) "disputed")
                err-escrow-conditions-not-met
            )
            (map-set escrow-disputes { escrow-id: escrow-id }
                (merge dispute-data { resolved: true })
            )
            (map-set escrow-agreements { escrow-id: escrow-id }
                (merge escrow-data {
                    status: (if release-to-payee "released" "cancelled"),
                    released-block: (some burn-block-height)
                })
            )
            (ok release-to-payee)
        )
    )
)

(define-read-only (get-escrow-details (escrow-id uint))
    (map-get? escrow-agreements { escrow-id: escrow-id })
)

(define-read-only (get-escrow-dispute (escrow-id uint))
    (map-get? escrow-disputes { escrow-id: escrow-id })
)

(define-read-only (check-escrow-expiry (escrow-id uint))
    (let ((escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id })
            err-escrow-not-found
        )))
        (if (>= burn-block-height (get expiry-block escrow-data))
            (ok true)
            (ok false)
        )
    )
)

(define-read-only (get-active-escrows-count)
    (ok (var-get escrow-counter))
)
