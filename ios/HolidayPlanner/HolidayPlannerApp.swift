import SwiftUI

@main
struct HolidayPlannerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: PlanDocument()) { file in
            PlanView(document: file.$document)
        }
    }
}
