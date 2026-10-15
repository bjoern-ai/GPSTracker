import SwiftUI

struct SettingsView: View {
    @AppStorage(WordPressClient.siteURLKey) private var siteURL = WordPressClient.defaultSiteURL
    @AppStorage(WordPressClient.usernameKey) private var username = ""
    @State private var password = KeychainHelper.read(account: WordPressClient.passwordAccount) ?? ""

    private enum TestState {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    @State private var testState: TestState = .idle

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Website-URL", text: $siteURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Benutzername", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Anwendungspasswort", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: password) { _, newValue in
                            KeychainHelper.save(newValue, account: WordPressClient.passwordAccount)
                        }
                } header: {
                    Text("WordPress")
                } footer: {
                    Text("Das Anwendungspasswort erstellst du in WordPress unter Benutzer → Profil → Anwendungspasswörter. Es wird sicher im Schlüsselbund gespeichert.")
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Verbindung testen")
                            Spacer()
                            if case .testing = testState {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isTesting)

                    switch testState {
                    case .idle, .testing:
                        EmptyView()
                    case .success(let name):
                        Label("Verbunden als \(name)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Einstellungen")
        }
    }

    private var isTesting: Bool {
        if case .testing = testState { return true }
        return false
    }

    private func testConnection() {
        testState = .testing
        Task {
            do {
                let name = try await WordPressClient.fromSettings().testConnection()
                testState = .success(name)
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}

#Preview {
    SettingsView()
}
