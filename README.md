# INJI VCI Client

The **Inji-Vci-Client-iOS-Swift** is a Swift-based library built to simplify credential issuance via [OpenID for Verifiable Credential Issuance (OID4VCI)](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0-13.html) protocol.  
It supports **Issuer Initiated (Credential Offer)** and **Wallet Initiated (Trusted Issuer)** flows, with secure proof handling, PKCE support, and custom error handling.

---

## 📋 Specifications supported

The implementation follows
- OpenID for Verifiable Credential Issuance - draft 11
- OpenID for Verifiable Credential Issuance - draft 13

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

[//]: # (The reference for PDI  is intentionally pointing to kotlin library master branch to be release agnostic, as the PDI support is available for both kotlin and swift libraries. The documentation for PDI support is also common for both libraries, hence it is placed in the common doc folder in the root of the repository.)
- Presentation During Issuance (PDI) support for both download flows (For more details on PDI support, please refer to the [Presentation During Issuance documentation](https://github.com/inji/inji-vci-client/tree/master/doc/presentation-during-issuance-support.md))

> ⚠️ Consumer of this library is responsible for processing and rendering the credential after it is downloaded.

## 📚 Library implementations available in:
This library is officially supported and available in both Kotlin and Swift, ensuring seamless integration across Android and iOS platforms. The references for both implementations are provided below:

* [Kotlin](https://github.com/inji/inji-vci-client/tree/master/kotlin)
* [Swift](.)
---

## 📦 Installation

Add VCIClient to your Swift Package Manager dependencies:

```swift
.package(url: "https://github.com/inji/inji-vci-client-ios", from: "0.7.0")
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
    ]
]
```

### 3. Request Credential

### 3.1 Request Credential using Credential Offer

#### fetchCredentialUsingCredentialOffer

- Method: `fetchCredentialUsingCredentialOffer`
- This method allows you to fetch a credential using a credential offer, which can be either an embedded JSON or a URI pointing to the credential offer.
- It supports both **Pre-Authorization** and **Authorization** flows.
- The library handles the PKCE flow internally.
- User-trust based credential download supported through onCheckIssuerTrust callback.
- This method is the recommended way to request credential using credential offer.

##### Parameters

| Name                    | Type                     | Required | Default Value | Description                                                                                                                                                            |
|-------------------------|--------------------------|----------|---------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| credentialOffer         | String                   | Yes      | N/A           | Credential offer as embedded JSON or `credential_offer_uri`                                                                                                            |
| clientMetadata          | ClientMetadata           | Yes      | N/A           | Contains client ID and redirect URI                                                                                                                                    |
| getTxCode               | TxCodeCallback           | No       | N/A           | Optional callback function for TX Code (for Pre-Auth flows)                                                                                                            |
| authorizationMethods    | [AuthorizationMethod]    | Yes      | N/A           | Callback functions list to handle authorization and return the resultant authorization response (for Authorization flows) [see authorization details](#authorizations) |
| getTokenResponse        | TokenResponseCallback    | Yes      | N/A           | Callback function to exchange Authorization Grant with Access Token response                                                                                           |
| getProofJwt             | ProofJwtCallback         | Yes      | N/A           | Callback function to prepare proof-jwt for Credential Request                                                                                                          |
| onCheckIssuerTrust      | CheckIssuerTrustCallback | No       | nil           | Callback function to get user trust with the Credential Issuer                                                                                                         |
| downloadTimeoutInMillis | Int64                    | No       | 10000         | Download timeout set for Credential Request call with Credential Issuer (defaults to 10000 ms)                                                                         |

##### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type       | Description                                                                    |
|---------------------------|------------|--------------------------------------------------------------------------------|
| credential                | AnyCodable | The credential downloaded from the Issuer                                      |
| credentialConfigurationId | String?    | The identifier of the respective supported credential from well-known response |
| credentialIssuer          | String?    | URI of the Credential Issuer                                                   |

##### Example usage

```swift
let credentialResponse: CredentialResponse? = try await vciClient.fetchCredentialUsingCredentialOffer(
    credentialOffer: "openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fsample-issuer.com%2Fcredential-offer",
    clientMetadata: ClientMetadata(clientId: "sample-client-id", redirectUri: "https://sample-wallet.com/callback"),
    getTxCode: { inputMode, description, length in
        // Handle the transaction code retrieval logic here
        let txCode = "sampleTxCode"
        return txCode
    },
    authorizationMethods: [
        // Presentation During Issuance flow for authorization
        .presentationDuringIssuance(
            selectCredentialsForPresentation: selectCredentialsForPresentationCallback(),
            signVerifiablePresentation: signVerifiablePresentationCallback(),
            ldpVpSignatureSuite: "Ed25519Signature2020"
        ),
        // Redirect to Web flow for Web view authorization
        .redirectToWeb(openWebPage: openWebPageCallback())
    ],
    getTokenResponse: { tokenRequest in
        // Handle the token response retrieval logic here
        // Exchange authorization code for access token
        return TokenResponse(
            accessToken: "sampleAccessToken",
            cNonce: "sampleNonce",
            tokenType: "Bearer",
            expiresIn: 3600,
            cNonceExpiresIn: 3600
        )
    },
    getProofJwt: { credentialIssuer, cNonce, proofSigningAlgorithmsSupported in
        // Prepare payload for JWT
        // Sign the JWT with the private key as per the proofSigningAlgorithmsSupported
        let jwt = "sampleProofJwt"
        return jwt
    },
    onCheckIssuerTrust: { credentialIssuer, issuerDisplay in
        // Handle the issuer trust check logic here
        return true // Assume the issuer is trusted for this example
    },
    downloadTimeoutInMillis: 10_000
)

// Consider the credential is a Driver's license credential (credential format `mso_mdoc`)
let credentialResponse: CredentialResponse? = try await vciClient.fetchCredentialUsingCredentialOffer(
    credentialOffer: credentialOffer,
    clientMetadata: clientMetadata,
    getTxCode: getTxCode,
    authorizationMethods: authorizationMethods,
    getTokenResponse: getTokenResponse,
    getProofJwt: getProofJwt,
    onCheckIssuerTrust: onCheckIssuerTrust,
    downloadTimeoutInMillis: downloadTimeoutInMillis
)
credentialResponse?.credential // This will contain the credential data
credentialResponse?.credentialConfigurationId // eg - "DriversLicense"
credentialResponse?.credentialIssuer // eg - "https://sample-issuer.com"
```

#### requestCredentialByCredentialOffer (deprecated - use `fetchCredentialUsingCredentialOffer` instead)

- Method: `requestCredentialByCredentialOffer`
- This method allows you to request a credential using a credential offer, which can be either an embedded JSON or a URI pointing to the credential offer.
- It supports both **Pre-Authorization** and **Authorization** flows.
- The library handles the PKCE flow internally.
- User-trust based credential download supported through onCheckIssuerTrust callback.

##### Parameters

| Name                    | Type                     | Required | Default Value | Description                                                                                    |
|-------------------------|--------------------------|----------|---------------|------------------------------------------------------------------------------------------------|
| credentialOffer         | String                   | Yes      | N/A           | Credential offer as embedded JSON or `credential_offer_uri`                                    |
| clientMetadata          | ClientMetadata           | Yes      | N/A           | Contains client ID and redirect URI                                                            |
| getTxCode               | TxCodeCallback           | No       | N/A           | Optional callback function for TX Code (for Pre-Auth flows)                                    |
| authorizeUser           | AuthorizeUserCallback    | Yes      | N/A           | Handles authorization and returns the code (for Authorization flows)                           |
| getTokenResponse        | TokenResponseCallback    | Yes      | N/A           | Callback function to exchange Authorization Grant with Access Token response                   |
| getProofJwt             | ProofJwtCallback         | Yes      | N/A           | Callback function to prepare proof-jwt for Credential Request                                  |
| onCheckIssuerTrust      | CheckIssuerTrustCallback | No       | nil           | Callback function to get user trust with the Credential Issuer                                 |
| downloadTimeoutInMillis | Int64                    | No       | 10000         | Download timeout set for Credential Request call with Credential Issuer (defaults to 10000 ms) |

##### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type       | Description                                                                    |
|---------------------------|------------|--------------------------------------------------------------------------------|
| credential                | AnyCodable | The credential downloaded from the Issuer                                      |
| credentialConfigurationId | String?    | The identifier of the respective supported credential from well-known response |
| credentialIssuer          | String?    | URI of the Credential Issuer                                                   |

##### Example usage

```swift
let credentialResponse: CredentialResponse? = try await vciClient.requestCredentialByCredentialOffer(
    credentialOffer: "openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fsample-issuer.com%2Fcredential-offer",
    clientMetadata: ClientMetadata(clientId: "sample-client-id", redirectUri: "https://sample-wallet.com/callback"),
    getTxCode: { inputMode, description, length in
        // Handle the transaction code retrieval logic here
        let txCode = "sampleTxCode"
        return txCode
    },
    authorizeUser: { authEndpoint in
        // Handle the user authorization logic here
        let authCode = "sampleAuthCode"
        return authCode
    },
    getTokenResponse: { tokenRequest in
        // Handle the token response retrieval logic here
        // Exchange authorization code for access token
        return TokenResponse(
            accessToken: "sampleAccessToken",
            cNonce: "sampleNonce",
            tokenType: "Bearer",
            expiresIn: 3600,
            cNonceExpiresIn: 3600
        )
    },
    getProofJwt: { credentialIssuer, cNonce, proofSigningAlgorithmsSupported in
        // Prepare payload for JWT
        // Sign the JWT with the private key as per the proofSigningAlgorithmsSupported
        let jwt = "sampleProofJwt"
        return jwt
    },
    onCheckIssuerTrust: { credentialIssuer, issuerDisplay in
        // Handle the issuer trust check logic here
        return true // Assume the issuer is trusted for this example
    },
    downloadTimeoutInMillis: 10000
)

// Consider the credential is a Driver's license credential (credential format `mso_mdoc`)
let credentialResponse: CredentialResponse? = try await vciClient.requestCredentialByCredentialOffer(
    credentialOffer: credentialOffer,
    clientMetadata: clientMetadata,
    getTxCode: getTxCode,
    authorizeUser: authorizeUser,
    getTokenResponse: getTokenResponse,
    getProofJwt: getProofJwt,
    onCheckIssuerTrust: onCheckIssuerTrust,
    downloadTimeoutInMillis: downloadTimeoutInMillis
)
credentialResponse?.credential // This will contain the credential data
credentialResponse?.credentialConfigurationId // eg - "DriversLicense"
credentialResponse?.credentialIssuer // eg - "https://sample-issuer.com"
```

### 3.2 Request Credential from Trusted Issuer

#### fetchCredentialFromTrustedIssuer
- Method: `fetchCredentialFromTrustedIssuer`
- It supports **Authorization** flow.
- The library handles the PKCE flow internally.

#### Parameters

| Name                      | Type                  | Required | Default Value | Description                                                                                                                                                            |
|---------------------------|-----------------------|----------|---------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| credentialIssuer          | String                | Yes      | N/A           | URI of the Credential Issuer                                                                                                                                           |
| credentialConfigurationId | String                | Yes      | N/A           | Identifier of the respective supported credential from well-known response                                                                                             |
| clientMetadata            | ClientMetadata        | Yes      | N/A           | Contains client ID and redirect URI                                                                                                                                    |
| authorizationMethods      | [AuthorizationMethod] | Yes      | N/A           | Callback functions list to handle authorization and return the resultant authorization response (for Authorization flows) [see authorization details](#authorizations) |
| getTokenResponse          | TokenResponseCallback | Yes      | N/A           | Callback function to exchange Authorization Grant with Access Token response                                                                                           |
| getProofJwt               | ProofJwtCallback      | Yes      | N/A           | Callback function to prepare proof-jwt for Credential Request                                                                                                          |
| downloadTimeoutInMillis   | Int64                 | No       | 10000         | Download timeout set for Credential Request call with Credential Issuer (defaults to 10000 ms)                                                                         |

#### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type       | Description                                                                    |
|---------------------------|------------|--------------------------------------------------------------------------------|
| credential                | AnyCodable | The credential downloaded from the Issuer                                      |
| credentialConfigurationId | String?    | The identifier of the respective supported credential from well-known response |
| credentialIssuer          | String?    | URI of the Credential Issuer                                                   |

#### Example usage

```swift
let credentialResponse: CredentialResponse? = try await vciClient.fetchCredentialFromTrustedIssuer(
    credentialIssuer: "https://sample-issuer.com",
    credentialConfigurationId: "DriversLicense",
    clientMetadata: ClientMetadata(
        clientId: "sample-client-id",
        redirectUri: "https://sample-wallet.com/callback"
    ),
    authorizationMethods: [
        // Presentation During Issuance flow for authorization
        .presentationDuringIssuance(
            selectCredentialsForPresentation: selectCredentialsForPresentationCallback(),
            signVerifiablePresentation: signVerifiablePresentationCallback(),
            ldpVpSignatureSuite: "Ed25519Signature2020"
        ),
        // Redirect to Web flow for Web view authorization
        .redirectToWeb(openWebPage: openWebPageCallback())
    ],
    getTokenResponse: { tokenRequest in
        // Handle the token response retrieval logic here
        // Exchange authorization code for access token
        return TokenResponse(
            accessToken: "sampleAccessToken",
            cNonce: "sampleNonce",
            tokenType: "Bearer",
            expiresIn: 3600,
            cNonceExpiresIn: 3600
        )
    },
    getProofJwt: { credentialIssuer, cNonce, proofSigningAlgorithmsSupported in
        // Prepare payload for JWT
        // Sign the JWT with the private key as per the proofSigningAlgorithmsSupported
        let jwt = "sampleProofJwt"
        return jwt
    },
    downloadTimeoutInMillis: 10000
)

// Consider the credential is a Driver's license credential (credential format `mso_mdoc`)
let credentialResponse: CredentialResponse? = try await vciClient.fetchCredentialFromTrustedIssuer(
    credentialIssuer: credentialIssuer,
    credentialConfigurationId: credentialConfigurationId,
    clientMetadata: clientMetadata,
    authorizationMethods: authorizationMethods,
    getTokenResponse: getTokenResponse,
    getProofJwt: getProofJwt,
    downloadTimeoutInMillis: downloadTimeoutInMillis
)
credentialResponse?.credential // This will contain the credential data
credentialResponse?.credentialConfigurationId // eg - "DriversLicense"
credentialResponse?.credentialIssuer // eg - "https://sample-issuer.com"
```

#### requestCredentialFromTrustedIssuer (deprecated - use `fetchCredentialFromTrustedIssuer` instead)
- Method: `requestCredentialFromTrustedIssuer`
- This method allows you to request a credential from a trusted issuer of Wallet.
- It supports **Authorization** flow.
- The library handles the PKCE flow internally.

#### Parameters

| Name                      | Type                  | Required | Default Value | Description                                                                                    |
|---------------------------|-----------------------|----------|---------------|------------------------------------------------------------------------------------------------|
| credentialIssuer          | String                | Yes      | N/A           | URI of the Credential Issuer                                                                   |
| credentialConfigurationId | String                | Yes      | N/A           | Identifier of the respective supported credential from well-known response                     |
| clientMetadata            | ClientMetadata        | Yes      | N/A           | Contains client ID and redirect URI                                                            |
| authorizeUser             | AuthorizeUserCallback | Yes      | N/A           | Handles authorization and returns the code (for Authorization flows)                           |
| getTokenResponse          | TokenResponseCallback | Yes      | N/A           | Callback function to exchange Authorization Grant with Access Token response                   |
| getProofJwt               | ProofJwtCallback      | Yes      | N/A           | Callback function to prepare proof-jwt for Credential Request                                  |
| downloadTimeoutInMillis   | Int64                 | No       | 10000         | Download timeout set for Credential Request call with Credential Issuer (defaults to 10000 ms) |

#### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type       | Description                                                                    |
|---------------------------|------------|--------------------------------------------------------------------------------|
| credential                | AnyCodable | The credential downloaded from the Issuer                                      |
| credentialConfigurationId | String?    | The identifier of the respective supported credential from well-known response |
| credentialIssuer          | String?    | URI of the Credential Issuer                                                   |

#### Example usage

```swift
let credentialResponse: CredentialResponse? = try await vciClient.requestCredentialFromTrustedIssuer(
    credentialIssuer: "https://sample-issuer.com",
    credentialConfigurationId: "DriversLicense",
    clientMetadata: ClientMetadata(
        clientId: "sample-client-id",
        redirectUri: "https://sample-wallet.com/callback"
    ),
    authorizeUser: { authEndpoint in
        // Handle the user authorization logic here
        let authCode = "sampleAuthCode"
        return authCode
    },
    getTokenResponse: { tokenRequest in
        // Handle the token response retrieval logic here
        // Exchange authorization code for access token
        return TokenResponse(
            accessToken: "sampleAccessToken",
            cNonce: "sampleNonce",
            tokenType: "Bearer",
            expiresIn: 3600,
            cNonceExpiresIn: 3600
        )
    },
    getProofJwt: { credentialIssuer, cNonce, proofSigningAlgorithmsSupported in
        // Prepare payload for JWT
        // Sign the JWT with the private key as per the proofSigningAlgorithmsSupported
        let jwt = "sampleProofJwt"
        return jwt
    },
    downloadTimeoutInMillis: 10000
)

// Consider the credential is a Driver's license credential (credential format `mso_mdoc`)
let credentialResponse: CredentialResponse? = try await vciClient.requestCredentialFromTrustedIssuer(
    credentialIssuer: credentialIssuer,
    credentialConfigurationId: credentialConfigurationId,
    clientMetadata: clientMetadata,
    authorizeUser: authorizeUser,
    getTokenResponse: getTokenResponse,
    getProofJwt: getProofJwt,
    downloadTimeoutInMillis: downloadTimeoutInMillis
)
credentialResponse?.credential // This will contain the credential data
credentialResponse?.credentialConfigurationId // eg - "DriversLicense"
credentialResponse?.credentialIssuer // eg - "https://sample-issuer.com"
```

##### Authorizations
The `authorizations` parameter is a list of `Authorization` objects indicating the supported authorizations of the Wallet for the download flow. Currently, library supports two authorization flows - _Redirect To Web_ and _Presentation During Issuance_. Library exposes the supported authorization flows via class - `AuthorizationMethod`

1. Redirect To Web (for Authorization flow)

Redirect the user to the authorization endpoint (authorization server) in a web view or browser, and get the authorization response parameters back after successful authorization.

**Parameters :**

| Name        | Type                | Required | Default Value | Description                                                                                                                                                                         |
|-------------|---------------------|----------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| openWebPage | OpenWebPageCallback | Yes      | N/A           | Callback function to open the authorization endpoint in a web view or browser, and return the authorization response parameters (e.g., code, state) after successful authorization. |

**Example usage**
```swift
AuthorizationMethod.redirectToWeb(
    openWebPage: { authorizationEndpoint in
        // Handle the user authorization logic here
        // Open a web view or browser with the authorizationEndpoint
        // Return the authorization response parameters (e.g., code, state)
        let result: [String: Any] = openWebViewAndGetResult(authorizationEndpoint)
        return result
    }
)
```
> Note: The Redirect to Web flow for an interactive authorization flow is exposed as an experimental API, and is expected to be improved in future releases.

2. Presentation During Issuance

Presentation During Issuance flow allows the Wallet to present a verifiable presentation to the Credential Issuer during the credential download process, which can be used by the issuer to verify certain claims about the user before issuing the credential. The authorization for the download here is presentation of another credential (or a verifiable presentation) instead of user-interaction-based authorization as in Redirect To Web flow.

###### Specification Reference

This implementation follows - [OpenID4VCI v1.1 Specification Commit](https://github.com/openid/OpenID4VCI/blob/31636e9bb7f0eef6933175e1e41c78ce79a69783/1.1/openid-4-verifiable-credential-issuance-1_1.md)

> Note:
> - While this library primarily implements OpenID4VCI draft 13 and 11, the Presentation During Issuance feature follows the v1.1 specification as mentioned above.
> - For Presentation During Issuance flow, this VCI client library internally uses [inji-openid4vp-ios-swift](https://github.com/inji/inji-openid4vp-ios-swift) library to construct the VP and handle the presentation exchange with the issuer.

**Parameters :**

| Name                             | Type                                     | Required | Default Value | Description                                                                                                                                                                                                                                                                                                                                                                                            |
|----------------------------------|------------------------------------------|----------|---------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| selectCredentialsForPresentation | SelectCredentialsForPresentationCallback | Yes      | N/A           | Callback function to select credentials from the wallet to be presented to the issuer during issuance as per the Issuer's request. The callback will be invoked with a VP request, this VP request will be used by the Wallet to ask the user for selecting the credentials and then the selected credentials are returned                                                                             |
| signVerifiablePresentation       | SignVerifiablePresentationCallback       | Yes      | N/A           | Callback function to sign the data which will be used for Verifiable Presentation construction. The callback will be invoked with the data to be signed, and the wallet needs to sign this data with the appropriate key and return the signature to the library.                                                                                                                                      |
| ldpVpSignatureSuite              | String                                   | No       | nil           | The signature suite to be used for signing the VP in case of LDP VCs. It is mandatory to provide this parameter if the credential being requested is of format `ldp_vc`. The library will use this information to prepare the proof for the Verifiable Presentation accordingly. Supported values are - `Ed25519Signature2020`, `Ed25519Signature2018`, `JsonWebSignature2020` and `RSASignature2018`. |


**Example usage**

```swift
AuthorizationMethod.presentationDuringIssuance(
    selectCredentialsForPresentation: { presentationRequest in
        // Handle the logic to select credentials from the wallet as per the presentation request
        // Handle the logic for obtaining consent from the user for presenting the credentials to the issuer
        let selectedCredentials: [String: [FormatType: [Any]]] = selectCredentials(presentationRequest)
        return selectedCredentials
    },
    signVerifiablePresentation: { payload in
        // Handle the logic to sign the data with the appropriate key as per the credential descriptor and signature suite
        // From UnsignedVPTokenV2 use the data like format, holderKeyReference and signatureAlgorithm to identify the key to be used for signing and the algorithm to be used for signing the dataToSign, and then return the signature result to the library
        let signedData: [VPTokenSigningResultV2] = signDataForVP(payload)
        // since the payload is a list of data to be signed for each credential, the result is also a list containing the signature result for each credential, and the library will take care of constructing the VP with the respective proof for each credential accordingly
        // To avoid any confusion, the library will expect the implementation of this callback to return list of signature results corresponding to each credential in the same order as the payload, and the library will match the signature result with the respective credential based on the order of the payload list.
        return signedData
    },
    ldpVpSignatureSuite: "Ed25519Signature2020"
)
```

[//]: # (The branch in inji-wallet for pdi docs link is pointed to master intentionally to ensure that the latest documentation is always referred.)
> For more details on the Presentation During Issuance flow and the expected implementation of the callbacks, please refer to the [inji-wallet Presentation During Issuance documentation](https://github.com/inji/inji-wallet/blob/master/docs/presentation-during-issuance-support.md)


### 3.3 Request Credential
- Method: `requestCredential`
- Request for credential from the providers (credential issuer), and receive the credential back.

> Note: This method is deprecated and will be removed in future releases. Please migrate to `requestCredentialByCredentialOffer()` or `requestCredentialFromTrustedIssuer()`.

#### Parameters

| Name        | Type       | Required | Default Value | Description                                                                |
|-------------|------------|----------|---------------|----------------------------------------------------------------------------|
| issuerMeta  | IssuerMeta | Yes      | N/A           | Data object of the issuer details                                          |
| proof       | Proof      | Yes      | N/A           | The proof used for making credential request. Supported proof types : JWT. |
| accessToken | String     | Yes      | N/A           | token issued by providers based on auth code                               |

##### Construction of issuerMetadata

1. Format: `ldp_vc`
```swift
let issuerMetadata = IssuerMeta(
    credentialAudience: CREDENTIAL_AUDIENCE,
    credentialEndpoint: CREDENTIAL_ENDPOINT,
    downloadTimeoutInMilliseconds: DOWNLOAD_TIMEOUT,
    credentialType: CREDENTIAL_TYPE,
    credentialFormat: .ldp_vc
)
```
2. Format: `mso_mdoc`
```swift
let issuerMetadata = IssuerMeta(
    credentialAudience: CREDENTIAL_AUDIENCE,
    credentialEndpoint: CREDENTIAL_ENDPOINT,
    downloadTimeoutInMilliseconds: DOWNLOAD_TIMEOUT,
    credentialFormat: .mso_mdoc,
    docType: DOC_TYPE,
    claims: CLAIMS
)
```

3. Format: `vc+sd-jwt`
```swift
let issuerMetadata = IssuerMeta(
    credentialAudience: CREDENTIAL_AUDIENCE,
    credentialEndpoint: CREDENTIAL_ENDPOINT,
    downloadTimeoutInMilliseconds: DOWNLOAD_TIMEOUT,
    credentialFormat: .vc_sd_jwt
)
```

4. Format: `dc+sd-jwt`
```swift
let issuerMetadata = IssuerMeta(
    credentialAudience: CREDENTIAL_AUDIENCE,
    credentialEndpoint: CREDENTIAL_ENDPOINT,
    downloadTimeoutInMilliseconds: DOWNLOAD_TIMEOUT,
    credentialFormat: .dc_sd_jwt
)
```
#### Returns

An instance of `CredentialResponse` containing:

| Name                      | Type        | Description                               |
|---------------------------|-------------|-------------------------------------------|
| credential                | AnyCodable  | The credential downloaded from the Issuer |
| credentialConfigurationId | String?     | N/A                                       |
| credentialIssuer          | String?     | N/A                                       |

##### Sample returned response

```swift
let credentialResponse: CredentialResponse? = try await vciClient.requestCredential(
    issuerMeta: IssuerMeta(
        credentialAudience: CREDENTIAL_AUDIENCE,
        credentialEndpoint: CREDENTIAL_ENDPOINT,
        downloadTimeoutInMilliseconds: DOWNLOAD_TIMEOUT,
        credentialFormat: .mso_mdoc,
        docType: DOC_TYPE,
        claims: CLAIMS
    ),
    proof: JWTProof(jwtValue: "sampleProofJwt"),
    accessToken: "sampleAccessToken"
)
credentialResponse?.credential // This will contain the credential data
credentialResponse?.credentialConfigurationId // This will be nil
credentialResponse?.credentialIssuer // This will be nil
```

---

## 🚨 Deprecation Notice

The following methods are deprecated and will be removed in future releases. Please migrate to the suggested alternatives.

| Method Name                        | Description                                                                                                                                                              | Deprecated Since | Suggested Alternative                                                                                                                                    |
|------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| requestCredentialFromTrustedIssuer | Request for the download of Verifiable Credential through trusted flow has been improvised to accept different authorizations (web / presentation during issuance)       | 0.7.0            | [fetchCredentialFromTrustedIssuer](#fetchcredentialfromtrustedissuer)                                                                                    |
| requestCredentialByCredentialOffer | Request for download of Verifiable Credential through Credential Offer flow has been improvised to accept different authorizations (web / presentation during issuance). | 0.7.0            | [fetchCredentialUsingCredentialOffer](#fetchcredentialusingcredentialoffer)                                                                              |
| requestCredential                  | Request for credential from the providers (credential issuer), and receive the credential back.                                                                          | 0.4.0            | [fetchCredentialUsingCredentialOffer()](#fetchcredentialusingcredentialoffer) or [fetchCredentialFromTrustedIssuer()](#fetchcredentialfromtrustedissuer) |

---

## 🔐 Security Support

-  **PKCE (Proof Key for Code Exchange)** handled internally (RFC 7636)
-  Supports `S256` code challenge method
-  Secure `c_nonce` binding via proof JWTs

---

## 🛑 Error Handling

All exceptions thrown by the library are subclasses of `VCIClientException`.  
They carry structured error codes like `VCI-001`, `VCI-002` etc., to help consumers identify and recover from failures.

| Code    | Exception Type                          | Description                                                                                              |
|---------|-----------------------------------------|----------------------------------------------------------------------------------------------------------|
| VCI-001 | `AuthorizationServerDiscoveryException` | Failed to discover authorization server                                                                  |
| VCI-002 | `DownloadFailedException`               | Failed to download Credential issuer                                                                     |
| VCI-003 | `InvalidAccessTokenException`           | Access token is invalid                                                                                  |
| VCI-004 | `InvalidDataProvidedException`          | Required details not provided                                                                            |
| VCI-005 | `InvalidPublicKeyException`             | Invalid public key passed metadata                                                                       |
| VCI-006 | `NetworkRequestFailedException`         | Network request failed                                                                                   |
| VCI-007 | `NetworkRequestTimeoutException`        | Network request timed-out                                                                                |
| VCI-008 | `OfferFetchFailedException`             | Failed  to fetch credentialOffer                                                                         |
| VCI-009 | `IssuerMetadataFetchException`          | Failed to fetch issuerMetadata                                                                           |
| VCI-010 | `VCIClientException`                    | Unexpected error during the VCI process                                                                  |
| VCI-011 | `InteractiveAuthorizationException`     | Failed to perform Interactive authorization (Presentation During Issuance / Redirect to Web interaction) |

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

## Documentation

- Architecture decisions are documented in the [INJI VCI Client ADR directory](https://github.com/inji/inji-vci-client/tree/master/doc).
- Documentation of the features are available in the [INJI VCI Client docs directory](https://github.com/inji/inji-vci-client/tree/master/doc).

**Note: The Android library is available in the [INJI VCI Client repository](https://github.com/inji/inji-vci-client).**

---

## Example App

A complete sample app demonstrating credential issuance flows, proof JWT signing, and error handling with `VCIClient` is available here:

[👉 Example iOS App Repository](./SwiftExample)

- Shows both **Credential Offer** and **Trusted Issuer** flows
- Includes best practices for callbacks and UI integration
- Can be built and run on iOS device only

> Use the example app to quickly get started and see the library in action.

---