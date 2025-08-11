(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_INVALID_STATUS (err u403))
(define-constant ERR_ALREADY_CLAIMED (err u405))
(define-constant ERR_NOT_ELIGIBLE (err u406))

(define-non-fungible-token cotton-bale uint)

(define-data-var next-bale-id uint u1)
(define-data-var platform-fee uint u25)
(define-data-var quality-pool-balance uint u0)
(define-data-var reward-per-grade uint u100)

(define-map bale-data
  uint
  {
    farmer: principal,
    farm-location: (string-ascii 100),
    weight-kg: uint,
    quality-grade: (string-ascii 10),
    harvest-date: uint,
    lab-certified: bool,
    lab-report-hash: (string-ascii 64),
    price-per-kg: uint,
    status: (string-ascii 20)
  }
)

(define-map escrow-agreements
  uint
  {
    bale-id: uint,
    buyer: principal,
    seller: principal,
    total-amount: uint,
    status: (string-ascii 20),
    created-at: uint,
    deadline: uint
  }
)

(define-map user-ratings
  principal
  {
    total-score: uint,
    rating-count: uint,
    reputation: uint
  }
)

(define-map audit-trail
  uint
  {
    bale-id: uint,
    action: (string-ascii 50),
    actor: principal,
    timestamp: uint,
    details: (string-ascii 200)
  }
)

(define-map quality-rewards
  uint
  {
    bale-id: uint,
    farmer: principal,
    reward-amount: uint,
    claimed: bool,
    eligible-at: uint
  }
)

(define-data-var next-escrow-id uint u1)
(define-data-var next-audit-id uint u1)

(define-read-only (get-bale-data (bale-id uint))
  (map-get? bale-data bale-id)
)

(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrow-agreements escrow-id)
)

(define-read-only (get-user-rating (user principal))
  (default-to
    {total-score: u0, rating-count: u0, reputation: u0}
    (map-get? user-ratings user)
  )
)

(define-read-only (get-audit-entry (audit-id uint))
  (map-get? audit-trail audit-id)
)

(define-read-only (get-next-bale-id)
  (var-get next-bale-id)
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-read-only (get-quality-pool-balance)
  (var-get quality-pool-balance)
)

(define-read-only (get-quality-reward (reward-id uint))
  (map-get? quality-rewards reward-id)
)

(define-read-only (get-reward-per-grade)
  (var-get reward-per-grade)
)

(define-public (mint-cotton-bale 
  (farm-location (string-ascii 100))
  (weight-kg uint)
  (quality-grade (string-ascii 10))
  (harvest-date uint)
  (lab-certified bool)
  (lab-report-hash (string-ascii 64))
  (price-per-kg uint))
  (let ((bale-id (var-get next-bale-id)))
    (try! (nft-mint? cotton-bale bale-id tx-sender))
    (map-set bale-data bale-id {
      farmer: tx-sender,
      farm-location: farm-location,
      weight-kg: weight-kg,
      quality-grade: quality-grade,
      harvest-date: harvest-date,
      lab-certified: lab-certified,
      lab-report-hash: lab-report-hash,
      price-per-kg: price-per-kg,
      status: "available"
    })
    (unwrap-panic (add-audit-entry bale-id "minted" tx-sender "Cotton bale minted by farmer"))
    (unwrap-panic (check-quality-eligibility bale-id))
    (var-set next-bale-id (+ bale-id u1))
    (ok bale-id)
  )
)

(define-public (create-escrow 
  (bale-id uint)
  (deadline-blocks uint))
  (let (
    (bale (unwrap! (get-bale-data bale-id) ERR_NOT_FOUND))
    (escrow-id (var-get next-escrow-id))
    (total-amount (* (get weight-kg bale) (get price-per-kg bale)))
  )
    (asserts! (is-eq (get status bale) "available") ERR_INVALID_STATUS)
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq tx-sender (get farmer bale))) ERR_UNAUTHORIZED)
    
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    (map-set escrow-agreements escrow-id {
      bale-id: bale-id,
      buyer: tx-sender,
      seller: (get farmer bale),
      total-amount: total-amount,
      status: "pending",
      created-at: stacks-block-height,
      deadline: (+ stacks-block-height deadline-blocks)
    })
    
    (map-set bale-data bale-id 
      (merge bale {status: "in-escrow"})
    )
    
    (unwrap-panic (add-audit-entry bale-id "escrow-created" tx-sender "Escrow agreement created"))
    (var-set next-escrow-id (+ escrow-id u1))
    (ok escrow-id)
  )
)

(define-public (complete-escrow (escrow-id uint))
  (let (
    (escrow (unwrap! (get-escrow escrow-id) ERR_NOT_FOUND))
    (bale (unwrap! (get-bale-data (get bale-id escrow)) ERR_NOT_FOUND))
    (fee-amount (/ (* (get total-amount escrow) (var-get platform-fee)) u1000))
    (seller-amount (- (get total-amount escrow) fee-amount))
  )
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) "pending") ERR_INVALID_STATUS)
    
    (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller escrow))))
    (try! (as-contract (stx-transfer? fee-amount tx-sender CONTRACT_OWNER)))
    
    (try! (nft-transfer? cotton-bale (get bale-id escrow) (get seller escrow) (get buyer escrow)))
    
    (map-set escrow-agreements escrow-id
      (merge escrow {status: "completed"})
    )
    
    (map-set bale-data (get bale-id escrow)
      (merge bale {status: "sold"})
    )
    
    (unwrap-panic (add-audit-entry (get bale-id escrow) "escrow-completed" tx-sender "Escrow completed and bale transferred"))
    (ok true)
  )
)

(define-public (cancel-escrow (escrow-id uint))
  (let (
    (escrow (unwrap! (get-escrow escrow-id) ERR_NOT_FOUND))
    (bale (unwrap! (get-bale-data (get bale-id escrow)) ERR_NOT_FOUND))
  )
    (asserts! (or 
      (is-eq tx-sender (get buyer escrow))
      (is-eq tx-sender (get seller escrow))
      (> stacks-block-height (get deadline escrow))
    ) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) "pending") ERR_INVALID_STATUS)
    
    (try! (as-contract (stx-transfer? (get total-amount escrow) tx-sender (get buyer escrow))))
    
    (map-set escrow-agreements escrow-id
      (merge escrow {status: "cancelled"})
    )
    
    (map-set bale-data (get bale-id escrow)
      (merge bale {status: "available"})
    )
    
    (unwrap-panic (add-audit-entry (get bale-id escrow) "escrow-cancelled" tx-sender "Escrow cancelled and funds returned"))
    (ok true)
  )
)

(define-public (rate-user (user principal) (score uint))
  (let (
    (current-rating (get-user-rating user))
    (new-total-score (+ (get total-score current-rating) score))
    (new-count (+ (get rating-count current-rating) u1))
    (new-reputation (/ new-total-score new-count))
  )
    (asserts! (and (>= score u1) (<= score u5)) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq tx-sender user)) ERR_UNAUTHORIZED)
    
    (map-set user-ratings user {
      total-score: new-total-score,
      rating-count: new-count,
      reputation: new-reputation
    })
    
    (ok new-reputation)
  )
)

(define-public (update-bale-status (bale-id uint) (new-status (string-ascii 20)))
  (let ((bale (unwrap! (get-bale-data bale-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get farmer bale)) ERR_UNAUTHORIZED)
    (map-set bale-data bale-id
      (merge bale {status: new-status})
    )
    (unwrap-panic (add-audit-entry bale-id "status-updated" tx-sender new-status))
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee u100) ERR_INVALID_AMOUNT)
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (contribute-to-quality-pool (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set quality-pool-balance (+ (var-get quality-pool-balance) amount))
    (ok true)
  )
)

(define-public (claim-quality-reward (reward-id uint))
  (let (
    (reward (unwrap! (get-quality-reward reward-id) ERR_NOT_FOUND))
    (pool-balance (var-get quality-pool-balance))
  )
    (asserts! (is-eq tx-sender (get farmer reward)) ERR_UNAUTHORIZED)
    (asserts! (not (get claimed reward)) ERR_ALREADY_CLAIMED)
    (asserts! (>= stacks-block-height (get eligible-at reward)) ERR_NOT_ELIGIBLE)
    (asserts! (>= pool-balance (get reward-amount reward)) ERR_INSUFFICIENT_FUNDS)
    
    (try! (as-contract (stx-transfer? (get reward-amount reward) tx-sender (get farmer reward))))
    (var-set quality-pool-balance (- pool-balance (get reward-amount reward)))
    (map-set quality-rewards reward-id
      (merge reward {claimed: true})
    )
    (ok true)
  )
)

(define-public (set-reward-per-grade (new-reward uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-reward u0) ERR_INVALID_AMOUNT)
    (var-set reward-per-grade new-reward)
    (ok true)
  )
)

(define-private (add-audit-entry (bale-id uint) (action (string-ascii 50)) (actor principal) (details (string-ascii 200)))
  (let ((audit-id (var-get next-audit-id)))
    (map-set audit-trail audit-id {
      bale-id: bale-id,
      action: action,
      actor: actor,
      timestamp: stacks-block-height,
      details: details
    })
    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

(define-private (check-quality-eligibility (bale-id uint))
  (let (
    (bale (unwrap! (get-bale-data bale-id) ERR_NOT_FOUND))
    (reward-amount (calculate-quality-reward (get quality-grade bale) (get lab-certified bale)))
  )
    (if (> reward-amount u0)
      (begin
        (map-set quality-rewards bale-id {
          bale-id: bale-id,
          farmer: (get farmer bale),
          reward-amount: reward-amount,
          claimed: false,
          eligible-at: (+ stacks-block-height u144)
        })
        (ok true)
      )
      (ok false)
    )
  )
)

(define-private (calculate-quality-reward (grade (string-ascii 10)) (lab-certified bool))
  (let ((base-reward (var-get reward-per-grade)))
    (if lab-certified
      (if (is-eq grade "Grade A")
        (* base-reward u3)
        (if (is-eq grade "Grade B")
          (* base-reward u2)
          (if (is-eq grade "Grade C")
            base-reward
            u0
          )
        )
      )
      u0
    )
  )
)
