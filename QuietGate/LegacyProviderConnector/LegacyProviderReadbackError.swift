import Foundation

enum LegacyProviderReadbackError: LocalizedError, Equatable {
  case addedDomainNotConfirmed(String)
  case removedDomainStillPresent(String)
  case categoryNotConfirmed(String)
  case ruleStatusUnknown(String)
  case ruleTurnedOffButNotConfirmed(String)
  case ruleTurnedOffButMacStillBlocks(String)
  case ruleTurnedOffButProofInconclusive(String)
  case pendingRulesNotConfirmed

  var errorDescription: String? {
    switch self {
    case .addedDomainNotConfirmed(let domain):
      return "QuietGate could not confirm \(domain), so the site was left off."
    case .removedDomainStillPresent(let domain):
      return "QuietGate could not confirm \(domain) was removed, so the site was left on."
    case .categoryNotConfirmed(let title):
      return "QuietGate could not confirm \(title) changed, so the switch was left unchanged."
    case .ruleStatusUnknown(let domain):
      return "QuietGate could not check \(domain) after changing it. The rule is saved, but it is not confirmed yet."
    case .ruleTurnedOffButNotConfirmed(let domain):
      return "QuietGate could not finish turning off \(domain), so it put the switch back."
    case .ruleTurnedOffButMacStillBlocks(let domain):
      return "QuietGate turned \(domain) off, but this Mac still appears to block it somewhere else."
    case .ruleTurnedOffButProofInconclusive(let domain):
      return "QuietGate could not finish turning off \(domain), so it put the switch back."
    case .pendingRulesNotConfirmed:
      return "QuietGate is still applying saved changes. This can take about a minute."
    }
  }
}
