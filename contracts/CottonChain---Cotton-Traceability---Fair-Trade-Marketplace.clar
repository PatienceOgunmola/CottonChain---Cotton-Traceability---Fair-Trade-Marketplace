(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_INVALID_STATUS (err u403))
(define-constant ERR_ALREADY_CLAIMED (err u405))
(define-constant ERR_NOT_ELIGIBLE (err u406))
(define-constant ERR_DISPUTE_EXISTS (err u407))
(define-constant ERR_DISPUTE_NOT_FOUND (err u408))
(define-constant ERR_DISPUTE_RESOLVED (err u409))

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

(define-map disputes
  uint
  {
    escrow-id: uint,
    initiator: principal,
    reason: (string-ascii 200),
    status: (string-ascii 20),
    created-at: uint,
    resolved-at: (optional uint)
  }
)

(define-data-var next-escrow-id uint u1)
(define-data-var next-audit-id uint u1)
(define-data-var next-dispute-id uint u1)

(define-map bale-transfers
  uint
  {
    bale-id: uint,
    from: principal,
    to: principal,
    transfer-type: (string-ascii 20),
    timestamp: uint,
    notes: (string-ascii 200)
  }
)

(define-data-var next-transfer-id uint u1)

(define-read-only (get-bale-transfer (transfer-id uint))
  (map-get? bale-transfers transfer-id)
)

(define-public (transfer-bale-ownership (bale-id uint) (new-owner principal) (transfer-type (string-ascii 20)) (notes (string-ascii 200)))
  (let (
    (bale (unwrap! (get-bale-data bale-id) ERR_NOT_FOUND))
    (transfer-id (var-get next-transfer-id))
  )
    (asserts! (is-eq tx-sender (get farmer bale)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq new-owner tx-sender)) ERR_INVALID_AMOUNT)
    (try! (nft-transfer? cotton-bale bale-id tx-sender new-owner))
    (map-set bale-data bale-id
      (merge bale {farmer: new-owner})
    )
    (map-set bale-transfers transfer-id {
      bale-id: bale-id,
      from: tx-sender,
      to: new-owner,
      transfer-type: transfer-type,
      timestamp: stacks-block-height,
      notes: notes
    })
    (unwrap-panic (add-audit-entry bale-id "ownership-transferred" tx-sender "Bale ownership transferred"))
    (var-set next-transfer-id (+ transfer-id u1))
    (ok transfer-id)
  )
)

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

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id)
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

(define-private (mint-single (bale {farm-location: (string-ascii 100), weight-kg: uint, quality-grade: (string-ascii 10), harvest-date: uint, lab-certified: bool, lab-report-hash: (string-ascii 64), price-per-kg: uint}))
  (let ((bale-id (var-get next-bale-id)))
    (unwrap-panic (nft-mint? cotton-bale bale-id tx-sender))
    (map-set bale-data bale-id {
      farmer: tx-sender,
      farm-location: (get farm-location bale),
      weight-kg: (get weight-kg bale),
      quality-grade: (get quality-grade bale),
      harvest-date: (get harvest-date bale),
      lab-certified: (get lab-certified bale),
      lab-report-hash: (get lab-report-hash bale),
      price-per-kg: (get price-per-kg bale),
      status: "available"
    })
    (unwrap-panic (add-audit-entry bale-id "minted" tx-sender "Cotton bale minted by farmer"))
    (unwrap-panic (check-quality-eligibility bale-id))
    (var-set next-bale-id (+ bale-id u1))
    bale-id
  )
)

(define-public (batch-mint-cotton-bales (bales (list 10 {farm-location: (string-ascii 100), weight-kg: uint, quality-grade: (string-ascii 10), harvest-date: uint, lab-certified: bool, lab-report-hash: (string-ascii 64), price-per-kg: uint})))
  (let ((len (len bales)))
    (if (is-eq len u0)
      (ok (list ))
      (let ((id1 (mint-single (unwrap-panic (element-at bales u0)))))
        (if (is-eq len u1)
          (ok (list id1))
          (let ((id2 (mint-single (unwrap-panic (element-at bales u1)))))
            (if (is-eq len u2)
              (ok (list id1 id2))
              (let ((id3 (mint-single (unwrap-panic (element-at bales u2)))))
                (if (is-eq len u3)
                  (ok (list id1 id2 id3))
                  (let ((id4 (mint-single (unwrap-panic (element-at bales u3)))))
                    (if (is-eq len u4)
                      (ok (list id1 id2 id3 id4))
                      (let ((id5 (mint-single (unwrap-panic (element-at bales u4)))))
                        (if (is-eq len u5)
                          (ok (list id1 id2 id3 id4 id5))
                          (let ((id6 (mint-single (unwrap-panic (element-at bales u5)))))
                            (if (is-eq len u6)
                              (ok (list id1 id2 id3 id4 id5 id6))
                              (let ((id7 (mint-single (unwrap-panic (element-at bales u6)))))
                                (if (is-eq len u7)
                                  (ok (list id1 id2 id3 id4 id5 id6 id7))
                                  (let ((id8 (mint-single (unwrap-panic (element-at bales u7)))))
                                    (if (is-eq len u8)
                                      (ok (list id1 id2 id3 id4 id5 id6 id7 id8))
                                      (let ((id9 (mint-single (unwrap-panic (element-at bales u8)))))
                                        (if (is-eq len u9)
                                          (ok (list id1 id2 id3 id4 id5 id6 id7 id8 id9))
                                          (let ((id10 (mint-single (unwrap-panic (element-at bales u9)))))
                                            (ok (list id1 id2 id3 id4 id5 id6 id7 id8 id9 id10))
                                          )
                                        )
                                      )
                                    )
                                  )
                                )
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
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

(define-public (initiate-dispute (escrow-id uint) (reason (string-ascii 200)))
  (let (
    (escrow (unwrap! (get-escrow escrow-id) ERR_NOT_FOUND))
    (dispute-id (var-get next-dispute-id))
  )
    (asserts! (or (is-eq tx-sender (get buyer escrow)) (is-eq tx-sender (get seller escrow))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) "pending") ERR_INVALID_STATUS)
    (asserts! (is-none (map-get? disputes dispute-id)) ERR_DISPUTE_EXISTS)
    (map-set disputes dispute-id {
      escrow-id: escrow-id,
      initiator: tx-sender,
      reason: reason,
      status: "open",
      created-at: stacks-block-height,
      resolved-at: none
    })
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (resolve-dispute (dispute-id uint) (buyer-share uint) (seller-share uint))
  (let (
    (dispute (unwrap! (get-dispute dispute-id) ERR_DISPUTE_NOT_FOUND))
    (escrow (unwrap! (get-escrow (get escrow-id dispute)) ERR_NOT_FOUND))
    (bale (unwrap! (get-bale-data (get bale-id escrow)) ERR_NOT_FOUND))
    (total-amount (get total-amount escrow))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status dispute) "open") ERR_DISPUTE_RESOLVED)
    (asserts! (is-eq (+ buyer-share seller-share) total-amount) ERR_INVALID_AMOUNT)
    (try! (as-contract (stx-transfer? buyer-share tx-sender (get buyer escrow))))
    (try! (as-contract (stx-transfer? seller-share tx-sender (get seller escrow))))
    (if (> buyer-share u0)
      (try! (nft-transfer? cotton-bale (get bale-id escrow) (get seller escrow) (get buyer escrow)))
      true
    )
    (map-set escrow-agreements (get escrow-id dispute)
      (merge escrow {status: "disputed"})
    )
    (map-set bale-data (get bale-id escrow)
      (merge bale {status: (if (> buyer-share u0) "sold" "available")})
    )
    (map-set disputes dispute-id
      (merge dispute {status: "resolved", resolved-at: (some stacks-block-height)})
    )
    (ok true)
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
