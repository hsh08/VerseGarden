import Foundation

struct PasswordValidationResult {
    let hasMinimumLength: Bool
    let containsLetter: Bool
    let containsNumber: Bool
    let containsSpecialCharacter: Bool
    let matchesConfirmation: Bool

    var meetsContentRequirements: Bool {
        hasMinimumLength
            && containsLetter
            && containsNumber
            && containsSpecialCharacter
    }

    var isValid: Bool {
        meetsContentRequirements && matchesConfirmation
    }
}

enum AuthValidation {
    static let passwordPolicyMessage = "비밀번호는 8자 이상이며, 영문·숫자·특수문자를 모두 포함해야 합니다."

    static func validatePassword(_ password: String, confirmation: String) -> PasswordValidationResult {
        PasswordValidationResult(
            hasMinimumLength: password.count >= 8,
            containsLetter: password.range(of: "[A-Za-z]", options: .regularExpression) != nil,
            containsNumber: password.range(of: "[0-9]", options: .regularExpression) != nil,
            containsSpecialCharacter: password.range(of: "[!@#$%^&*()_+\\-=\\?\\.,]", options: .regularExpression) != nil,
            matchesConfirmation: !password.isEmpty && password == confirmation
        )
    }

    static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty,
              parts[1].contains(".") else {
            return false
        }

        return true
    }
}
