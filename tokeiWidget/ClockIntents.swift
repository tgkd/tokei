import AppIntents
import WidgetKit

struct AdjustTimeIntent: AppIntent {
    static let title: LocalizedStringResource = "Adjust Time"
    static let description = IntentDescription("Shifts the world clock by a number of minutes.")

    @Parameter(title: "Minutes to Add")
    var minutesToAdd: Int

    init() {}

    init(minutes: Int) {
        minutesToAdd = minutes
    }

    func perform() async throws -> some IntentResult {
        let shifted = ZoneStorage.loadShift() + minutesToAdd
        ZoneStorage.saveShift(min(max(shifted, -72 * 60), 72 * 60))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct ResetTimeIntent: AppIntent {
    static let title: LocalizedStringResource = "Reset Time"
    static let description = IntentDescription("Returns the world clock to the current time.")

    func perform() async throws -> some IntentResult {
        ZoneStorage.saveShift(0)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
