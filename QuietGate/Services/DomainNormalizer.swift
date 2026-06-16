import Darwin
import Foundation

protocol DomainResolutionChecking {
  func addresses(for domain: String) async -> [String]
}

struct DomainResolutionStatus: Equatable {
  let domain: String
  let addresses: [String]

  var isSinkholed: Bool {
    addresses.contains(where: Self.isSinkholeAddress)
  }

  var provesUnblocked: Bool {
    !addresses.isEmpty && !isSinkholed
  }

  var isInconclusive: Bool {
    addresses.isEmpty
  }

  private static func isSinkholeAddress(_ address: String) -> Bool {
    let normalized = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "0.0.0.0"
      || normalized == "::"
      || normalized == "0:0:0:0:0:0:0:0"
      || normalized == "::1"
      || normalized.hasPrefix("127.")
  }
}

struct SystemDomainResolver: DomainResolutionChecking {
  func addresses(for domain: String) async -> [String] {
    await Task.detached(priority: .utility) {
      Self.lookupAddresses(for: domain)
    }.value
  }

  private static func lookupAddresses(for domain: String) -> [String] {
    var hints = addrinfo()
    hints.ai_family = AF_UNSPEC

    var result: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(domain, nil, &hints, &result) == 0,
          let firstResult = result
    else {
      return []
    }
    defer { freeaddrinfo(firstResult) }

    var addresses = Set<String>()
    var current: UnsafeMutablePointer<addrinfo>? = firstResult
    while let pointer = current {
      let info = pointer.pointee
      if let socketAddress = info.ai_addr {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let code = getnameinfo(
          socketAddress,
          socklen_t(info.ai_addrlen),
          &host,
          socklen_t(host.count),
          nil,
          0,
          NI_NUMERICHOST
        )
        if code == 0 {
          addresses.insert(String(cString: host))
        }
      }
      current = info.ai_next
    }
    return addresses.sorted()
  }
}

enum DomainNormalizationError: LocalizedError, Equatable {
  case empty
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case .empty:
      return "Enter a domain."
    case .invalid(let value):
      return "\"\(value)\" is not a valid domain."
    }
  }
}

enum DomainNormalizer {
  static func normalize(_ input: String) throws -> String {
    var candidate = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    guard !candidate.isEmpty else {
      throw DomainNormalizationError.empty
    }

    if let components = URLComponents(string: candidate.contains("://") ? candidate : "https://\(candidate)"),
       let host = components.host,
       !host.isEmpty {
      candidate = host
    } else {
      candidate = candidate.components(separatedBy: "/").first ?? candidate
    }

    if candidate.hasPrefix("*.") {
      candidate.removeFirst(2)
    }
    while candidate.hasPrefix(".") {
      candidate.removeFirst()
    }
    while candidate.hasSuffix(".") {
      candidate.removeLast()
    }

    guard isValidDomain(candidate) else {
      throw DomainNormalizationError.invalid(candidate)
    }
    return candidate
  }

  private static func isValidDomain(_ value: String) -> Bool {
    guard value.count <= 253,
          value.contains("."),
          !value.contains(".."),
          value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          value.canBeConverted(to: .ascii),
          !isIPv4Address(value) else {
      return false
    }

    let labels = value.components(separatedBy: ".")
    return labels.allSatisfy { label in
      guard !label.isEmpty, label.count <= 63 else { return false }
      guard label.first != "-", label.last != "-" else { return false }
      return label.unicodeScalars.allSatisfy { scalar in
        (97...122).contains(Int(scalar.value)) ||
          (48...57).contains(Int(scalar.value)) ||
          scalar.value == 45
      }
    }
  }

  private static func isIPv4Address(_ value: String) -> Bool {
    let parts = value.components(separatedBy: ".")
    guard parts.count == 4 else { return false }
    return parts.allSatisfy { part in
      guard let number = Int(part), String(number) == part else { return false }
      return (0...255).contains(number)
    }
  }
}
