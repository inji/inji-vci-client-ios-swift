# INJI VCI Client

The **Inji-Vci-Client-iOS-Swift** is a Swift-based library built to simplify credential issuance via [OpenID for Verifiable Credential Issuance (OID4VCI)](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0-13.html) protocol.  
It supports **Issuer Initiated (Credential Offer)** and **Wallet Initiated (Trusted Issuer)** flows, with secure proof handling, PKCE support, and custom error handling.

---

## ✨ Features

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

> ⚠️ Consumer of this library is responsible for processing and rendering the credential after it is downloaded.

---

## 📦 Installation

Add VCIClient to your Swift Package Manager dependencies:

```swift
.package(url: "https://github.com/mosip/inji-vci-client-ios", from: "0.5.0")
```

## 🏗️ Construction of VCIClient instance

- The `VCIClient` is constructed with a `traceabilityId` which is used to track the session and traceability of the credential request.

```swift
let traceabilityId = "sample-trace-id"
let vciClient = VCIClient(traceabilityId: traceabilityId)
```

#### Parameters

| Name            | Type   | Required | Default Value | Description                          |
|-----------------|--------|----------|---------------|--------------------------------------|
| traceabilityId  | String | Yes      | N/A           | Unique identifier for the session    |

## 📖 API Overview

### 1. Obtain Issuer Metadata

Retrieve the issuer metadata from the credential issuer's well-known endpoint.

#### Parameters

| Name             | Type   | Required | Default Value | Description                  |
|------------------|--------|----------|---------------|------------------------------|
| credentialIssuer | String | Yes      | N/A           | URI of the Credential Issuer |

#### Returns

`IssuerMetadata` object containing details like `credential_endpoint`, `credential_issuer`, and other IssuerMetadata information from the well-known endpoint of Credential Issuer, which can be used by the consumer to display Issuer information, etc.

> Note: This method does not parse the metadata, it simply returns the raw Network response of well-known endpoint as a `Map<String, Any>`.

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

Retrieve credential configurations supported for given issuer from its well-known endpoint.

#### Parameters

| Name             | Type   | Required | Default Value | Description                  |
|------------------|--------|----------|---------------|------------------------------|
| credentialIssuer | String | Yes      | N/A           | URI of the Credential Issuer |

#### Returns
Map of `credential_configurations_supported` objects containing details like `format`, `scope` and other configuration
information from the well-known endpoint of Credential Issuer, which can be used by the consumer to display supported
credential types, etc.

> Note: This method does not parse the metadata, it simply returns the raw Network response of well-known endpoint as a `Map<String, Any>`.

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
    ]
]
```

### 3. Request Credential

### 3.1 Request Credential by Credential Offer

- Method: `requestCredentialByCredentialOffer`
- This method allows you to request a credential using a credential offer, which can be either an embedded JSON or a URI pointing to the credential offer.
- It supports both **Pre-Authorization** and **Authorization** flows.
- The library handles the PKCE flow internally.
- user-trust based credential download supported through onCheckIssuerTrust callback.

#### Parameters

| Name                    | Type                     | Required | Default Value | Description                                                                                 |
|-------------------------|--------------------------|----------|---------------|---------------------------------------------------------------------------------------------|
| credentialOffer         | String                   | Yes      | N/A           | Credential offer as embedded JSON or `credential_offer_uri`                                 |
| clientMetadata          | ClientMetadata           | Yes      | N/A           | Contains client ID and redirect URI                                                         |
| getTxCode               | TxCodeCallback           | No       | N/A           | Optional callback function for TX Code (for Pre-Auth flows)                                 |
| authorizeUser           | AuthorizeUserCallback    | Yes      | N/A           | Handles authorization and returns the code (for Authorization flows)                        |
| getTokenResponse        | TokenResponseCallback    | Yes      | N/A           | Callback function to exchange Authorization Grant with Access Token response                |
| getProofJwt             | ProofJwtCallback         | Yes      | N/A           | Callback function to prepare proof-jwt for Credential Request                               |
| onCheckIssuerTrust      | CheckIssuerTrustCallback | No       | null          | Callback function to get user trust with the Credential Issuer                              |
| downloadTimeoutInMillis | Long                     | No       | 10000         | Download timeout set for Credential Request call with Credential Issuer (defaults to 10 ms) |

#### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type        | Description                                                                    |
|---------------------------|-------------|--------------------------------------------------------------------------------|
| credential                | JsonElement | The credential downloaded from the Issuer                                      |
| credentialConfigurationId | String      | The identifier of the respective supported credential from well-known response |
| credentialIssuer          | String      | URI of the Credential Issuer                                                   |


#### Example usage

```swift
let credentialResponse = try await vciClient.requestCredentialByCredentialOffer(
    credentialOffer: "openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fsample-issuer.com%2Fcredential-offer",
    clientMetadata: ClientMetadata(
        clientId: "sample-client-id",
        redirectUri: "https://sample-wallet.com/callback"
    ),
    getTxCode: { credentialIssuer, displayData, timeoutInMillis in
        // Handle transaction code retrieval logic here
        return "sampleTxCode"
    },
    authorizeUser: { authEndpoint in
        // Handle user authorization logic here
        return "sampleAuthCode"
    },
    getTokenResponse: { tokenRequest in
        // Exchange authorization code for access token
        return TokenResponse(
            accessToken: "sampleAccessToken",
            cNonce: "sampleNonce",
            tokenType: "Bearer",
            expiresIn: 3600,
            cNonceExpiresIn: 3600
        )
    },
    getProofJwt: { credentialIssuer, cNonce, proofSigningAlgosSupported in
        // Sign the JWT with the private key
        return "sampleProofJwt"
    },
    onCheckIssuerTrust: { credentialIssuer, issuerDisplay in
        // Handle trust check
        return true
    },
    downloadTimeoutInMillis: 10_000
)

// Access the credential fields
let credential = credentialResponse.credential  // This will be a JsonElement containing the credential data. eg - JsonPrimitive("omdk...t")
let credentialConfigId = credentialResponse.credentialConfigurationId // eg - "DriversLicense"
let credentialIssuer = credentialResponse.credentialIssuer // eg - "https://sample-issuer.com"

```

### 3.2 Request Credential from Trusted Issuer

- Method: `requestCredentialFromTrustedIssuer`
- This method allows you to request a credential from a trusted issuer of Wallet.
- It supports **Authorization** flow.
- The library handles the PKCE flow internally.

#### Parameters

| Name                      | Type                  | Required | Default Value | Description                                                                                 |
|---------------------------|-----------------------|----------|---------------|---------------------------------------------------------------------------------------------|
| credentialIssuer          | String                | Yes      | N/A           | URI of the Credential Issuer                                                                |
| credentialConfigurationId | String                | Yes      | N/A           | Identifier of the respective supported credential from well-known response                  |
| clientMetadata            | ClientMetadata        | Yes      | N/A           | Contains client ID and redirect URI                                                         |
| authorizeUser             | AuthorizeUserCallback | Yes      | N/A           | Handles authorization and returns the code (for Authorization flows)                        |
| getTokenResponse          | TokenResponseCallback | Yes      | N/A           | Callback function to exchange Authorization Grant with Access Token response                |
| getProofJwt               | ProofJwtCallback      | Yes      | N/A           | Callback function to prepare proof-jwt for Credential Request                               |
| downloadTimeoutInMillis   | Long                  | No       | 10000         | Download timeout set for Credential Request call with Credential Issuer (defaults to 10 ms) |

#### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type        | Description                                                                    |
|---------------------------|-------------|--------------------------------------------------------------------------------|
| credential                | JsonElement | The credential downloaded from the Issuer                                      |
| credentialConfigurationId | String      | The identifier of the respective supported credential from well-known response |
| credentialIssuer          | String      | URI of the Credential Issuer                                                   |

#### Example usage

```swift
let credentialResponse = try await vciClient.requestCredentialFromTrustedIssuer(
    credentialIssuer: "https://sample-issuer.com",
    credentialConfigurationId: "DriversLicense",
    clientMetadata: ClientMetadata(
        clientId: "sample-client-id",
        redirectUri: "https://sample-wallet.com/callback"
    ),
    authorizeUser: { authEndpoint in
        // Handle user authorization logic here
        return "sampleAuthCode"
    },
    getTokenResponse: { tokenRequest in
        // Exchange authorization code for access token
        return TokenResponse(
            accessToken: "sampleAccessToken",
            cNonce: "sampleNonce",
            tokenType: "Bearer",
            expiresIn: 3600,
            cNonceExpiresIn: 3600
        )
    },
    getProofJwt: { credentialIssuer, cNonce, proofSigningAlgosSupported in
        // Sign JWT with the private key as per proofSigningAlgosSupported
        return "sampleProofJwt"
    },
    downloadTimeoutInMillis: 10_000
)

// Access the credential fields
let credential = credentialResponse.credential  // This will be a JsonElement containing the credential data. eg - JsonPrimitive("omdk...t")
let credentialConfigId = credentialResponse.credentialConfigurationId // eg - "DriversLicense"
let credentialIssuer = credentialResponse.credentialIssuer // eg - "https://sample-issuer.com"

```

### 3.3 Request Credential
- Method: `requestCredential`
- Request for credential from the providers (credential issuer), and receive the credential back.

> Note: This method is deprecated and will be removed in future releases. Please migrate to `requestCredentialByCredentialOffer()` or `requestCredentialFromTrustedIssuer()`.

#### Parameters

| Name           | Type           | Required | Default Value | Description                                                                |
|----------------|----------------|----------|---------------|----------------------------------------------------------------------------|
| issuerMeta | IssuerMeta| Yes      | N/A           | Data object of the issuer details                                          |
| proof      | Proof          | Yes      | N/A           | The proof used for making credential request. Supported proof types : JWT. |
| accessToken    | String         | Yes      | N/A           | token issued by providers based on auth code                               |

###### Construction of issuerMetadata

1. Format: `ldp_vc`
```
val issuerMetadata = IssuerMetadata(
                        CREDENTIAL_AUDIENCE,
                        CREDENTIAL_ENDPOINT, 
                        DOWNLOAD_TIMEOUT, 
                        CREDENTIAL_TYPE, 
                        CredentialFormat.ldp_vc )
```
2. Format: `mso_mdoc`
```
val issuerMetadata = IssuerMetadata(
                        CREDENTIAL_AUDIENCE,
                        CREDENTIAL_ENDPOINT, 
                        DOWNLOAD_TIMEOUT, 
                        DOC_TYPE,
                        CLAIMS, 
                        CredentialFormat.mso_mdoc )
```

> **Note**: The `claims` parameter is optional in the OID4VCI specification for `mso_mdoc` format. While `claims` can be provided in `IssuerMetadata`, this implementation does not include `claims` in the credential request body for `mso_mdoc` format.

3. Format: `vc+sd-jwt`
```
val issuerMetadata = IssuerMetadata(
                        CREDENTIAL_AUDIENCE,
                        CREDENTIAL_ENDPOINT,
                        DOWNLOAD_TIMEOUT,
                        VCT,
                        CredentialFormat.vc_sd_jwt )
```

4. Format: `dc+sd-jwt`
```
val issuerMetadata = IssuerMetadata(
                        CREDENTIAL_AUDIENCE,
                        CREDENTIAL_ENDPOINT,
                        DOWNLOAD_TIMEOUT,
                        VCT,
                        CredentialFormat.dc_sd_jwt )
```
#### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type        | Description                               |
|---------------------------|-------------|-------------------------------------------|
| credential                | JsonElement | The credential downloaded from the Issuer |
| credentialConfigurationId | Null        | N/A                                       |
| credentialIssuer          | Null        | N/A                                       |

##### Sample returned response

```swift
val credentialResponse = try await vciClient.requestCredential(
    issuerMeta = IssuerMetadata(
                        CREDENTIAL_AUDIENCE,
                        CREDENTIAL_ENDPOINT, 
                        DOWNLOAD_TIMEOUT, 
                        DOC_TYPE,
                        CLAIMS, 
                        CredentialFormat.MSO_MDOC ),
    proof = JWTProof(jwtValue = "sampleProofJwt"),
    accessToken = "sampleAccessToken"
)
credentialResponse.credential // This will be a JsonElement containing the credential data. eg - JsonPrimitive("omdk...t")
credentialResponse.credentialConfigurationId // This will be null
credentialResponse.credentialIssuer // This will be null
```

---

## 🚨 Deprecation Notice

The following methods are deprecated and will be removed in future releases. Please migrate to the suggested alternatives.

| Method Name       | Description                                                                                     | Deprecated Since | Suggested Alternative                                                                                                                                                       |
|-------------------|-------------------------------------------------------------------------------------------------|------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| requestCredential | Request for credential from the providers (credential issuer), and receive the credential back. | 0.4.0            | [requestCredentialByCredentialOffer()](#21-request-credential-using-credential-offer) or [requestCredentialFromTrustedIssuer()](#22-request-credential-from-trusted-issuer) |

---

## 🔐 Security Support

-  **PKCE (Proof Key for Code Exchange)** handled internally (RFC 7636)
-  Supports `S256` code challenge method
-  Secure `c_nonce` binding via proof JWTs

---

## 🛑 Error Handling

All exceptions thrown by the library are subclasses of `VCIClientException`.  
They carry structured error codes like `VCI-001`, `VCI-002` etc., to help consumers identify and recover from failures.

| Code    | Exception Type                          | Description                             |
|---------|-----------------------------------------|-----------------------------------------|
| VCI-001 | `AuthorizationServerDiscoveryException` | Failed to discover authorization server |
| VCI-002 | `DownloadFailedException`               | Failed to download Credential issuer    |
| VCI-003 | `InvalidAccessTokenException`           | Access token is invalid                 |
| VCI-004 | `InvalidDataProvidedException`          | Required details not provided           |
| VCI-005 | `InvalidPublicKeyException`             | Invalid public key passed metadata      |
| VCI-006 | `NetworkRequestFailedException`         | Network request failed                  |
| VCI-007 | `NetworkRequestTimeoutException`        | Network request timed-out               |
| VCI-008 | `OfferFetchFailedException`             | Failed  to fetch credentialOffer        |
| VCI-009 | `IssuerMetadataFetchException`          | Failed to fetch issuerMetadata          |


---

## 🧪 Testing

Mock-based tests are available covering:

- Credential download flow (offer + trusted issuer)
- Proof JWT signing callbacks
- Token exchange logic

> See `VCIClientTest` for full coverage

## Platform Support

- **Swift:** 5.7+
- **iOS:** 13.0+

Architecture decisions are noted as ADRs [here](https://github.com/mosip/inji-vci-client/tree/master/doc).

**Note: The android library is available [here](https://github.com/mosip/inji-vci-client)**

---

## Example App

A complete sample app demonstrating credential issuance flows, proof JWT signing, and error handling with `VCIClient` is available here:

[👉 Example iOS App Repository](https://github.com/mosip/inji-vci-client-ios-swift/tree/release-0.4.x/SwiftExample)

- Shows both **Credential Offer** and **Trusted Issuer** flows
- Includes best practices for callbacks and UI integration
- Can be built and run on iOS device only

> Use the example app to quickly get started and see the library in action.

---