import SwiftUI
import UIKit
import AVFoundation
import Foundation

// MARK: - kuvan koon muutos
private extension UIImage {
    /// Palauttaa kuvan, jonka suurin sivu on enintään `maxDimension` (säilyttää kuvasuhteen).
    func downscaled(maxDimension: CGFloat = 1280) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}


// MARK: - Värit
private extension Color {
    static let appMinusRed  = Color(red: 204/255, green: 0/255,   blue: 0/255)      // #cc0000
    static let appPlusGreen = Color(red: 106/255, green: 168/255, blue: 79/255)     // #6aa84f
}

// MARK: - Pressable Button Style (skaala-animaatio)
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Pitkä painallus + auto-repeat -nappi
/// - Tap: suorittaa onTap (±1)
/// - Long press: juoksee onRepeat (±5) ~interval välein, kunnes vapautetaan
struct AutoRepeatCircleButton: View {
    let title: String
    let bgColor: Color
    let size: CGFloat
    let onTap: () -> Void
    let onRepeat: () -> Void

    @State private var timer: Timer?
    // Muokattavat aikamääreet:
    private let interval: TimeInterval = 0.35       // toistoväli long pressissä
    private let longPressThreshold: TimeInterval = 0.7 // kuinka pitkään ennen kuin alkaa juosta

    var body: some View {
        Text(title)
            .font(.title3.bold())
            .frame(width: size, height: size)
            .background(bgColor.opacity(0.18))
            .clipShape(Circle())
            .contentShape(Circle())
            .onTapGesture {
                onTap()
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
            .onLongPressGesture(minimumDuration: longPressThreshold, maximumDistance: 44, pressing: { pressing in
                if pressing {
                    startTimer()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    stopTimer()
                }
            }, perform: { })
            .buttonStyle(PressableButtonStyle())
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            onRepeat()
            let gen = UIImpactFeedbackGenerator(style: .soft)
            gen.impactOccurred(intensity: 0.5)
        }
        if let timer { RunLoop.current.add(timer, forMode: .common) }
    }
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct ContentView: View {
    // Kieli & asetukset
    @AppStorage("appLanguage") private var appLanguage: String = "FI"
    @AppStorage("showHintField") private var showHintField = true

    // Shortcut
    @AppStorage("shortcutEnabled") private var shortcutEnabled = true
    @AppStorage("shortcutName") private var shortcutName = ""
    @AppStorage("shortcutSendJSON") private var shortcutSendJSON = true

    // Kuva & picker
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var showLibrary = false

    // Prosessin tila
    @State private var isRunning = false
    @State private var errorMessage: String?

    // Tulokset — StageMealResult
    @State private var stageResult: StageMealResult?
    @State private var rawDebug: String = ""

    // UI-säädettävät arvot (±1 / ±5 long press)
    @State private var carbsVal: Double?
    @State private var fatVal: Double?
    @State private var proteinVal: Double?

    // Lisävihje (UI)
    @State private var userHintText: String = ""

    // AI-päättely sheet
    @State private var showReasoningSheet = false

    // Shortcut ilmoitus
    @State private var showShortcutAlert = false
    @State private var shortcutAlertMessage = ""
    
    // Peruuta/backoff
    @State private var analysisTask: Task<Void, Never>? = nil
    @State private var infoMessage: String?

    


    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Kuva
                        imagePreview

                        // Lisävihje-kenttä
                        if showHintField {
                            TextField(loc("Lisävihje (valinnainen)",
                                          en: "Optional hint (e.g., weights, sauces)"),
                                      text: $userHintText)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                        }

                        // Tilaviesti
                        if isRunning {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text(loc("Analysoidaan…", en: "Analyzing…"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .scale))
                        }

                        // Info (neutraali) – esim. peruutus
                        if let info = infoMessage, !info.isEmpty {
                            Text(info)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }

                        // Virhe (punainen)
                        if let err = errorMessage, !err.isEmpty {
                            Text(err)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }


                        // Tuloslaatikko
                        if stageResult != nil {
                            resultsBox
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Alapalkki
                bottomBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("") // ei vie tilaa yläreunassa
            .toolbar {
                // Vasen: roskakori
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        clearAll()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .accessibilityLabel(loc("Tyhjennä analyysi", en: "Clear analysis"))
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                // Oikea: Shortcut (jos käytössä) + asetukset
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if shortcutEnabled {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            // ✅ käyttää nyt no-arg wrapperia
                            runShortcutWithOptionalJSON()
                        } label: {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                                .accessibilityLabel(loc("Suorita Shortcut", en: "Run Shortcut"))
                        }
                        .disabled(shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(PressableButtonStyle())
                    }

                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            // Kamera ja kirjasto
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera) { image in
                    selectedImage = image
                    clearResultsOnly()
                }
            }
            .sheet(isPresented: $showLibrary) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    selectedImage = image
                    clearResultsOnly()
                }
            }
            // AI-päättely
            .sheet(isPresented: $showReasoningSheet) {
                reasoningSheetView()
                    .presentationDetents([.medium, .large])
            }
            // Shortcut-kuittaus
            .alert(loc("Shortcut", en: "Shortcut"), isPresented: $showShortcutAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(shortcutAlertMessage)
            }
            // ✅ Shortcuts x-callback palaa tähän
            .onOpenURL { url in
                handleCallbackURL(url)
            }
        }
    }

    // MARK: - Kuvaesikatselu

    private var imagePreview: some View {
        Group {
            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.18)))
                    .padding(.horizontal)
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 220)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(loc("Ei kuvaa valittuna", en: "No image selected"))
                                .foregroundColor(.secondary)
                        }
                    )
                    .padding(.horizontal)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Tuloslaatikko

    private var resultsBox: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(loc("Analyysin tulos", en: "Analysis Result"))
                .font(.headline)

            // Arvorivit: “- XX g +” (värit + long press auto-repeat)
            VStack(spacing: 10) {
                adjustableRow(title: "Carbs", value: Binding(
                    get: { carbsVal ?? currentCarbsDefault() },
                    set: { carbsVal = max(0, $0) }
                ))
                adjustableRow(title: "Fat", value: Binding(
                    get: { fatVal ?? currentFatDefault() },
                    set: { fatVal = max(0, $0) }
                ))
                adjustableRow(title: "Proteins", value: Binding(
                    get: { proteinVal ?? currentProteinDefault() },
                    set: { proteinVal = max(0, $0) }
                ))
            }

            // Kopiointinapit arvojen alla (kolmijakona)
            HStack(spacing: 10) {
                copyButton(label: "Carbs", value: carbsVal ?? currentCarbsDefault())
                copyButton(label: "Fat", value: fatVal ?? currentFatDefault())
                copyButton(label: "Proteins", value: proteinVal ?? currentProteinDefault())
            }

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        // iOS 17+: kahden parametrin onChange
        .onChange(of: stageResult?.analysis.totals.carbs_g) { _, _ in
            syncUIValuesIfNeeded()
        }
    }

    // Yksi rivi: − [XX g] +
    private func adjustableRow(title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(width: 95, alignment: .leading)

            // Miinus: tap = −1, long = toistona −5
            AutoRepeatCircleButton(
                title: "−",
                bgColor: .appMinusRed,
                size: 32,
                onTap: { value.wrappedValue = max(0, value.wrappedValue - 1) },
                onRepeat: { value.wrappedValue = max(0, value.wrappedValue - 5) }
            )

            Text("\(formatted(value.wrappedValue)) g")
                .font(.title3.monospacedDigit())
                .frame(minWidth: 80, alignment: .center)

            // Plus: tap = +1, long = toistona +5
            AutoRepeatCircleButton(
                title: "+",
                bgColor: .appPlusGreen,
                size: 32,
                onTap: { value.wrappedValue = value.wrappedValue + 1 },
                onRepeat: { value.wrappedValue = value.wrappedValue + 5 }
            )

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Kopiointinapit

    private func copyButton(label: String, value: Double) -> some View {
        Button {
            UIPasteboard.general.string = numberForCopy(value)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(label)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Ota kuva
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openCamera()
            } label: {
                VStack {
                    Image(systemName: "camera")
                    Text(loc("Ota kuva", en: "Camera"))
                }
            }
            .buttonStyle(PressableButtonStyle())
            .frame(maxWidth: .infinity)

            // Analysoi (tai Peruuta jos käynnissä)
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                if isRunning {
                    // ✅ Peruuttaa käynnissä olevan analyysin, EI aloita uutta
                    analysisTask?.cancel()
                    return
                }

                // Käynnistä uusi analyysi vain kun ei käynnissä
                analysisTask = Task { await analyzeNow() }
            } label: {
                VStack {
                    Image(systemName: isRunning ? "xmark.circle" : "wand.and.stars")
                    Text(isRunning ? loc("Peruuta", en: "Cancel")
                                   : loc("Analysoi", en: "Analyze"))
                }
            }
            // ÄLÄ disabloi analyysin aikana, jotta voit peruuttaa
            .disabled(selectedImage == nil)
            .frame(maxWidth: .infinity)
            .buttonStyle(PressableButtonStyle())

            // Valitse kirjastosta
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showLibrary = true
            } label: {
                VStack {
                    Image(systemName: "photo.on.rectangle")
                    Text(loc("Valitse", en: "Select"))
                }
            }
            .buttonStyle(PressableButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemGray6))
    }

    // MARK: - Kamera

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Ei kameraa -> avaa kirjasto
            showLibrary = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.showCamera = true }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.showCamera = true }
                    else { self.showLibrary = true }
                }
            }
        default:
            // Kielletty -> avaa kirjasto tai näytä alert
            self.showLibrary = true
        }
    }

    // MARK: - AI-päättelyn sheet

    @ViewBuilder
    private func reasoningSheetView() -> some View {
        NavigationView {
            ScrollView {
                Text(rawReasoningText())
                    .textSelection(.enabled) // kopioitavissa
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(loc("AI-päättely", en: "AI reasoning"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func rawReasoningText() -> String {
        guard let s = stageResult else { return "" }
        var parts: [String] = []

        let a = s.selvitys.trimmingCharacters(in: .whitespacesAndNewlines)
        if !a.isEmpty { parts.append(a) }

        if let per = s.analysis.per100g {
            let line = "\(loc("Ravintoarvot 100 g kohti", en: "Per 100 g")):\n" +
            "Carbs: \(formatted(per.carbs_g)) g, " +
            "Fat: \(formatted(per.fat_g)) g, " +
            "Proteins: \(formatted(per.protein_g)) g"
            parts.append(line)
        }

        let b = s.reasoning.trimmingCharacters(in: .whitespacesAndNewlines)
        if !b.isEmpty { parts.append(b) }

        return parts.joined(separator: "\n\n")
    }

    /// Palauttaa true, jos virhe on käyttäjän / tehtävän peruutus.
    private func isUserCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlErr = error as? URLError, urlErr.code == .cancelled { return true } // URLSession -999
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return true } // varmistus
        if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError { return true }
        // Jos ollaan peruutustilassa, varmuuden vuoksi tulkitaan peruutukseksi
        if Task.isCancelled { return true }
        return false
    }
 // MARK: - Analyze

    
    private func analyzeNow() async {
        guard let img = selectedImage else { return }
        let downsized = img.downscaled(maxDimension: 1280)
        guard let data = downsized.jpegData(compressionQuality: 0.8) else { return }

        // Alustus joka kerta kun analyysi alkaa
        withAnimation { isRunning = true }
        errorMessage = nil
        infoMessage  = nil

        // Nollaa tila aina lopuksi (onnistui / virhe / peruutus)
        defer {
            withAnimation { isRunning = false }
            analysisTask = nil
        }

        do {
            let (stage, raw) = try await MealAnalyzer.shared.analyzeMeal(imageData: data)
            self.stageResult = stage
            self.rawDebug = raw
            syncUIValuesFromStage()
        } catch {
            if isUserCancellation(error) {
                // ✅ Peruutus on neutraali ilmoitus, ei virhe
                self.infoMessage = loc("Peruutettu.", en: "Cancelled.")
                self.errorMessage = nil
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                self.errorMessage = "Virhe: \(error.localizedDescription)"
                self.infoMessage = nil
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }



    // MARK: - Sync tuloksista UI-arvoihin

    private func syncUIValuesFromStage() {
        guard let s = stageResult else {
            carbsVal = nil; fatVal = nil; proteinVal = nil
            return
        }
        carbsVal   = s.analysis.totals.carbs_g
        fatVal     = s.analysis.totals.fat_g
        proteinVal = s.analysis.totals.protein_g
    }

    private func syncUIValuesIfNeeded() {
        if carbsVal == nil || fatVal == nil || proteinVal == nil {
            syncUIValuesFromStage()
        }
    }

    // MARK: - Helpers (formatointi, kopiointi, oletukset, lokalisointi)

    private func formatted(_ v: Double) -> String {
        let v1 = (v * 10).rounded() / 10
        if v1.rounded() == v1 { return String(Int(v1)) }
        return String(format: "%.1f", v1)
    }

    /// Kopioidaan vain numero, pilkkudesimaalilla (X,X) jos desimaaleja
    private func numberForCopy(_ v: Double) -> String {
        let v1 = (v * 10).rounded() / 10
        if v1.rounded() == v1 {
            return String(Int(v1))
        } else {
            let s = String(format: "%.1f", v1)
            return s.replacingOccurrences(of: ".", with: ",")
        }
    }

    private func currentCarbsDefault() -> Double {
        stageResult?.analysis.totals.carbs_g ?? 0
    }
    private func currentFatDefault() -> Double {
        stageResult?.analysis.totals.fat_g ?? 0
    }
    private func currentProteinDefault() -> Double {
        stageResult?.analysis.totals.protein_g ?? 0
    }

    // Yksinkertainen lokalisointiapu
    private func loc(_ fi: String, en: String? = nil) -> String {
        if appLanguage == "FI" { return fi }
        return en ?? fi
    }

    /// Palauttaa nykyiset (mahd. käyttäjän säätämät) arvot tai mallin oletukset.
    private func currentMacroInts() -> (carbs: Int, fat: Int, protein: Int)? {
        let c = Int((carbsVal ?? stageResult?.analysis.totals.carbs_g ?? 0).rounded())
        let f = Int((fatVal ?? stageResult?.analysis.totals.fat_g ?? 0).rounded())
        let p = Int((proteinVal ?? stageResult?.analysis.totals.protein_g ?? 0).rounded())
        if c == 0, f == 0, p == 0 { return nil }
        return (c, f, p)
    }


    // MARK: - Shortcuts: compact JSON rakentaja
    /// Palauttaa Shortcutille lähetettävän JSONin muodossa:
    /// {"carbs": 45, "protein": 20, "fat": 15}
    private func buildCompactShortcutJSON() -> String? {
        guard let ints = currentMacroInts() else { return nil }

        // Vain vaaditut kentät, ilman "_g" -päätteitä tai ylimääräisiä meta-arvoja
        let payload: [String: Int] = [
            "carbs":   ints.carbs,
            "protein": ints.protein,
            "fat":     ints.fat
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }


    // MARK: - Shortcuts: no-arg wrapper, käyttää compact JSONia

    func runShortcutWithOptionalJSON() {
        let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)

        var jsonString: String? = nil
        if shortcutSendJSON {
            jsonString = buildCompactShortcutJSON()
            if jsonString == nil {
                shortcutAlertMessage = loc("Ei lähetettäviä arvoja. Tee analyysi ensin tai säädä arvoja.", en: "No values to send. Run an analysis first or adjust values.")
                showShortcutAlert = true
                return
            }
        }

        runShortcutWithOptionalJSON(shortcutName: name, json: jsonString)
    }


    // Avaa iOS Shortcuts -appiin valitun Shortcutin ja välittää JSONin turvallisesti
    func runShortcutWithOptionalJSON(shortcutName: String, json: String?) {
        let trimmed = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            shortcutAlertMessage = loc("Määritä Shortcuttin nimi asetuksissa.", en: "Define the Shortcut name in Settings.")
            showShortcutAlert = true
            return
        }

        // Rakennetaan shortcuts://x-callback-url/run-shortcut?...
        var comps = URLComponents()
        comps.scheme = "shortcuts"
        comps.host   = "x-callback-url"
        comps.path   = "/run-shortcut"

        var items: [URLQueryItem] = [
            URLQueryItem(name: "name",      value: trimmed),
            URLQueryItem(name: "x-success", value: "mealai://done"),
            URLQueryItem(name: "x-error",   value: "mealai://error"),
            URLQueryItem(name: "x-cancel",  value: "mealai://cancel"),
        ]

        // Välitä analyysin JSON Shortcutsille "input"-kentässä vain jos sitä löytyy
        if let j = json, !j.isEmpty {
            items.append(URLQueryItem(name: "input", value: j))
        }
        comps.queryItems = items

        guard let url = comps.url else {
            shortcutAlertMessage = loc("Virheellinen Shortcuts-URL.", en: "Invalid Shortcuts URL.")
            showShortcutAlert = true
            return
        }

        UIApplication.shared.open(url) { ok in
            if !ok {
                shortcutAlertMessage = loc("Shortcutsin avaaminen epäonnistui.", en: "Failed to open Shortcuts.")
                showShortcutAlert = true
            }
        }
    }

    // ✅ Shortcuts x-callback tulkinta — sijoitettu ContentView’n SISÄLLE
    private func handleCallbackURL(_ url: URL) {
        guard url.scheme == "mealai" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch url.host {
        case "done":
            shortcutAlertMessage = loc("Pikakuvake suoritettu ✅", en: "Shortcut finished ✅")
            showShortcutAlert = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

        case "error":
            // yritetään poimia selitysteksti (esim. ?error=Something)
            let reason = comps?.queryItems?.first(where: { $0.name == "error" || $0.name == "message" })?.value
            shortcutAlertMessage = reason ?? loc("Pikakuvake epäonnistui ❌", en: "Shortcut failed ❌")
            showShortcutAlert = true

        case "cancel":
            // Ei näytetä alertia peruutuksesta, mutta voit halutessa näyttää:
            // shortcutAlertMessage = loc("Peruit Shortcutsin.", en: "Shortcut was cancelled.")
            // showShortcutAlert = true
            break

        default:
            break
        }
    }

    // MARK: - Clear

    private func clearResultsOnly() {
        stageResult = nil
        errorMessage = nil
        infoMessage = nil
        rawDebug = ""
        carbsVal = nil; fatVal = nil; proteinVal = nil
    }

    private func clearAll() {
        selectedImage = nil
        clearResultsOnly()
    }
}
