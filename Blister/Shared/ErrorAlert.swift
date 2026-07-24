import SwiftUI

/// A lightweight, reusable error the user should know about — most importantly a failed
/// `modelContext.save()`. Views hold an optional `ErrorAlert?` state and set it on failure instead
/// of swallowing the error into `Logger`, so a save that didn't stick surfaces an alert rather than
/// silently proceeding or dismissing (a data-loss risk).
struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(
        title: String = String(localized: "Couldn’t Save"),
        message: String = String(localized: "Something went wrong and your changes may not have been saved. Please try again.")
    ) {
        self.title = title
        self.message = message
    }
}

extension View {
    /// Presents `error` as a dismissible alert. Setting the bound state to a non-nil value shows it;
    /// dismissal clears it back to `nil`.
    func errorAlert(_ error: Binding<ErrorAlert?>) -> some View {
        alert(
            error.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { presented in if !presented { error.wrappedValue = nil } }
            ),
            presenting: error.wrappedValue
        ) { _ in
            Button(String(localized: "OK"), role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}
