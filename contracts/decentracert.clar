(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_CERT_EXISTS (err u101))
(define-constant ERR_CERT_NOT_FOUND (err u102))
(define-constant ERR_NOT_ISSUER (err u103))

(define-map issuers 
  { issuer: principal }     ;; issuer address
  { verified: bool }        ;; true if verified issuer
)

(define-map certificates
  { cert-id: uint }          ;; certificate ID
  {
    issuer: principal,
    recipient: principal,
    metadata-uri: (string-utf8 256),
    revoked: bool
  }
)

(define-data-var next-cert-id uint u1)

;; Register an issuer
(define-public (register-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender issuer) ERR_UNAUTHORIZED)
    (map-set issuers { issuer: issuer } { verified: true })
    (ok true)
  )
)

;; Issue a certificate
(define-public (issue-certificate (recipient principal) (metadata-uri (string-utf8 256)))
  (let ((issuer-data (map-get? issuers { issuer: tx-sender })))
    (match issuer-data
      data (if (get verified data)
        (let ((cert-id (var-get next-cert-id)))
          (begin
            (map-set certificates { cert-id: cert-id } {
              issuer: tx-sender,
              recipient: recipient,
              metadata-uri: metadata-uri,
              revoked: false
            })
            (var-set next-cert-id (+ cert-id u1))
            (ok cert-id)
          ))
        ERR_NOT_ISSUER)
      ERR_NOT_ISSUER)
  )
)

;; Verify a certificate
(define-read-only (verify-certificate (cert-id uint))
  (match (map-get? certificates { cert-id: cert-id })
    cert-data (ok cert-data)
    ERR_CERT_NOT_FOUND
  )
)

;; Revoke a certificate
(define-public (revoke-certificate (cert-id uint))
  (match (map-get? certificates { cert-id: cert-id })
    cert-data
      (begin
        (asserts! (is-eq (get issuer cert-data) tx-sender) ERR_UNAUTHORIZED)
        (map-set certificates { cert-id: cert-id } {
          issuer: (get issuer cert-data),
          recipient: (get recipient cert-data),
          metadata-uri: (get metadata-uri cert-data),
          revoked: true
        })
        (ok true)
      )
    ERR_CERT_NOT_FOUND
  )
)
