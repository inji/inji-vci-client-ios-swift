import Foundation

class ValidatorResult {
    var isValid: Bool = true
    var invalidFields: [String] = []

    init(isValid: Bool = true) {
        self.isValid = isValid
    }

    func addInvalidField(_ invalidField: String) {
        isValid = false
        invalidFields.append(invalidField)
    }
}
