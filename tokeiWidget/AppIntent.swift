import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "World Clock Configuration" }
    static var description: IntentDescription { "Configure your world clock widget time zones." }
}