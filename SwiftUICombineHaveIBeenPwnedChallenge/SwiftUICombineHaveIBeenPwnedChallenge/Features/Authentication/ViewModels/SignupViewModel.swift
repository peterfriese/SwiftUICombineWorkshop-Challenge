//
//  SignupViewModel.swift
//  SwiftUICombineHaveIBeenPwnedChallenge
//
//  Created by Peter Friese on 03.05.22.
//

import Foundation
import Combine

typealias Available = Result<Bool, Error>

enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated
}

private struct UserNameAvailableMessage: Codable {
    var isAvailable: Bool
    var userName: String
}

struct APIErrorMessage: Decodable {
  var error: Bool
  var reason: String
}

enum APIError: LocalizedError {
  case invalidRequestError(String)
  case transportError(Error)
  case invalidResponse
  case validationError(String)
  case decodingError(Error)
  case serverError(statusCode: Int, reason: String? = nil, retryAfter: String? = nil)

  var errorDescription: String? {
    switch self {
    case .invalidRequestError(let message):
      return "Invalid request: \(message)"
    case .transportError(let error):
      return "Transport error: \(error)"
    case .invalidResponse:
      return "Invalid response"
    case .validationError(let reason):
      return "Validation Error: \(reason)"
    case .decodingError:
      return "The server returned data in an unexpected format. Try updating the app."
    case .serverError(let statusCode, let reason, let retryAfter):
      return "Server error with code \(statusCode), reason: \(reason ?? "no reason given"), retry after: \(retryAfter ?? "no retry after provided")"
    }
  }
}

enum PasswordCheck {
    case valid
    case empty
    case noMatch
    case notLongEnough
}

class SignupViewModel: ObservableObject {
    // MARK: - Input
    @Published var username = ""
    @Published var password = ""
    @Published var confirmPassword  = ""
    
    // MARK: - Output
    @Published var isUsernameValid = false
    @Published var isPasswordEmpty = true
    @Published var isPasswordMatched = false
    @Published var isPasswordLengthSufficient = false
    @Published var isPasswordPwned = false
    @Published var isValid  = false
    @Published var errorMessage  = ""
    @Published var authenticationState = AuthenticationState.unauthenticated
    
    lazy var isUsernameAvailablePublisher: AnyPublisher<Available, Never> = {
        $username
            .print("1: ")
            .dropFirst()
            .debounce(for: 0.8, scheduler: DispatchQueue.main)
            .removeDuplicates()
            .print("2: ")
            .flatMap { value in
                self.checkUserNameAvailable(userName: value)
                    .asResult()
            }
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
    }()
    
    lazy var isPasswordValidPublisher: AnyPublisher<PasswordCheck, Never>  = {
        Publishers.CombineLatest3($isPasswordEmpty, $isPasswordMatched, $isPasswordLengthSufficient)
            .map { (isPasswordEmpty, isPasswordMatched, isPasswordLengthSufficient) in
                if isPasswordEmpty {
                    return .empty
                }
                else if !isPasswordMatched {
                    return .noMatch
                }
                else if !isPasswordLengthSufficient {
                    return .notLongEnough
                }
                else {
                    return .valid
                }
            }
            .eraseToAnyPublisher()
    }()
    
    lazy var isFormValidPublisher: AnyPublisher<Bool, Never> = {
        isUsernameAvailablePublisher
            .map { result -> Bool in
                if case .failure(let error) = result {
                    if case APIError.transportError(_) = error {
                        return true
                    }
                    return false
                }
                if case .success(let isAvailable) = result {
                    return isAvailable
                }
                return true
            }
            .print("isUsernameAvailablePublisher")
            .combineLatest($isUsernameValid, isPasswordValidPublisher) { (isUsernameAvailable, isUsernameValid, isPasswordValid) in
                // TODO: make sure form is not valid if password is pwned
                isUsernameAvailable && isUsernameValid && (isPasswordValid == .valid)
            }
            .print("isFormValidPublisher")
            .eraseToAnyPublisher()
    }()
    
    lazy var errorMessagePublisher: AnyPublisher<String, Never> = {
        isUsernameAvailablePublisher
            .map { result -> String in
                switch result {
                case .failure(let error):
                    if case APIError.transportError(_) = error {
                        return ""
                    }
                    else if case APIError.validationError(let reason) = error {
                        return reason
                    }
                    else {
                        return error.localizedDescription
                    }
                case .success(let isAvailable):
                    return isAvailable ? "" : "This username is not available"
                }
            }
            .combineLatest($isUsernameValid, isPasswordValidPublisher) { isUsernameAvailableMessage, isUsernameValid, isPasswordValid in
                if !isUsernameAvailableMessage.isEmpty {
                    return isUsernameAvailableMessage
                }
                else if !isUsernameValid {
                    return "Username is invalid. Must be more than 2 characters"
                }
                // TODO: issue warning message if password is pwned
                else if isPasswordValid != .valid {
                    switch isPasswordValid {
                    case .noMatch:
                        return "Passwords don't match"
                    case .empty:
                        return "Password must not be empty"
                    case .notLongEnough:
                        return "Password not long enough. Must at least be 6 characters"
                    default:
                        return ""
                    }
                }
                else {
                    return ""
                }
            }
            .eraseToAnyPublisher()
    }()
    
    init() {
        $username
            .map { value in
                value.count >= 3
            }
            .assign(to: &$isUsernameValid)
        
        $password
            .map { password in
                // TODO: implement Combine pipeline
                return true
            }
            .assign(to: &$isPasswordPwned)

        $password
            .map { $0.isEmpty }
            .assign(to: &$isPasswordEmpty)
        
        $password
            .combineLatest($confirmPassword)
            .map { (password, confirmPassword) in
                password == confirmPassword
            }
            .assign(to: &$isPasswordMatched)
        
        $password
            .map { $0.count >= 6 }
            .assign(to: &$isPasswordLengthSufficient)
        
        isFormValidPublisher
            .assign(to: &$isValid)
        
        errorMessagePublisher
            .assign(to: &$errorMessage)
    }
    
    func checkUserNameAvailable(userName: String) -> AnyPublisher<Bool, Error> {
        guard let url = URL(string: "http://127.0.0.1:8080/isUserNameAvailable?userName=\(userName)") else {
            return Fail(error: APIError.invalidRequestError("URL invalid"))
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            // handle URL errors (most likely not able to connect to the server)
            .mapError { error -> Error in
                return APIError.transportError(error)
            }
        
            // handle all other errors
            .tryMap { (data, response) -> (data: Data, response: URLResponse) in
                print("Received response from server, now checking status code")
                
                guard let urlResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                if (200..<300) ~= urlResponse.statusCode {
                }
                else {
                    let decoder = JSONDecoder()
                    let apiError = try decoder.decode(APIErrorMessage.self,
                                                      from: data)
                    
                    if urlResponse.statusCode == 400 {
                        throw APIError.validationError(apiError.reason)
                    }
                }
                return (data, response)
            }
            .map(\.data)
            .decode(type: UserNameAvailableMessage.self, decoder: JSONDecoder())
            .map(\.isAvailable)
            .print()
            .eraseToAnyPublisher()
    }
    
    func checkHaveIBeenPwned(password: String) -> AnyPublisher<Bool, Never> {
        // TODO: replace with the real implementation
        return Just(true)
            .eraseToAnyPublisher()
    }
}
