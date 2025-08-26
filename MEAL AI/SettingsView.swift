import SwiftUI

struct SettingsView: View {
    // Kieli
    @AppStorage("appLanguage") private var appLanguage: String = "FI" // "FI" | "EN"

    // Pienempi datankulutus
    @AppStorage("preferSmallerOnCellular") private var preferSmallerOnCellular = false

    // UI
    @AppStorage("showHintField") private var showHintField: Bool = true

    // Shortcut
    @AppStorage("shortcutEnabled") private var shortcutEnabled: Bool = true
    @AppStorage("shortcutName") private var shortcutName: String = ""
    @AppStorage("shortcutSendJSON") private var shortcutSendJSON: Bool = true

    var body: some View {
        Form {
           
            // MARK: - Kieli
            Section(header: Text(loc("Kieli", en: "Language"))) {
                Picker(loc("Sovelluksen kieli", en: "App language"), selection: $appLanguage) {
                    Text("Suomi").tag("FI")
                    Text("English").tag("EN")
                }
                .pickerStyle(.segmented)
            }
            
            // MARK: - Käyttöliittymä
            Section(header: Text("Verkko")) {
                Toggle(isOn: $preferSmallerOnCellular) {
                    Text("Pienempi kuva mobiiliverkossa")
                }
                .help("Suomessa mobiili on usein kiinteähintainen; ulkomailla/prepaidilla säästää dataa.")
            }
            
            // MARK: - Käyttöliittymä
            Section(header: Text(loc("Käyttöliittymä", en: "Interface"))) {
                Toggle(loc("Näytä lisävihje-kenttä", en: "Show optional hint field"), isOn: $showHintField)

                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("Valokuvausvinkit", en: "Photo tips"))
                        .font(.subheadline).bold()
                    Text(loc(
                        "Parhaan tuloksen saat, kun kuvaat annoksen ylhäältä tai 45° kulmasta hyvässä valossa. Pidä koko lautanen kuvassa ja mieluiten jokin mittakaava (haarukka, käsi). Vältä liikettä ja tarkennuksen epäselvyyttä.",
                        en: "For best results, shoot from top-down or ~45° with good lighting. Keep the whole plate in view and include a scale cue (fork, hand). Avoid motion blur and ensure focus."
                    ))
                    .font(.footnote)
                    .foregroundColor(.secondary)

                    Text(loc("Mitä lisävihje tekee?", en: "What does the hint do?"))
                        .font(.subheadline).bold()
                        .padding(.top, 6)
                    Text(loc(
                        "Vihje välitetään analyysille (esim. 'kastiketta ~2 rkl', 'riisiä 200 g', 'ei pähkinää'). Se auttaa mallia arvioimaan määriä ja piilokomponentteja.",
                        en: "The hint is passed to the analysis (e.g., '~2 tbsp sauce', 'rice 200 g', 'no nuts'). It helps the model estimate quantities and hidden components."
                    ))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // MARK: - Shortcuts
            Section(header: Text("Shortcuts")) {
                Toggle(loc("Näytä pikakuvake yläpalkissa", en: "Show Shortcut button"), isOn: $shortcutEnabled)

                TextField(
                    loc("Shortcuttin nimi (esim. 'Play Spotify')", en: "Shortcut name (e.g. 'Play Spotify')"),
                    text: $shortcutName
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

                Toggle(loc("Lähetä makrot JSON‑inputtina", en: "Send macros as JSON input"), isOn: $shortcutSendJSON)

                Text(loc(
                    "Kun tämä on päällä, sovellus välittää Shortcutille JSON‑objektin: { \"carbs\": 00, \"fat\": 00, \"protein\": 00 }. Shortcutsissa käytä toimintoa “Get Dictionary from Input”.",
                    en: "When enabled, the app passes a JSON object to the Shortcut: { \"carbs\": 00, \"fat\": 00, \"protein\": 00 }. In Shortcuts, use “Get Dictionary from Input”."
                ))
                .font(.footnote)
                .foregroundColor(.secondary)

                Text(loc(
                    "Pikakuvakkeen painallus avaa Shortcuts-sovelluksen ja suorittaa annetun pikakuvakkeen.",
                    en: "Tapping the button opens Shortcuts and runs the specified shortcut."
                ))
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle(loc("Asetukset", en: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func explainQuality(_ mode: String) -> String {
        switch mode {
        case "premium":
            return loc(
                "Premium: AI arvioi painot ja sovellus laskee makrot koodilla. Sisältää laajan selityksen ja per 100 g ‑arvion.",
                en: "Premium: AI estimates component weights; the app computes macros deterministically. Includes rich explanation and per‑100 g values."
            )
        case "high":
            return loc(
                "High: AI antaa erittelyn ja selityksen (painot arvioidaan), makrot suoraan mallilta.",
                en: "High: AI provides a breakdown and explanation (weights estimated), macros directly from the model."
            )
        default:
            return loc(
                "Normal: Nopea ja kustannustehokas – suorat makrot mallilta, ytimekäs tulos.",
                en: "Normal: Fast and cost‑effective – direct macros from the model, concise result."
            )
        }
    }

    private func loc(_ fi: String, en: String? = nil) -> String {
        // Sama @AppStorage-avain kuin ContentView:issa
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "FI"
        if lang == "FI" { return fi }
        return en ?? fi
    }
}
