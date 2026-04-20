import XCTest
@testable import VCIClient
import  CryptoKit

final class PKCESessionManagerTests: XCTestCase {
    
    var manager: PKCESessionManager!
    
    override func setUp() {
        super.setUp()
        manager = PKCESessionManager()
    }
    
    func testCreateSessionProducesNonEmptyValues() {
        let session = manager.createSession()
        
        XCTAssertFalse(session.codeVerifier.isEmpty, "Code Verifier should not be empty")
        XCTAssertFalse(session.codeChallenge.isEmpty, "Code Challenge should not be empty")
        XCTAssertFalse(session.state.isEmpty, "State should not be empty")
        XCTAssertFalse(session.nonce.isEmpty, "Nonce should not be empty")
    }
    
    func testCodeVerifierIsBase64URLEncoded() {
        let session = manager.createSession()
        let verifier = session.codeVerifier
        
        XCTAssertFalse(verifier.contains("+"), "Verifier should not contain +")
        XCTAssertFalse(verifier.contains("/"), "Verifier should not contain /")
        XCTAssertFalse(verifier.contains("="), "Verifier should not contain =")
    }
    
    func testCodeChallengeIsBase64URLEncoded() {
        let session = manager.createSession()
        let challenge = session.codeChallenge
        
        XCTAssertFalse(challenge.contains("+"), "Challenge should not contain +")
        XCTAssertFalse(challenge.contains("/"), "Challenge should not contain /")
        XCTAssertFalse(challenge.contains("="), "Challenge should not contain =")
    }
    
    func testCodeChallengeMatchesSHA256OfVerifier() {
        let session = manager.createSession()
        
        let verifierData = Data(session.codeVerifier.utf8)
        let hash = SHA256.hash(data: verifierData)
        let expectedChallenge = Data(hash).base64URLEncodedString()
        
        XCTAssertEqual(session.codeChallenge, expectedChallenge, "Code challenge should match SHA256 of verifier")
    }
    
    func testMultipleSessionsAreUnique() {
        let session1 = manager.createSession()
        let session2 = manager.createSession()
        
        XCTAssertNotEqual(session1.codeVerifier, session2.codeVerifier, "Code Verifiers should differ")
        XCTAssertNotEqual(session1.state, session2.state, "States should differ")
        XCTAssertNotEqual(session1.nonce, session2.nonce, "Nonces should differ")
    }
}
