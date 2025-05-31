;; Constants
(define-constant KNOWLEDGE_VAULT_CAPACITY u1500000)
(define-constant BASE_LEARNING_REWARD u12)
(define-constant MASTERY_BONUS u4)
(define-constant MAX_MASTERY_LEVEL u8)
(define-constant ERR_INVALID_STUDY_SESSION u1)
(define-constant ERR_NO_KNOWLEDGE_TOKENS u2)
(define-constant ERR_VAULT_EXCEEDED u3)
(define-constant BLOCKS_PER_STUDY_CYCLE u720)
(define-constant DEDICATION_MULTIPLIER u2)
(define-constant MIN_DEDICATION_DURATION u576)
(define-constant EARLY_EXIT_PENALTY u12)

;; Data Variables
(define-data-var total-knowledge-tokens-issued uint u0)
(define-data-var total-study-sessions uint u0)
(define-data-var learning-facilitator principal tx-sender)

;; Data Maps
(define-map learner-sessions principal uint)
(define-map learner-knowledge-tokens principal uint)
(define-map study-session-start-time principal uint)
(define-map learner-mastery principal uint)
(define-map learner-last-study principal uint)
(define-map learner-dedicated-tokens principal uint)
(define-map learner-dedication-start-block principal uint)

;; Public Functions

(define-public (initiate-study-session (complexity uint))
  (let
    (
      (learner tx-sender)
    )
    (asserts! (> complexity u0) (err ERR_INVALID_STUDY_SESSION))
    (map-set study-session-start-time learner burn-block-height)
    (ok true)
  )
)

(define-public (complete-study-session (complexity uint))
  (let
    (
      (learner tx-sender)
      (start-block (default-to u0 (map-get? study-session-start-time learner)))
      (blocks-studied (- burn-block-height start-block))
      (last-study-block (default-to u0 (map-get? learner-last-study learner)))
      (mastery-level (default-to u0 (map-get? learner-mastery learner)))
      (capped-mastery (if (<= mastery-level MAX_MASTERY_LEVEL) mastery-level MAX_MASTERY_LEVEL))
      (reward-amount (+ BASE_LEARNING_REWARD (* capped-mastery MASTERY_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-studied complexity)) (err ERR_INVALID_STUDY_SESSION))
    (map-set learner-sessions learner (+ (default-to u0 (map-get? learner-sessions learner)) u1))
    (map-set learner-knowledge-tokens learner (+ (default-to u0 (map-get? learner-knowledge-tokens learner)) reward-amount))
    (if (< (- burn-block-height last-study-block) BLOCKS_PER_STUDY_CYCLE)
      (map-set learner-mastery learner (+ mastery-level u1))
      (map-set learner-mastery learner u1)
    )
    (map-set learner-last-study learner burn-block-height)
    (var-set total-study-sessions (+ (var-get total-study-sessions) u1))
    (var-set total-knowledge-tokens-issued (+ (var-get total-knowledge-tokens-issued) reward-amount))
    (asserts! (<= (var-get total-knowledge-tokens-issued) KNOWLEDGE_VAULT_CAPACITY) (err ERR_VAULT_EXCEEDED))
    (ok reward-amount)
  )
)

(define-public (claim-knowledge-rewards)
  (let
    (
      (learner tx-sender)
      (token-balance (default-to u0 (map-get? learner-knowledge-tokens learner)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_KNOWLEDGE_TOKENS))
    (map-set learner-knowledge-tokens learner u0)
    (ok token-balance)
  )
)

;; Dedication Features

(define-public (dedicate-knowledge-tokens (amount uint))
  (let
    (
      (learner tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_STUDY_SESSION))
    (asserts! (>= (var-get total-knowledge-tokens-issued) amount) (err ERR_VAULT_EXCEEDED))
    (map-set learner-dedicated-tokens learner amount)
    (map-set learner-dedication-start-block learner burn-block-height)
    (var-set total-knowledge-tokens-issued (- (var-get total-knowledge-tokens-issued) amount))
    (ok amount)
  )
)

(define-public (withdraw-dedicated-tokens)
  (let
    (
      (learner tx-sender)
      (dedicated-amount (default-to u0 (map-get? learner-dedicated-tokens learner)))
      (dedication-start-block (default-to u0 (map-get? learner-dedication-start-block learner)))
      (blocks-dedicated (- burn-block-height dedication-start-block))
      (penalty (if (< blocks-dedicated MIN_DEDICATION_DURATION) (/ (* dedicated-amount EARLY_EXIT_PENALTY) u100) u0))
      (final-amount (- dedicated-amount penalty))
    )
    (asserts! (> dedicated-amount u0) (err ERR_NO_KNOWLEDGE_TOKENS))
    (map-set learner-dedicated-tokens learner u0)
    (map-set learner-dedication-start-block learner u0)
    (var-set total-knowledge-tokens-issued (+ (var-get total-knowledge-tokens-issued) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions

(define-read-only (get-study-session-count (user principal))
  (default-to u0 (map-get? learner-sessions user))
)

(define-read-only (get-knowledge-token-balance (user principal))
  (default-to u0 (map-get? learner-knowledge-tokens user))
)

(define-read-only (get-mastery-level (user principal))
  (default-to u0 (map-get? learner-mastery user))
)

(define-read-only (get-knowledge-vault-stats)
  {
    total-study-sessions: (var-get total-study-sessions),
    total-knowledge-tokens-issued: (var-get total-knowledge-tokens-issued)
  }
)

;; Private Functions

(define-private (is-learning-facilitator)
  (is-eq tx-sender (var-get learning-facilitator))
)