import Foundation

/// Everything user-facing that changes per app. Compiled into both the app and the widget,
/// so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Apprentice Hours"
    static let bundleID = "com.example.apprentice-hours"
    static let appGroupID = "group.com.example.apprentice-hours"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.
    static let appStoreID = ""

    // MARK: Sync
    static let iCloudSyncEnabled = false

    // MARK: StoreKit
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/apprentice-hours/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    static let entryNoun = "Entry"
    static let entryNounPlural = "Entries"
    static let exportFileStem = "apprentice-hours"

    /// The boundary. Requirements differ by state, sponsor and trade, so the app holds the
    /// apprentice's own numbers and never claims to know the programme.
    static let disclaimer = """
    You enter the hours and the work processes your own standards of apprenticeship require. \
    Apprentice Hours adds up what you log against those numbers and prints it. \
    It is not your sponsor, your JATC or your state apprenticeship agency, and what you submit \
    still has to match the forms and sign-offs they ask for.
    """

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "chart.bar.fill", title: "Hours where they count",
                       body: "Not just a timesheet. Every hour lands on a work process, so you can see which one you are short on."),
        OnboardingPage(symbol: "signature", title: "Signed before it is due",
                       body: "Mark hours signed off by your journeyman as you go, and see at a glance what is still unsigned."),
        OnboardingPage(symbol: "doc.text.fill", title: "The report your sponsor wants",
                       body: "A PDF for any period with the hours by work process, the totals to date and a signature block."),
    ]

    static let paywallSymbol = "hammer.fill"
    static let paywallHeadline = "Unlock Apprentice Hours"
    static let paywallBenefits = [
        "Unlimited hours, work processes and classes",
        "Progress against every required minimum",
        "Sign-off tracking and unsigned-hours warnings",
        "Sponsor PDF and CSV for any period",
        "No account, no server, nothing leaves your phone",
    ]

    // MARK: How-to guide
    static let howToIntro = "Five steps from install to the report your sponsor asks for. Each takes under a minute."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "person.text.rectangle", title: "Set up your programme",
                  body: "Tap Set Up on the Progress tab. Enter your name and apprentice number, pick your trade, and type the total on-the-job and classroom hours your standards require.",
                  tip: "If you already have credited hours, put them in Hours already credited so your totals start correct."),
        HowToStep(symbol: "list.bullet.rectangle", title: "Check the work processes",
                  body: "Your trade comes with a starter list. Go to Setup → Work Processes and change the names and the required hours to match your own standards exactly.",
                  tip: "Set required hours to 0 for a process you track without a minimum."),
        HowToStep(symbol: "plus.circle", title: "Log a day",
                  body: "Tap + on the Hours tab, pick the work process, enter the hours and the job site, and save. Most days are one tap on a recent process plus the hours.",
                  tip: "Say \"Log hours in Apprentice Hours\" to Siri to jump straight to a new entry."),
        HowToStep(symbol: "signature", title: "Get them signed",
                  body: "When your journeyman signs the period, open the Report tab, choose the period and tap Mark Signed. Unsigned hours are flagged on the Progress tab until then."),
        HowToStep(symbol: "square.and.arrow.up", title: "Send the report",
                  body: "Report tab, choose the period, then PDF for your sponsor. CSV for every entry is on the same screen."),
        HowToStep(symbol: "rectangle.on.rectangle", title: "Add the widget",
                  body: "Long-press your Home Screen, tap +, search \"Apprentice Hours\", and add the widget to see your total and this period at a glance."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`).
    static let mockPrices = (annual: "$9.99", lifetime: "$24.99")

    // MARK: Behaviour
    static let reviewAfterSuccesses = 6
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
