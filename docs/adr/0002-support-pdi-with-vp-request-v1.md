# Support for PDI with VP Request following OpenID4VP 1.0 version

To Support for PDI with VP Request following OpenID4VP 1.0 version, the OVP library (OpenID4VP) needs to be upgraded to version 1.0.0, which introduces support for Verifiable Presentation 1.0 specification. The VCI Client's Presentation During Issuance (PDI) authorization method now needs to support both VP 1.0 (primary path) and Draft 23 (legacy compatibility path).

## Context

- VP 1.0 and Draft 23 issuers should be transparently supported in PDI flows
- version detection and routing should be internal; no public API changes for PDI versioning

## Decision 

Upgrade OVP library version

## Effects

### OVP 0.7.0 → 1.0.0 Upgrade

The OVP library version 1.0.0 introduces breaking changes to the Presentation During Issuance authorization method. These changes require updates to the `presentationDuringIssuance` authorization method in `AuthorizationMethod`.

#### Public API changes

##### 1. Removal of `ldpVpSignatureSuite`

- `ldpVpSignatureSuite` parameter has been removed from the public API
- OVP 0.8.0 uses `JsonWebSignatureSuite2020` as the default signature suite for verifiable presentations
- Linked Data Proof (LDP) signature suite input is no longer supported for `ldp_vp` presentations
- The `presentationDuringIssuance` method now uses `JsonWebSignatureSuite2020` exclusively for verifiable presentations

##### 2. `SelectCredentialsForPresentationCallback` signature change

The callback for selecting credentials has been updated:

| Aspect      | VCI 0.7.0                                                | VCI 1.0.0                                                  | Notes                                                                                                           |
|-------------|----------------------------------------------------------|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| Output type | `Map<String, Map<FormatType, AnyCodable>>`               | `Map<String, Array<Credential>>`                           | Changed from format-grouped structure to credential array indexed by input descriptor ID or credential query ID |
| Semantic    | Map of input descriptor ID to format-grouped credentials | Map of input descriptor ID to list of selected credentials | Simpler structure for credential selection                                                                      |

##### 3. `SignVerifiablePresentationCallback` signature change

Callback for signing verifiable presentations has been renamed:

| Aspect      | VCI 0.7.0                       | VCI 1.0.0                     | Notes                                                                                                                                                                  |
|-------------|---------------------------------|-------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Input type  | `Array<UnsignedVPTokenV2>`      | `Array<UnsignedVPToken>`      | Versioning simplified by removing V2 suffix. New version includes an `id` field to link unsigned VP tokens with their corresponding signed results during preparation. |
| Output type | `Array<VPTokenSigningResultV2>` | `Array<VPTokenSigningResult>` | Versioning simplified by removing V2 suffix. New version includes an `id` field to link unsigned VP tokens with their corresponding signed results during preparation. |

##### 4. Optional `jsonLdCanonicalizer` parameter (Swift-specific)

- New optional input parameter for canonicalization of JSON-LD data
- Applicable only when presenting credentials of format `ldp_vc`
- Allows Swift consumers to provide custom JSON-LD canonicalization logic

#### Internal changes

##### 1. Removal of holder ID extraction logic

- OVP 0.8.0 removes holder ID as an input parameter from consumer code
- Holder ID extraction is now handled internally by the OVP library
- The OVP library automatically extracts holder ID from the verifiable credential
- Holder binding proof generation for `ldp_vp` presentations is managed by the OVP library
- Inji VCI Client no longer needs to extract or provide holder ID for `ldp_vp` presentations

##### 2. Method naming changes

The following internal method names have been updated to align with OVP 1.0.0:

- `constructUnsignedVPTokenV2()` → `constructUnsignedVPToken()`
- `constructVPResponseV2()` → `constructVPResponse()`

These methods are used internally for:
- Constructing the data structure to be signed for verifiable presentation creation
- Building the final VP response object

### VCI 0.7.0 → 1.0.0 Upgrade - VP 1.0 & Draft 23 Support

The OVP library version 1.0.0 introduces support for Verifiable Presentation 1.0 specification alongside Draft 23 compatibility.
The VCI Client now implements version-aware PDI flow handling to support both VP 1.0 and Draft 23 based requests.

#### Dual specification support

The PDI flow now supports:

- **VP 1.0**: Present-day Verifiable Presentation specification (primary path)
- **Draft 23**: Legacy Verifiable Presentation Draft 23 specification (compatibility path)

The VCI Client handles version detection and routing automatically, similar to the OpenID4VCI 1.0/Draft-13 pattern used for credential download flows.

#### Version detection policy

The PDI flow determines whether to use VP 1.0 or Draft 23 based on VP request details with the help of Inji OpenID4VP library

#### Migration impact summary for VCI 1.0.0 in PDI flow

- **Public API breakage**: Code calling `presentationDuringIssuance` must update callback type signatures
- **Removed parameters**: Remove any `ldpVpSignatureSuite` parameter passing; it is no longer accepted
- **Internal simplification**: No need to extract or manage holder ID; OVP library handles this
- **Preserved functionality**: Core presentation during issuance flow remains intact; only the method contracts have changed

### Presentation During Issuance related files

- `Sources/VCIClient/authorizationCodeFlow/AuthorizationMethod.swift`
- `Sources/VCIClient/authorizationCodeFlow/InteractiveAuthorization/PresentationDuringIssuance/PresentationDuringIssuanceAuthorizationMethodService.swift`
- `Sources/VCIClient/authorizationCodeFlow/InteractiveAuthorization/PresentationDuringIssuance/PresentationDuringIssuanceRequestData.swift`
- `Sources/VCIClient/authorizationCodeFlow/InteractiveAuthorization/PresentationDuringIssuance/PresentationInteractionResponse.swift`
- `Sources/VCIClient/authorizationCodeFlow/InteractiveAuthorization/PresentationDuringIssuance/OpenID4VP/OpenID4VPInteraction.swift`