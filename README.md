# INJI VCI Client

The **Inji-Vci-Client-iOS-Swift** is a Swift-based library built to simplify credential issuance via [OpenID for Verifiable Credential Issuance (OID4VCI)](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0-13.html) protocol.  
It supports **Issuer Initiated (Credential Offer)** and **Wallet Initiated (Trusted Issuer)** flows, with secure proof handling, PKCE support, and custom error handling.

---

## Specifications supported

The implementation follows
- OpenID for Verifiable Credential Issuance 1.0
- OpenID for Verifiable Credential Issuance draft 13 compatibility for issuers that still expose the older metadata and request/response format

## Features

- Request credentials from OID4VCI-compliant credential issuers
- Supports both:
  - Issuer Initiated Flow (Credential Offer Flow).
  - Wallet Initiated Flow (Trusted Issuer Flow).
- Authorization server discovery for both flows
- PKCE-compliant OAuth 2.0 Authorization Code flow (RFC 7636)
  - PKCE session is managed internally by the library
- Well-defined **exception handling** with `VCI-XXX` error codes (see more on [this](#error-handling))
- Support for multiple Credential formats:
  - `ldp_vc`
  - `mso_mdoc`
  - `vc+sd-jwt` / `dc+sd-jwt`
  - `jwt_vc_json`

[//]: # (The reference for PDI  is intentionally pointing to kotlin library master branch to be release agnostic, as the PDI support is available for both kotlin and swift libraries. The documentation for PDI support is also common for both libraries, hence it is placed in the common doc folder in the root of the repository.)
- Presentation During Issuance (PDI) support for both download flows (For more details on PDI support, please refer to the [Presentation During Issuance documentation](https://github.com/inji/inji-vci-client/tree/master/doc/presentation-during-issuance-support.md))

> Consumer of this library is responsible for processing and rendering the credential after it is downloaded.

## Library implementations available in:
This library is officially supported and available in both Kotlin and Swift, ensuring seamless integration across Android and iOS platforms. The references for both implementations are provided below:

* [Kotlin](https://github.com/inji/inji-vci-client/tree/master/kotlin)
* [Swift](.)
---

## Installation

Add VCIClient to your Swift Package Manager dependencies:

```swift
.package(url: "https://github.com/inji/inji-vci-client-ios-swift", from: "1.0.0")
```

## What's New in 1.0.0

Version `1.0.0` defines the stable public API surface for credential download:

- `fetchCredentialsUsingCredentialOffer(...)` for issuer-initiated flows
- `fetchCredentialsFromTrustedIssuer(...)` for wallet-initiated flows
- plural proof and response models aligned with OpenID4VCI 1.0
- retained Draft-13 issuer compatibility behind the new APIs
- structured error handling so wallet applications can distinguish between library-level failures and issuer or authorization server error payloads
- issuer metadata fetches validate that the `credential_issuer` returned by the well-known endpoint matches the requested issuer, per [OID4VCI Section 13.5](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#section-13.5)

## Construction of VCIClient instance

- The `VCIClient` is constructed with a `traceabilityId` which is used to track the session and traceability of the credential request.

```swift
let traceabilityId = "sample-trace-id"
let vciClient = VCIClient(traceabilityId: traceabilityId)
```

#### Parameters

| Name            | Type   | Required | Default Value | Description                          |
|-----------------|--------|----------|---------------|--------------------------------------|
| traceabilityId  | String | Yes      | N/A           | Unique identifier for the session    |

## API Overview

### 1. Obtain Issuer Metadata
#### getIssuerMetadata

Retrieve the issuer metadata from the credential issuer's well-known endpoint.

#### Parameters

| Name             | Type   | Required | Default Value | Description                  |
|------------------|--------|----------|---------------|------------------------------|
| credentialIssuer | String | Yes      | N/A           | URI of the Credential Issuer |

#### Returns

`[String: Any]` dictionary containing details like `credential_endpoint`, `credential_issuer`, and other issuer metadata from the well-known endpoint of Credential Issuer, which can be used by the consumer to display Issuer information, etc.

> Note: This method does not parse the metadata, it simply returns the raw Network response of well-known endpoint as a `[String: Any]`.

#### Example Usage

```swift
let issuerMetadata: [String: Any] = try await vciClient.getIssuerMetadata(credentialIssuer: "https://example.com/issuer")
    
//the response looks similar to this
[String: Any] = [
    "credential_issuer": "https://example.com/issuer",
    "credential_endpoint": "https://example.com/issuer/credential"
]
```

### 2. Obtain Credential Configurations Supported
#### getCredentialConfigurationsSupported

Retrieve credential configurations supported for given issuer from its well-known endpoint.

#### Parameters

| Name             | Type   | Required | Default Value | Description                  |
|------------------|--------|----------|---------------|------------------------------|
| credentialIssuer | String | Yes      | N/A           | URI of the Credential Issuer |

#### Returns
Map of `credential_configurations_supported` objects containing details like `format`, `scope` and other configuration
information from the well-known endpoint of Credential Issuer, which can be used by the consumer to display supported
credential types, etc.

> Note: This method does not parse the metadata, it simply returns the raw Network response of well-known endpoint as a `[String: Any]`.

#### Example Usage

```swift
let credentialConfigurationsSupported : [String: Any] = try await vciClient.getCredentialConfigurationsSupported(
    credentialIssuer: "https://example.com/issuer"
)

//The response looks similar to this
[String: Any] = [
    "credentialConfigId-1": [
        "format": "ldp_vc",
        "credential_definition": [
            "type": ["VerifiableCredential", "ExampleCredential"]
        ]
    ],
    "credentialConfigId-2": [
        "format": "mso_mdoc",
        "doctype": "org.iso.18013.5.1.mDL"
    ],
    "credentialConfigId-3": [
        "format": "jwt_vc_json",
        "credential_definition": [
            "type": ["VerifiableCredential", "ExampleJwtCredential"],
        ],
        "scope": "ExampleJwtCredential"
    ]
]
```

### 3. Request Credential

Version `1.0.0` exposes two public credential download APIs:

- `fetchCredentialsUsingCredentialOffer(...)` for issuer-initiated flows
- `fetchCredentialsFromTrustedIssuer(...)` for wallet-initiated flows

Both methods use the OpenID4VCI 1.0-facing proof callback and return a normalized plural response. When an issuer still behaves like Draft-13, the library keeps the compatibility routing internal and still returns the 1.0 response shape.

### 3.1 Request Credential using Credential Offer

#### fetchCredentialsUsingCredentialOffer

- Method: `fetchCredentialsUsingCredentialOffer`
- Accepts either an embedded credential offer or a `credential_offer_uri`
- Supports both **Pre-Authorization** and **Authorization** flows
- Handles PKCE internally
- Supports issuer trust checks via `onCheckIssuerTrust`

##### Parameters

| Name                    | Type                          | Required | Default Value | Description                                                                                                                                                            |
|-------------------------|-------------------------------|----------|---------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| credentialOffer         | String                        | Yes      | N/A           | Credential offer as embedded JSON or `credential_offer_uri`                                                                                                            |
| clientMetadata          | ClientMetadata                | Yes      | N/A           | Contains client ID and redirect URI                                                                                                                                    |
| getTxCode               | TxCodeCallback                | No       | N/A           | Optional callback for TX Code in pre-authorized flows                                                                                                                  |
| authorizationMethods    | [AuthorizationMethod]         | Yes      | N/A           | Supported authorization callbacks for interactive flows [see authorization details](#authorizations)                                                                   |
| getTokenResponse        | TokenResponseCallback         | Yes      | N/A           | Callback that exchanges the authorization grant for an access token                                                                                                    |
| getProofs               | ProofsCallback                | Yes      | N/A           | Callback that prepares the proof set for the credential request                                                                                                        |
| onCheckIssuerTrust      | CheckIssuerTrustCallback      | No       | nil           | Optional callback to confirm that the issuer is trusted                                                                                                                |
| downloadTimeoutInMillis | Int64                         | No       | 10000         | Timeout for the credential request to the issuer                                                                                                                       |

##### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type           | Description                                                                    |
|---------------------------|----------------|--------------------------------------------------------------------------------|
| credentials               | [AnyCodable]?  | Credentials downloaded from the issuer                                         |
| credentialConfigurationId | String?        | The identifier of the respective supported credential from well-known response |
| credentialIssuer          | String?        | URI of the credential issuer                                                   |

##### Example usage

```swift
let credentialResponse = try await vciClient.fetchCredentialsUsingCredentialOffer(
    credentialOffer: "openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fsample-issuer.com%2Fcredential-offer",
    clientMetadata: ClientMetadata(clientId: "sample-client-id", redirectUri: "https://sample-wallet.com/callback"),
    getTxCode: { inputMode, description, length in
        "sampleTxCode"
    },
    authorizationMethods: [
        .presentationDuringIssuance(
            selectCredentialsForPresentation: selectCredentialsForPresentationCallback(),
            signVerifiablePresentation: signVerifiablePresentationCallback(),
            ldpVpSignatureSuite: "Ed25519Signature2020"
        ),
        .redirectToWeb(openWebPage: openWebPageCallback())
    ],
    getTokenResponse: { tokenRequest in
        TokenResponse(
            accessToken: "sampleAccessToken",
            cNonce: "sampleNonce",
            tokenType: "Bearer",
            expiresIn: 3600,
            cNonceExpiresIn: 3600
        )
    },
    getProofs: { credentialIssuer, nonce, proofSigningAlgorithmsSupported in
        CredentialRequestProofs(proofs: ["sampleProofJwt"])
    },
    onCheckIssuerTrust: { credentialIssuer, issuerDisplay in
        true
    },
    downloadTimeoutInMillis: 10_000
)

credentialResponse.credentials
credentialResponse.credentialConfigurationId
credentialResponse.credentialIssuer
```

### 3.2 Request Credential from Trusted Issuer

#### fetchCredentialsFromTrustedIssuer

- Method: `fetchCredentialsFromTrustedIssuer`
- Supports **Authorization** flow
- Handles PKCE internally

##### Parameters

| Name                      | Type                       | Required | Default Value | Description                                                                                                                                                            |
|---------------------------|----------------------------|----------|---------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| credentialIssuer          | String                     | Yes      | N/A           | URI of the credential issuer                                                                                                                                           |
| credentialConfigurationId | String                     | Yes      | N/A           | Identifier of the supported credential configuration                                                                                                                   |
| clientMetadata            | ClientMetadata             | Yes      | N/A           | Contains client ID and redirect URI                                                                                                                                    |
| authorizationMethods      | [AuthorizationMethod]      | Yes      | N/A           | Supported authorization callbacks for interactive flows [see authorization details](#authorizations)                                                                   |
| getTokenResponse          | TokenResponseCallback      | Yes      | N/A           | Callback that exchanges the authorization grant for an access token                                                                                                    |
| getProofs                 | ProofsCallback             | Yes      | N/A           | Callback that prepares the proof set for the credential request                                                                                                        |
| downloadTimeoutInMillis   | Int64                      | No       | 10000         | Timeout for the credential request to the issuer                                                                                                                       |

##### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type           | Description                                                                    |
|---------------------------|----------------|--------------------------------------------------------------------------------|
| credentials               | [AnyCodable]?  | Credentials downloaded from the issuer                                         |
| credentialConfigurationId | String?        | The identifier of the respective supported credential from well-known response |
| credentialIssuer          | String?        | URI of the credential issuer                                                   |

##### Example usage

```swift
let credentialResponse = try await vciClient.fetchCredentialsFromTrustedIssuer(
    credentialIssuer: "https://sample-issuer.com",
    credentialConfigurationId: "DriversLicense",
    clientMetadata: ClientMetadata(
        clientId: "sample-client-id",
        redirectUri: "https://sample-wallet.com/callback"
    ),
    authorizationMethods: [
        .presentationDuringIssuance(
            selectCredentialsForPresentation: selectCredentialsForPresentationCallback(),
            signVerifiablePresentation: signVerifiablePresentationCallback(),
            ldpVpSignatureSuite: "Ed25519Signature2020"
        ),
        .redirectToWeb(openWebPage: openWebPageCallback())
    ],
    getTokenResponse: { tokenRequest in
        TokenResponse(
            accessToken: "sampleAccessToken",
            cNonce: "sampleNonce",
            tokenType: "Bearer",
            expiresIn: 3600,
            cNonceExpiresIn: 3600
        )
    },
    getProofs: { credentialIssuer, nonce, proofSigningAlgorithmsSupported in
        CredentialRequestProofs(proofs: ["sampleProofJwt"])
    },
    downloadTimeoutInMillis: 10_000
)

credentialResponse.credentials
credentialResponse.credentialConfigurationId
credentialResponse.credentialIssuer
```

##### Authorizations

The `authorizationMethods` parameter is a list of supported wallet authorization flows. The library currently supports:

1. Redirect To Web

Redirect the user to the authorization endpoint in a web view or browser and return the authorization response parameters after successful authorization.

| Name        | Type                | Required | Default Value | Description                                                                                                                                                                         |
|-------------|---------------------|----------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| openWebPage | OpenWebPageCallback | Yes      | N/A           | Callback that opens the authorization endpoint and returns the authorization response parameters such as `code` and `state`                                                         |

```swift
AuthorizationMethod.redirectToWeb(
    openWebPage: { authorizationEndpoint in
        let result: [String: Any] = openWebViewAndGetResult(authorizationEndpoint)
        return result
    }
)
```

2. Presentation During Issuance

Presentation During Issuance allows the wallet to present a verifiable presentation to the credential issuer during the issuance flow.

This implementation follows [OpenID4VCI v1.1 Specification Commit](https://github.com/openid/OpenID4VCI/blob/31636e9bb7f0eef6933175e1e41c78ce79a69783/1.1/openid-4-verifiable-credential-issuance-1_1.md).

> Note:
> - The public API surface is aligned to OpenID4VCI 1.0.
> - For Presentation During Issuance, this library internally uses [inji-openid4vp-ios-swift](https://github.com/inji/inji-openid4vp-ios-swift) to construct the VP and handle presentation exchange.

| Name                             | Type                                     | Required | Default Value | Description                                                                                                                                                                                                                                                                                                                                                                                            |
|----------------------------------|------------------------------------------|----------|---------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| selectCredentialsForPresentation | SelectCredentialsForPresentationCallback | Yes      | N/A           | Callback to select credentials from the wallet for the issuer's presentation request                                                                                                                                                                                                                                                                                                                  |
| signVerifiablePresentation       | SignVerifiablePresentationCallback       | Yes      | N/A           | Callback to sign the payload used for verifiable presentation construction                                                                                                                                                                                                                                                                                                                             |
| ldpVpSignatureSuite              | String                                   | No       | nil           | Signature suite to use for signing the VP when the requested credential format is `ldp_vc`                                                                                                                                                                                                                                                                                                            |

```swift
AuthorizationMethod.presentationDuringIssuance(
    selectCredentialsForPresentation: { presentationRequest in
        let selectedCredentials: [String: [FormatType: [Any]]] = selectCredentials(presentationRequest)
        return selectedCredentials
    },
    signVerifiablePresentation: { payload in
        let signedData: [VPTokenSigningResultV2] = signDataForVP(payload)
        return signedData
    },
    ldpVpSignatureSuite: "Ed25519Signature2020"
)
```

[//]: # (The branch in inji-wallet for pdi docs link is pointed to master intentionally to ensure that the latest documentation is always referred.)
> For more details on the Presentation During Issuance flow and the expected implementation of the callbacks, please refer to the [inji-wallet Presentation During Issuance documentation](https://github.com/inji/inji-wallet/blob/master/docs/presentation-during-issuance-support.md)

---

## Security Support

-  **PKCE (Proof Key for Code Exchange)** handled internally (RFC 7636)
-  Supports `S256` code challenge method
-  Secure `c_nonce` binding via proof JWTs

---

## Error Handling

All exceptions thrown by the library are subclasses of `VCIClientException`.  
They carry structured fields that help consumers identify whether the failure came from the library itself, a wrapped library exception, or an upstream server response.

### `VCIClientException` fields

| Field                    | Type      | Meaning |
|--------------------------|-----------|---------|
| `code`                   | `String`  | The library-defined error code for the exception being thrown to the consumer. |
| `message`                | `String`  | Human-readable summary of the failure, ready for logging or diagnostics. |
| `sourceErrorCode`        | `String?` | The root `VCI-*` code from the underlying cause when the library wraps another `VCIClientException`. |
| `serverErrorCode`        | `String?` | The issuer or authorization server `error` value when the remote service returned a structured OAuth/OID4VCI-style error response. |
| `serverErrorDescription` | `String?` | The upstream `error_description` value when available. If the response body is not parseable JSON, the raw response body may be propagated here for diagnostics. |

### Error model

The error model provides full observability into failures:

- `code` identifies the current exception returned to the caller.
- `sourceErrorCode` preserves the deeper `VCI-*` code when the current exception wraps another library exception.
- `serverErrorCode` captures the upstream server `error` field when present.
- `serverErrorDescription` captures the upstream `error_description`, or the raw error body when structured parsing is not possible.

This means consumers can distinguish between:

- a library wrapper error exposed at the public API boundary,
- the original underlying library failure,
- and a server-originated error payload returned by the issuer or authorization server.

#### Consumer guidance

- Use `code` for primary client-side branching, telemetry dimensions, and product analytics.
- Use `sourceErrorCode` when `code` represents a wrapper exception and you need the more specific underlying failure category.
- Use `serverErrorCode` to decide whether a failure is recoverable through user action, such as re-authentication, retry, or correcting a request.
- Use `serverErrorDescription` for logs, support tooling, and developer diagnostics. Avoid showing it directly to end users without sanitization because it may contain server-specific text.

Some public API methods may wrap an internal `VCIClientException` into another `VCIClientException` before rethrowing it. This improves consistency at the API boundary without losing the root cause.

Example:

- `getIssuerMetadata()` may throw `VCI-010` at the API boundary.
- `sourceErrorCode` may still contain `VCI-009` if the underlying failure was an issuer metadata fetch error.
- `serverErrorCode` may contain a remote value such as `invalid_token` if the upstream endpoint returned it.

### Recommended consumer handling

```swift
do {
    let credentialResponse = try await vciClient.fetchCredentialsUsingCredentialOffer(
        credentialOffer: credentialOffer,
        clientMetadata: clientMetadata,
        getTxCode: getTxCode,
        authorizationMethods: authorizationMethods,
        getTokenResponse: getTokenResponse,
        getProofs: getProofs
    )
} catch let error as VCIClientException {
    logger.error(
        "VCI request failed. code=\(error.code), source=\(error.sourceErrorCode ?? "nil"), " +
        "serverCode=\(error.serverErrorCode ?? "nil"), serverDescription=\(error.serverErrorDescription ?? "nil"), " +
        "message=\(error.message)"
    )

    switch error.code {
    case "VCI-007":
        showRetryMessage()
    case "VCI-003":
        triggerTokenRefresh()
    case "VCI-011":
        showAuthorizationFailure()
    default:
        showGenericFailure()
    }
}
```

### Error code reference

| Code    | Exception Type                             | Description                                                                                              |
|---------|--------------------------------------------|----------------------------------------------------------------------------------------------------------|
| VCI-001 | `AuthorizationServerDiscoveryException`    | Failed to discover authorization server                                                                  |
| VCI-002 | `DownloadFailedException`                  | Failed to download credential                                                                            |
| VCI-003 | `InvalidAccessTokenException`              | Access token is invalid                                                                                  |
| VCI-004 | `InvalidDataProvidedException`             | Required details not provided                                                                            |
| VCI-005 | `InvalidPublicKeyException`                | Invalid public key passed                                                                                |
| VCI-006 | `NetworkRequestFailedException`            | Network request failed                                                                                   |
| VCI-007 | `NetworkRequestTimeoutException`           | Network request timed-out                                                                                |
| VCI-008 | `CredentialOfferFetchFailedException`      | Failed to fetch credential offer                                                                         |
| VCI-009 | `IssuerMetadataFetchException`             | Failed to fetch issuerMetadata                                                                           |
| VCI-010 | `VCIClientException`                       | Generic API-boundary wrapper or unknown exception surfaced by `VCIClient` public methods                |
| VCI-011 | `InteractiveAuthorizationException`        | Failed to perform Interactive authorization (Presentation During Issuance / Redirect to Web interaction) |

---

## Testing

Mock-based tests are available covering:

- Credential download flow (offer + trusted issuer)
- Proof JWT signing callbacks
- Token exchange logic

> See `VCIClientTest` for full coverage

## Platform Support

- **Swift:** 5.7+
- **iOS:** 13.0+

## Documentation

- Architecture decisions are documented in the [INJI VCI Client ADR directory](https://github.com/inji/inji-vci-client/tree/master/doc/adr).
- Documentation of the features are available in the [INJI VCI Client docs directory](https://github.com/inji/inji-vci-client/tree/master/doc).
- The OpenID4VCI 1.0 migration and Draft-13 compatibility design for this Swift library is documented in [ADR-0001](docs/adr/0001-openid4vci-v1-migration.md).

**Note: The Android library is available in the [INJI VCI Client repository](https://github.com/inji/inji-vci-client).**

---

## Example App

A complete sample app demonstrating credential issuance flows, proof JWT signing, and error handling with `VCIClient` is available here:

[Example iOS App Repository](./SwiftExample)

- Shows both **Credential Offer** and **Trusted Issuer** flows
- Includes best practices for callbacks and UI integration
- Can be built and run on iOS device only

> Use the example app to quickly get started and see the library in action.

---
