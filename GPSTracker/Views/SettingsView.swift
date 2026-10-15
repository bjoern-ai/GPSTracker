import SwiftUI

struct SettingsView: View {
    // Edited locally and saved shortly after typing stops, so keystrokes never wait for the Keychain.
    @State private var siteURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoaded = false

    private enum Field { case siteURL, username, password }
    @FocusState private var focusedField: Field?

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
                        .focused($focusedField, equals: .siteURL)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .username }
                    TextField("Benutzername", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                    SecureField("Anwendungspasswort", text: $password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
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
            .scrollDismissesKeyboard(.interactively)
            .onAppear(perform: load)
            .onDisappear(perform: save)
            .task(id: [siteURL, username, password]) {
                guard isLoaded else { return }
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                save()
            }
        }
    }

    private func load() {
        guard !isLoaded else { return }
        let defaults = UserDefaults.standard
        siteURL = defaults.string(forKey: WordPressClient.siteURLKey) ?? WordPressClient.defaultSiteURL
        username = defaults.string(forKey: WordPressClient.usernameKey) ?? ""
        password = KeychainHelper.read(account: WordPressClient.passwordAccount) ?? ""
        isLoaded = true
    }

    private func save() {
        guard isLoaded else { return }
        let defaults = UserDefaults.standard
        defaults.set(siteURL, forKey: WordPressClient.siteURLKey)
        defaults.set(username, forKey: WordPressClient.usernameKey)
        if password != KeychainHelper.read(account: WordPressClient.passwordAccount) ?? "" {
            KeychainHelper.save(password, account: WordPressClient.passwordAccount)
        }
    }

    private var isTesting: Bool {
        if case .testing = testState { return true }
        return false
    }

    private func testConnection() {
        focusedField = nil
        save()
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
