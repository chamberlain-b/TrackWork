import Foundation
import SwiftData

/// Saves the policy in its own transaction, without saving or rolling back live attendance edits.
@MainActor
struct WorkPolicyEditor {
    enum ValidationError: LocalizedError, Equatable {
        case invalid(String)
        case missingMonth

        var errorDescription: String? {
            switch self {
            case .invalid(let message): message
            case .missingMonth: "The effective month could not be determined. Please try again."
            }
        }
    }

    private let container: ModelContainer
    private let persist: (ModelContext) throws -> Void

    init(
        container: ModelContainer,
        save: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.container = container
        persist = save
    }

    @discardableResult
    func save(
        draft: WorkPolicyDraft,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) throws -> UUID {
        if let message = draft.validationMessage {
            throw ValidationError.invalid(message)
        }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let rules = try context.fetch(FetchDescriptor<ComplianceRule>())
        let resolver = ComplianceRuleResolver()
        let activeRule = resolver.currentRule(from: rules, now: now)

        // Merely reviewing and confirming an existing policy does not create history.
        if let activeRule, draft.matches(activeRule) {
            return activeRule.id
        }

        let rule: ComplianceRule
        if let activeRule {
            guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
                throw ValidationError.missingMonth
            }
            let thisMonthRules = rules.filter {
                $0.effectiveFrom.map { calendar.isDate($0, inSameDayAs: monthStart) } ?? false
            }
            if let existing = resolver.currentRule(from: thisMonthRules, now: now) {
                rule = existing
            } else {
                rule = resolver.copy(activeRule, effectiveFrom: monthStart, now: now)
                context.insert(rule)
            }
        } else {
            // The first deliberately chosen policy also covers any manually entered history.
            // Subsequent edits create a dated version and preserve that initial policy.
            rule = ComplianceRule(name: "Work policy", effectiveFrom: nil, createdAt: now, updatedAt: now)
            context.insert(rule)
        }
        draft.apply(to: rule, now: now)
        do {
            try persist(context)
            return rule.id
        } catch {
            context.rollback()
            throw error
        }
    }
}
