(define-constant contract-owner tx-sender)
(define-constant message-stake u1000000)
(define-constant report-threshold u3)
(define-constant refund-window u144)
(define-constant max-content-length u280)

(define-data-var total-messages uint u0)
(define-data-var total-stakes uint u0)
(define-data-var contract-balance uint u0)

(define-map messages
    { message-id: uint }
    {
        sender: principal,
        recipient: principal,
        content: (string-utf8 280),
        stake: uint,
        timestamp: uint,
        reports: uint,
        refunded: bool,
        is-spam: bool,
    }
)

(define-map user-stats
    { user: principal }
    {
        messages-sent: uint,
        messages-received: uint,
        total-staked: uint,
        reputation-score: uint,
        spam-count: uint,
    }
)

(define-map blocked-users
    {
        blocker: principal,
        blocked: principal,
    }
    { is-blocked: bool }
)

(define-map message-reporters
    {
        message-id: uint,
        reporter: principal,
    }
    { has-reported: bool }
)

(define-map user-reputation
    { user: principal }
    {
        score: uint,
        last-updated: uint,
    }
)

(define-public (send-message
        (recipient principal)
        (content (string-utf8 280))
    )
    (let (
            (message-id (var-get total-messages))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        )
        (asserts! (not (is-eq tx-sender recipient)) (err u1))
        (asserts! (> (len content) u0) (err u2))
        (asserts! (<= (len content) max-content-length) (err u3))
        (asserts!
            (not (default-to false
                (get is-blocked
                    (map-get? blocked-users {
                        blocker: recipient,
                        blocked: tx-sender,
                    })
                )))
            (err u4)
        )
        (try! (stx-transfer? message-stake tx-sender (as-contract tx-sender)))
        (map-set messages { message-id: message-id } {
            sender: tx-sender,
            recipient: recipient,
            content: content,
            stake: message-stake,
            timestamp: current-time,
            reports: u0,
            refunded: false,
            is-spam: false,
        })
        (update-user-stats tx-sender true)
        (update-user-stats recipient false)
        (var-set total-messages (+ message-id u1))
        (var-set total-stakes (+ (var-get total-stakes) message-stake))
        (var-set contract-balance (+ (var-get contract-balance) message-stake))
        (ok message-id)
    )
)

(define-public (report-message (message-id uint))
    (let (
            (message (unwrap! (map-get? messages { message-id: message-id }) (err u5)))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        )
        (asserts! (not (is-eq tx-sender (get sender message))) (err u6))
        (asserts! (not (get refunded message)) (err u7))
        (asserts! (not (get is-spam message)) (err u8))
        (asserts!
            (not (default-to false
                (get has-reported
                    (map-get? message-reporters {
                        message-id: message-id,
                        reporter: tx-sender,
                    })
                )))
            (err u9)
        )
        (map-set message-reporters {
            message-id: message-id,
            reporter: tx-sender,
        } { has-reported: true }
        )
        (let ((new-reports (+ (get reports message) u1)))
            (map-set messages { message-id: message-id }
                (merge message { reports: new-reports })
            )
            (if (>= new-reports report-threshold)
                (begin
                    (try! (mark-as-spam message-id))
                    (try! (burn-stake message-id))
                    (update-reputation (get sender message) false)
                    (ok true)
                )
                (ok true)
            )
        )
    )
)

(define-public (claim-refund (message-id uint))
    (let (
            (message (unwrap! (map-get? messages { message-id: message-id }) (err u10)))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        )
        (asserts! (is-eq (get sender message) tx-sender) (err u11))
        (asserts! (not (get refunded message)) (err u12))
        (asserts! (not (get is-spam message)) (err u13))
        (asserts! (>= current-time (+ (get timestamp message) refund-window))
            (err u14)
        )
        (asserts! (< (get reports message) report-threshold) (err u15))
        (try! (as-contract (stx-transfer? message-stake tx-sender (get sender message))))
        (map-set messages { message-id: message-id }
            (merge message { refunded: true })
        )
        (var-set total-stakes (- (var-get total-stakes) message-stake))
        (var-set contract-balance (- (var-get contract-balance) message-stake))
        (update-reputation tx-sender true)
        (ok true)
    )
)

(define-public (block-user (user principal))
    (begin
        (asserts! (not (is-eq tx-sender user)) (err u16))
        (map-set blocked-users {
            blocker: tx-sender,
            blocked: user,
        } { is-blocked: true }
        )
        (ok true)
    )
)

(define-public (unblock-user (user principal))
    (begin
        (map-set blocked-users {
            blocker: tx-sender,
            blocked: user,
        } { is-blocked: false }
        )
        (ok true)
    )
)

(define-private (mark-as-spam (message-id uint))
    (let ((message (unwrap! (map-get? messages { message-id: message-id }) (err u17))))
        (map-set messages { message-id: message-id }
            (merge message { is-spam: true })
        )
        (ok true)
    )
)

(define-private (burn-stake (message-id uint))
    (let ((message (unwrap! (map-get? messages { message-id: message-id }) (err u18))))
        (var-set total-stakes (- (var-get total-stakes) message-stake))
        (ok true)
    )
)

(define-private (update-user-stats
        (user principal)
        (is-sender bool)
    )
    (let ((current-stats (default-to {
            messages-sent: u0,
            messages-received: u0,
            total-staked: u0,
            reputation-score: u100,
            spam-count: u0,
        }
            (map-get? user-stats { user: user })
        )))
        (if is-sender
            (map-set user-stats { user: user }
                (merge current-stats {
                    messages-sent: (+ (get messages-sent current-stats) u1),
                    total-staked: (+ (get total-staked current-stats) message-stake),
                })
            )
            (map-set user-stats { user: user }
                (merge current-stats { messages-received: (+ (get messages-received current-stats) u1) })
            )
        )
    )
)

(define-private (update-reputation
        (user principal)
        (positive bool)
    )
    (let (
            (current-rep (default-to {
                score: u100,
                last-updated: u0,
            }
                (map-get? user-reputation { user: user })
            ))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        )
        (map-set user-reputation { user: user } {
            score: (if positive
                (+ (get score current-rep) u10)
                (if (>= (get score current-rep) u20)
                    (- (get score current-rep) u20)
                    u0
                )
            ),
            last-updated: current-time,
        })
    )
)

(define-read-only (get-message (message-id uint))
    (map-get? messages { message-id: message-id })
)

(define-read-only (get-user-stats (user principal))
    (map-get? user-stats { user: user })
)

(define-read-only (get-user-reputation (user principal))
    (map-get? user-reputation { user: user })
)

(define-read-only (is-user-blocked
        (blocker principal)
        (blocked principal)
    )
    (default-to false
        (get is-blocked
            (map-get? blocked-users {
                blocker: blocker,
                blocked: blocked,
            })
        ))
)

(define-read-only (has-reported-message
        (message-id uint)
        (reporter principal)
    )
    (default-to false
        (get has-reported
            (map-get? message-reporters {
                message-id: message-id,
                reporter: reporter,
            })
        ))
)

(define-read-only (get-total-messages)
    (var-get total-messages)
)

(define-read-only (get-total-stakes)
    (var-get total-stakes)
)

(define-read-only (get-contract-balance)
    (var-get contract-balance)
)

(define-read-only (get-message-stake-amount)
    message-stake
)

(define-read-only (get-refund-window)
    refund-window
)

(define-read-only (get-report-threshold)
    report-threshold
)

(define-constant category-personal u1)
(define-constant category-business u2)
(define-constant category-promotional u3)
(define-constant category-announcement u4)
(define-constant category-other u5)

(define-map user-category-preferences
    { user: principal }
    {
        allow-personal: bool,
        allow-business: bool,
        allow-promotional: bool,
        allow-announcement: bool,
        allow-other: bool,
    }
)

(define-map message-categories
    { message-id: uint }
    { category: uint }
)

(define-public (send-categorized-message
        (recipient principal)
        (content (string-utf8 280))
        (category uint)
    )
    (let (
            (message-id (var-get total-messages))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
            (recipient-prefs (get-user-category-preferences recipient))
        )
        (asserts! (not (is-eq tx-sender recipient)) (err u101))
        (asserts! (> (len content) u0) (err u102))
        (asserts! (<= (len content) max-content-length) (err u103))
        (asserts! (and (>= category u1) (<= category u5)) (err u104))
        (asserts! (is-category-allowed recipient category) (err u105))
        (asserts!
            (not (default-to false
                (get is-blocked
                    (map-get? blocked-users {
                        blocker: recipient,
                        blocked: tx-sender,
                    })
                )))
            (err u106)
        )
        (try! (stx-transfer? message-stake tx-sender (as-contract tx-sender)))
        (map-set messages { message-id: message-id } {
            sender: tx-sender,
            recipient: recipient,
            content: content,
            stake: message-stake,
            timestamp: current-time,
            reports: u0,
            refunded: false,
            is-spam: false,
        })
        (map-set message-categories { message-id: message-id } { category: category })
        (update-user-stats tx-sender true)
        (update-user-stats recipient false)
        (var-set total-messages (+ message-id u1))
        (var-set total-stakes (+ (var-get total-stakes) message-stake))
        (var-set contract-balance (+ (var-get contract-balance) message-stake))
        (ok message-id)
    )
)

(define-public (set-category-preferences
        (allow-personal bool)
        (allow-business bool)
        (allow-promotional bool)
        (allow-announcement bool)
        (allow-other bool)
    )
    (begin
        (map-set user-category-preferences { user: tx-sender } {
            allow-personal: allow-personal,
            allow-business: allow-business,
            allow-promotional: allow-promotional,
            allow-announcement: allow-announcement,
            allow-other: allow-other,
        })
        (ok true)
    )
)

(define-private (is-category-allowed
        (user principal)
        (category uint)
    )
    (let ((prefs (get-user-category-preferences user)))
        (if (is-eq category category-personal)
            (get allow-personal prefs)
            (if (is-eq category category-business)
                (get allow-business prefs)
                (if (is-eq category category-promotional)
                    (get allow-promotional prefs)
                    (if (is-eq category category-announcement)
                        (get allow-announcement prefs)
                        (get allow-other prefs)
                    )
                )
            )
        )
    )
)

(define-private (get-user-category-preferences (user principal))
    (default-to {
        allow-personal: true,
        allow-business: true,
        allow-promotional: false,
        allow-announcement: true,
        allow-other: true,
    }
        (map-get? user-category-preferences { user: user })
    )
)

(define-read-only (get-message-category (message-id uint))
    (map-get? message-categories { message-id: message-id })
)

(define-read-only (get-user-preferences (user principal))
    (map-get? user-category-preferences { user: user })
)

(define-read-only (can-send-category
        (sender principal)
        (recipient principal)
        (category uint)
    )
    (and
        (not (is-user-blocked recipient sender))
        (is-category-allowed recipient category)
    )
)

(define-map message-threads
    { message-id: uint }
    {
        parent-id: (optional uint),
        thread-root: uint,
        reply-count: uint,
        last-reply-time: uint,
    }
)

(define-map thread-participants
    {
        thread-root: uint,
        participant: principal,
    }
    { joined-time: uint }
)

(define-map user-thread-stats
    { user: principal }
    {
        threads-started: uint,
        replies-sent: uint,
        active-threads: uint,
    }
)

(define-public (reply-to-message
        (parent-message-id uint)
        (content (string-utf8 280))
    )
    (let (
            (parent-message (unwrap! (map-get? messages { message-id: parent-message-id })
                (err u201)
            ))
            (parent-thread (map-get? message-threads { message-id: parent-message-id }))
            (message-id (var-get total-messages))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
            (thread-root (if (is-some parent-thread)
                (get thread-root (unwrap-panic parent-thread))
                parent-message-id
            ))
            (recipient (get sender parent-message))
        )
        (asserts! (not (is-eq tx-sender recipient)) (err u202))
        (asserts! (> (len content) u0) (err u203))
        (asserts! (<= (len content) max-content-length) (err u204))
        (asserts! (not (get is-spam parent-message)) (err u205))
        (asserts!
            (not (default-to false
                (get is-blocked
                    (map-get? blocked-users {
                        blocker: recipient,
                        blocked: tx-sender,
                    })
                )))
            (err u206)
        )
        (try! (stx-transfer? message-stake tx-sender (as-contract tx-sender)))
        (map-set messages { message-id: message-id } {
            sender: tx-sender,
            recipient: recipient,
            content: content,
            stake: message-stake,
            timestamp: current-time,
            reports: u0,
            refunded: false,
            is-spam: false,
        })
        (map-set message-threads { message-id: message-id } {
            parent-id: (some parent-message-id),
            thread-root: thread-root,
            reply-count: u0,
            last-reply-time: current-time,
        })
        (try! (update-thread-reply-count parent-message-id current-time))
        (add-thread-participant thread-root tx-sender current-time)
        (update-user-thread-stats tx-sender false)
        (update-user-stats tx-sender true)
        (update-user-stats recipient false)
        (var-set total-messages (+ message-id u1))
        (var-set total-stakes (+ (var-get total-stakes) message-stake))
        (var-set contract-balance (+ (var-get contract-balance) message-stake))
        (ok message-id)
    )
)

(define-public (start-new-thread
        (recipient principal)
        (content (string-utf8 280))
    )
    (let (
            (message-id (var-get total-messages))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        )
        (asserts! (not (is-eq tx-sender recipient)) (err u207))
        (asserts! (> (len content) u0) (err u208))
        (asserts! (<= (len content) max-content-length) (err u209))
        (asserts!
            (not (default-to false
                (get is-blocked
                    (map-get? blocked-users {
                        blocker: recipient,
                        blocked: tx-sender,
                    })
                )))
            (err u210)
        )
        (try! (stx-transfer? message-stake tx-sender (as-contract tx-sender)))
        (map-set messages { message-id: message-id } {
            sender: tx-sender,
            recipient: recipient,
            content: content,
            stake: message-stake,
            timestamp: current-time,
            reports: u0,
            refunded: false,
            is-spam: false,
        })
        (map-set message-threads { message-id: message-id } {
            parent-id: none,
            thread-root: message-id,
            reply-count: u0,
            last-reply-time: current-time,
        })
        (add-thread-participant message-id tx-sender current-time)
        (add-thread-participant message-id recipient current-time)
        (update-user-thread-stats tx-sender true)
        (update-user-stats tx-sender true)
        (update-user-stats recipient false)
        (var-set total-messages (+ message-id u1))
        (var-set total-stakes (+ (var-get total-stakes) message-stake))
        (var-set contract-balance (+ (var-get contract-balance) message-stake))
        (ok message-id)
    )
)

(define-private (update-thread-reply-count
        (message-id uint)
        (current-time uint)
    )
    (let ((thread-info (unwrap! (map-get? message-threads { message-id: message-id }) (err u211))))
        (map-set message-threads { message-id: message-id }
            (merge thread-info {
                reply-count: (+ (get reply-count thread-info) u1),
                last-reply-time: current-time,
            })
        )
        (ok true)
    )
)

(define-private (add-thread-participant
        (thread-root uint)
        (participant principal)
        (current-time uint)
    )
    (map-set thread-participants {
        thread-root: thread-root,
        participant: participant,
    } { joined-time: current-time }
    )
)

(define-private (update-user-thread-stats
        (user principal)
        (is-new-thread bool)
    )
    (let ((current-stats (default-to {
            threads-started: u0,
            replies-sent: u0,
            active-threads: u0,
        }
            (map-get? user-thread-stats { user: user })
        )))
        (if is-new-thread
            (map-set user-thread-stats { user: user }
                (merge current-stats {
                    threads-started: (+ (get threads-started current-stats) u1),
                    active-threads: (+ (get active-threads current-stats) u1),
                })
            )
            (map-set user-thread-stats { user: user }
                (merge current-stats { replies-sent: (+ (get replies-sent current-stats) u1) })
            )
        )
    )
)

(define-read-only (get-message-thread-info (message-id uint))
    (map-get? message-threads { message-id: message-id })
)

(define-read-only (get-thread-participant-info
        (thread-root uint)
        (participant principal)
    )
    (map-get? thread-participants {
        thread-root: thread-root,
        participant: participant,
    })
)

(define-read-only (get-user-thread-stats (user principal))
    (map-get? user-thread-stats { user: user })
)

(define-read-only (is-thread-participant
        (thread-root uint)
        (user principal)
    )
    (is-some (map-get? thread-participants {
        thread-root: thread-root,
        participant: user,
    }))
)

(define-read-only (get-thread-root (message-id uint))
    (match (map-get? message-threads { message-id: message-id })
        thread-info (some (get thread-root thread-info))
        none
    )
)
