//
//  Publisher+Extensions.swift
//  SwiftUICombineHaveIBeenPwnedChallenge
//
//  Created by Peter Friese on 03.05.22.
//

import Foundation
import Combine

extension Publisher {
  func asResult() -> AnyPublisher<Result<Output, Failure>, Never> {
    self
      .map(Result.success)
      .catch { error in
        Just(.failure(error))
      }
      .eraseToAnyPublisher()
  }
}
