# ADR-0002: Support for PDI with VP Request following OpenID4VP 1.0

- Status: Accepted
- Date: 2026-06-07

## Context

The OpenID4VP library (OVP) version 0.7.0 currently supports Verifiable Presentation (VP) Draft 23 specification.

The VCI Client's Presentation During Issuance (PDI) authorization method must support both:

- **VP 1.0**: Present-day Verifiable Presentation specification (primary path)
- **Draft 23**: Legacy Verifiable Presentation Draft 23 specification (compatibility path)

The main constraints are:

* VP 1.0 and Draft 23 presentation requests provided by issuers must be supported transparently within PDI flows.
* The core presentation behavior during the issuance flow must remain unchanged.

## Decision

Upgrade OVP library from version 0.7.0 to 1.0.0 and implement version-aware PDI flow handling to support both VP 1.0 and Draft 23 based requests, similar to the OpenID4VCI 1.0/Draft-13 pattern used for credential download flows.

## Implementation Details

To provide support for both VP requests following VP 1.0 and Draft 23 specification, the Inji OpenID4VP library needs to be updated to the latest version

### OVP Library Upgrade (0.7.0 → 1.0.0)

The OVP library version 1.0.0 introduces breaking changes to the Presentation During Issuance authorization method. These changes require updates to the `presentationDuringIssuance` authorization method in `AuthorizationMethod`.

#### Public API Changes

##### 1. Removal of `ldpVpSignatureSuite`

- `ldpVpSignatureSuite` parameter has been removed from the public API
- OVP 1.0.0 uses `JsonWebSignatureSuite2020` as the default signature suite for verifiable presentations
- Linked Data Proof (LDP) signature suite input is no longer supported for `ldp_vp` presentations
- The `presentationDuringIssuance` method now uses `JsonWebSignatureSuite2020` exclusively for verifiable presentations

##### 2. `SelectCredentialsForPresentationCallback` Signature Change

The callback for selecting credentials has been updated:

| Aspect      | OVP 0.7.0                                                | OVP 1.0.0                                                  | Notes                                                                                                           |
|-------------|----------------------------------------------------------|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| Output type | `Map<String, Map<FormatType, AnyCodable>>`               | `Map<String, Array<Credential>>`                           | Changed from format-grouped structure to credential array indexed by input descriptor ID or credential query ID |
| Semantic    | Map of input descriptor ID to format-grouped credentials | Map of input descriptor ID to list of selected credentials | Simpler structure for credential selection                                                                      |

##### 3. `SignVerifiablePresentationCallback` Signature Change

Callback for signing verifiable presentations has been updated:

| Aspect      | OVP 0.7.0                       | OVP 1.0.0                     | Notes                                                                                                                                                                  |
|-------------|---------------------------------|-------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Input type  | `Array<UnsignedVPTokenV2>`      | `Array<UnsignedVPToken>`      | Versioning simplified by removing V2 suffix. New version includes an `id` field to link unsigned VP tokens with their corresponding signed results during preparation. |
| Output type | `Array<VPTokenSigningResultV2>` | `Array<VPTokenSigningResult>` | Versioning simplified by removing V2 suffix. New version includes an `id` field to link unsigned VP tokens with their corresponding signed results during preparation. |

##### 4. Optional `jsonLdCanonicalizer` Parameter (Swift-specific)

- New optional input parameter for canonicalization of JSON-LD data
- Applicable only when presenting credentials of format `ldp_vc`
- Allows Swift consumers to provide custom JSON-LD canonicalization logic

##### 5. Optional `openid4vpWalletConfig`

* Introduces a new optional parameter for wallet-specific OpenID4VP configuration.
* This configuration will be passed to the Inji OpenID4VP library, where it is used to control the wallet's behavior during OpenID4VP transactions and to customize the wallet metadata communicated to the verifier.

#### Internal Changes

##### 1. Removal of Holder ID Extraction Logic

- OVP 1.0.0 removes holder ID as an input parameter from consumer code
- Holder ID extraction is now handled internally by the OVP library
- The OVP library automatically extracts holder ID from the verifiable credential
- Holder binding proof generation for `ldp_vp` presentations is managed by the OVP library
- Inji VCI Client no longer needs to extract or provide holder ID for `ldp_vp` presentations

##### 2. Method Naming Changes

The following internal method names have been updated to align with OVP 1.0.0:

- `constructUnsignedVPTokenV2()` → `constructUnsignedVPToken()`
- `constructVPResponseV2()` → `constructVPResponse()`

These methods are used internally for:
- Constructing the data structure to be signed for verifiable presentation creation
- Building the final VP response object

### Dual VP Specification Support

The OVP library version 1.0.0 introduces support for Verifiable Presentation 1.0 specification alongside Draft 23 compatibility. The VCI Client implements version-aware PDI flow handling to support both specifications:

- **VP 1.0**: Present-day Verifiable Presentation specification (primary path)
- **Draft 23**: Legacy Verifiable Presentation Draft 23 specification (compatibility path)

Version detection and routing are handled automatically by the OVP library, similar to the OpenID4VCI 1.0/Draft-13 pattern used for credential download flows. Version routing is transparent to consumers of the public API.

## Consequences

### Positive

- Dual specification support (VP 1.0 and Draft 23) enables interoperability with both old and new issuers
- Version detection and routing are handled internally by the OVP library, keeping version complexity hidden from consumers
- Core presentation during issuance flow remains intact; only method contracts have changed
- Similar pattern to OpenID4VCI 1.0/Draft-13 dual support provides consistency across the codebase
- Holder ID management is simplified; the OVP library handles extraction internally
- Cleaner callback signatures with simplified type naming (removal of V2 suffix)

### Negative

- Public API of `presentationDuringIssuance` has breaking changes that require code updates
- Callback type signatures have changed, affecting integration code
- Migration effort required for existing integrators

## Migration Path

### For integrators using PDI:

1. Update all calls to `presentationDuringIssuance` to use new callback signatures
2. Remove any `ldpVpSignatureSuite` parameter passing
3. Update callback implementations:
   - `SelectCredentialsForPresentationCallback`: Return `Map<String, Array<Credential>>` instead of format-grouped map
   - `SignVerifiablePresentationCallback`: Accept `Array<UnsignedVPToken>` and return `Array<VPTokenSigningResult>` (without V2 suffix)
4. Optionally provide custom `jsonLdCanonicalizer` for `ldp_vc` credential handling
5. Optionally provide wallet's OpenID4VP related configuration via `openid4vpWalletConfig`

## Implementation Notes

Primary files involved in PDI and OVP 1.0.0 support:

- `Sources/VCIClient/authorizationCodeFlow/AuthorizationMethod.swift`
- `Sources/VCIClient/authorizationCodeFlow/InteractiveAuthorization/PresentationDuringIssuance/PresentationDuringIssuanceAuthorizationMethodService.swift`
- `Sources/VCIClient/authorizationCodeFlow/InteractiveAuthorization/PresentationDuringIssuance/PresentationDuringIssuanceRequestData.swift`
- `Sources/VCIClient/authorizationCodeFlow/InteractiveAuthorization/PresentationDuringIssuance/PresentationInteractionResponse.swift`
- `Sources/VCIClient/authorizationCodeFlow/InteractiveAuthorization/PresentationDuringIssuance/OpenID4VP/OpenID4VPInteraction.swift`