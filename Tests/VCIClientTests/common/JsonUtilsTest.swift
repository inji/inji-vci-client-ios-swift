import XCTest
@testable import VCIClient

final class JsonUtilsTests: XCTestCase {
    
    struct TestUser: Codable, Equatable {
        let firstName: String
        let lastName: String
    }

    func testDeserializeParsesValidJSONString() async throws {
        let json = """
        {
            "firstName": "John",
            "lastName": "Doe"
        }
        """
        
        let user = try JsonUtils.deserialize(json, as: TestUser.self)
        XCTAssertNotNil(user)
        XCTAssertEqual(user, TestUser(firstName: "John", lastName: "Doe"))
    }

    func testDeserializeReturnsNilForEmptyString() async throws {
        let json = ""
        let user = try JsonUtils.deserialize(json, as: TestUser.self)
        XCTAssertNil(user, "Should return nil for empty input")
    }

    func testDeserializeThrowsOnInvalidJSON() async {
        let invalidJson = "{ invalid json }"

        do {
            _ = try JsonUtils.deserialize(invalidJson, as: TestUser.self)
            XCTFail("Expected decoding to throw error")
        } catch {
                    }
    }


    func testToMapConvertsValidJSONStringToDictionary() {
        let json = """
        {
            "first_name": "John",
            "last_name": "Doe"
        }
        """

        let map = JsonUtils.toMap(json)
        XCTAssertEqual(map["first_name"] as? String, "John")
        XCTAssertEqual(map["last_name"] as? String, "Doe")
    }

    func testToMapReturnsEmptyDictionaryOnInvalidJSON() {
        let invalidJson = "{ invalid json }"
        let map = JsonUtils.toMap(invalidJson)
        XCTAssertTrue(map.isEmpty)
    }

    func testToMapHandlesEmptyString() {
        let emptyJson = ""
        let map = JsonUtils.toMap(emptyJson)
        XCTAssertTrue(map.isEmpty)
    }

    func testToMapTrimsWhitespaceAndNewlines() {
        let json = " \n\t  {\"key\":\"value\"}  \n "
        let map = JsonUtils.toMap(json)
        XCTAssertEqual(map["key"] as? String, "value")
    }
    
    func testEncodeEncodesObjectToJSONString() {
        let user = TestUser(firstName: "John", lastName: "Doe")

        let json = JsonUtils.encode(user)

        XCTAssertTrue(json.contains("John"))
        XCTAssertTrue(json.contains("Doe"))
    }
    
    
    struct FailingEncodable: Encodable {
        func encode(to encoder: Encoder) throws {
            throw NSError(domain: "EncodingError", code: 1)
        }
    }

    func testEncodeReturnsEmptyOnFailure() {
        let obj = FailingEncodable()

        let json = JsonUtils.encode(obj, empty: "EMPTY")

        XCTAssertEqual(json, "EMPTY")
    }
    
    
    func testToMapReturnsEmptyWhenJsonIsArray() {
        let json = """
        ["a", "b", "c"]
        """

        let map = JsonUtils.toMap(json)

        XCTAssertTrue(map.isEmpty)
    }
    
    struct FailingJsonEncodable: Encodable {
        func encode(to encoder: Encoder) throws {
            throw NSError(domain: "EncodingError", code: 1)
        }
    }

    func testToJsonStringReturnsNilOnFailure() {
        let obj = FailingJsonEncodable()

        let json = JsonUtils.toJsonString(obj)

        XCTAssertNil(json)
    }
}
