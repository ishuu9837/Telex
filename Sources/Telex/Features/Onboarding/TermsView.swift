import SwiftUI

struct TermsView: View {
    @Bindable var app: AppCoordinator
    @State private var agreed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(nsImage: BrandAssets.logo).resizable().frame(width: 42, height: 42)
                VStack(alignment: .leading) { Text("Terms of Service").font(.title2.bold()); Text("Telex · Version \(AppTerms.version)").font(.caption).foregroundStyle(.secondary) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(AppTerms.sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 7) { Text(section.title).font(.headline); Text(section.body).font(.system(size: 13)).lineSpacing(4).foregroundStyle(.secondary).textSelection(.enabled) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 10)
            }.frame(height: 330)
            if app.termsAccepted {
                Text("You agreed to this version on \((app.preferences.acceptedTermsAt ?? Date()).formatted(date: .abbreviated, time: .omitted)).").font(.caption).foregroundStyle(.secondary)
                HStack { Spacer(); Button("Close") { app.presentedSheet = nil }.keyboardShortcut(.cancelAction) }
            } else {
                Toggle("I have read and agree to these terms", isOn: $agreed).accessibilityIdentifier("terms.agreement")
                HStack {
                    Button("Decline & Quit", role: .cancel) { app.handlePrompterAction(.quit) }
                    Spacer()
                    Button("Agree & Continue") { app.acceptTerms() }.buttonStyle(.borderedProminent).disabled(!agreed).accessibilityIdentifier("terms.accept")
                }
            }
        }.padding(28).frame(width: 580).interactiveDismissDisabled()
    }
}
