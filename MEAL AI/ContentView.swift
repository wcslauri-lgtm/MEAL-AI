import SwiftUI
import UIKit
import AVFoundation
import Foundation
import Network

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

// MARK: - Yhteysvahti (offline-ilmoitusta varten)
final class Connectivity: ObservableObject {
    @Published var isOnline: Bool = true
    @Published var isCellular: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = (path.status == .satisfied)
                self?.isCellular = path.isExpensive // = todennäköisesti mobiiliverkko
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}


// MARK: - Värit
private extension Color {
    static let appMinusRed  = Color(red: 204/255, green: 0/255,   blue: 0/255)      // #cc0000
    static let appPlusGreen = Color(red: 106/255, green: 168/255, blue: 79/255)     // #6aa84f
}

// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Auto-repeat -nappi
struct AutoRepeatCircleButton: View {
    let title: String
    let bgColor: Color
    let size: CGFloat
    let onTap: () -> Void
    let onRepeat: () -> Void

    @State private var timer: Timer?
    private let interval: TimeInterval = 0.4
    private let longPressThreshold: TimeInterval = 0.8

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
                if !pressing {
                    stopTimer()
                }
            }) {
                onRepeat()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                startTimer()
            }
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
    // Shortcut settings
    @AppStorage("shortcutEnabled") private var shortcutEnabled = true
    @AppStorage("shortcutName") private var shortcutName = ""
    @AppStorage("shortcutSendJSON") private var shortcutSendJSON = true


    // Kuva & picker
    @State private var selectedImage: UIImage?
    @State private var showFoodSearch = false
    @State private var showLibrary = false

    // Prosessin tila
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    // Tulokset — StageMealResult
    @State private var stageResult: StageMealResult?
    @State private var rawDebug: String = ""

    // UI-säädettävät arvot
    @State private var carbsVal: Double?
    @State private var fatVal: Double?
    @State private var proteinVal: Double?

    // Lisävihje (UI)
    @State private var userHintText: String = ""

    // AI-päättely (vain DEBUG)
    #if DEBUG
    @State private var showReasoningSheet = false
    #endif

    // Shortcut alert
    @State private var showShortcutAlert = false
    @State private var shortcutAlertMessage = ""

    // Peruuta
    @State private var analysisTask: Task<Void, Never>? = nil

    // Offline
    @StateObject private var connectivity = Connectivity()
   
    /// Pyöristys 1 desimaaliin – sama logiikka kuin `formatted(_:)` käyttää
    private func round1(_ v: Double) -> Double { ((v * 10).rounded()) / 10 }

    /// Vertaa kahta arvoa 1 desimaalin tarkkuudella
    private func equal1dp(_ a: Double, _ b: Double) -> Bool { round1(a) == round1(b) }

    /// True, jos UI:n nykyiset arvot (carbs/fat/proteins) vastaavat AI:n tulosta 1 desimaalin tarkkuudella
    private var isAtAIDefaults: Bool {
        guard let s = stageResult else { return true } // ei tulosta → ei tarvetta napille
        let uiC = carbsVal   ?? s.analysis.totals.carbs_g
        let uiF = fatVal     ?? s.analysis.totals.fat_g
        let uiP = proteinVal ?? s.analysis.totals.protein_g
        return equal1dp(uiC, s.analysis.totals.carbs_g)
            && equal1dp(uiF, s.analysis.totals.fat_g)
            && equal1dp(uiP, s.analysis.totals.protein_g)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                ScrollView {
                    VStack(spacing: 16) {
                        imagePreview

                        TextField(
                            loc("Lisävihje (valinnainen)", en: "Optional hint (e.g., weights, sauces)"),
                            text: $userHintText
                        )
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

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

                        if let info = infoMessage, !info.isEmpty {
                            Text(info)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }

                        if let err = errorMessage, !err.isEmpty {
                            Text(err)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        if stageResult != nil {
                            resultsBox
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.vertical, 8)
                }

                bottomBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
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

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if shortcutEnabled {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            runShortcutWithOptionalJSON()
                        } label: {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                                .accessibilityLabel(loc("Suorita Shortcut", en: "Run Shortcut"))
                        }
                        .disabled(shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(PressableButtonStyle())
                    }

                }
            }
            .fullScreenCover(isPresented: $showFoodSearch) {
                FoodSearchView { image in
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
            #if DEBUG
            .sheet(isPresented: $showReasoningSheet) {
                reasoningSheetView()
                    .presentationDetents([.medium, .large])
            }
            #endif
            .alert(loc("Shortcut", en: "Shortcut"), isPresented: $showShortcutAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(shortcutAlertMessage)
            }
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

    // MARK: - Tuloslaatikko (sis. “Palauta AI-arvot”)
    private var resultsBox: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Otsikko: AI:n nimi jos on, muuten fallback
            Text(mealTitle())
                .font(.headline)

            // Arvorivit: “- XX g +”
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

            // Kopiointinapit
            HStack(spacing: 10) {
                copyButton(label: "Carbs", value: carbsVal ?? currentCarbsDefault())
                copyButton(label: "Fat", value: fatVal ?? currentFatDefault())
                copyButton(label: "Proteins", value: proteinVal ?? currentProteinDefault())
            }

            // Palauta AI-arvot
            Button {
                guard !isAtAIDefaults else { return } // hiljainen, jos jo samat
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.15)) {
                    syncUIValuesFromStage() // palauttaa UI-arvot mallin tulokseen
                }
            } label: {
                Text(loc("Palauta AI-arvot", en: "Reset to AI values"))
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isAtAIDefaults)              // estä painallus, jos ei muutettavaa
            .opacity(isAtAIDefaults ? 0.5 : 1.0)   // visuaalisesti “hiljaisempi”
            .buttonStyle(PressableButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .onChange(of: stageResult?.analysis.totals.carbs_g) { _, _ in
            syncUIValuesIfNeeded()
        }
    }


    // MARK: - Arvorivi
    private func adjustableRow(title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(width: 95, alignment: .leading)

            AutoRepeatCircleButton(
                title: "−1",
                bgColor: .appMinusRed,
                size: 32,
                onTap: { value.wrappedValue = max(0, value.wrappedValue - 1) },
                onRepeat: { value.wrappedValue = max(0, value.wrappedValue - 5) }
            )

            Text("\(formatted(value.wrappedValue)) g")
                .font(.title3.monospacedDigit())
                .frame(minWidth: 80, alignment: .center)

            AutoRepeatCircleButton(
                title: "+1",
                bgColor: .appPlusGreen,
                size: 32,
                onTap: { value.wrappedValue = value.wrappedValue + 1 },
                onRepeat: { value.wrappedValue = value.wrappedValue + 5 }
            )

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Kopio
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

    // MARK: - Alapalkki
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                startFoodSearch()
            } label: {
                VStack {
                    Image(systemName: "fork.knife")
                    Text(loc("Ruokahaku", en: "Food Search"))
                }
            }
            .buttonStyle(PressableButtonStyle())
            .frame(maxWidth: .infinity)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                if isRunning {
                    analysisTask?.cancel() // Peruuta käynnissä oleva analyysi
                    return
                }
                analysisTask = Task { await analyzeNow() }
            } label: {
                VStack {
                    Image(systemName: isRunning ? "xmark.circle" : "wand.and.stars")
                    Text(isRunning ? loc("Peruuta", en: "Cancel")
                                   : loc("Analysoi", en: "Analyze"))
                }
            }
            .disabled(selectedImage == nil)
            .frame(maxWidth: .infinity)
            .buttonStyle(PressableButtonStyle())

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

    // MARK: - Food Search
    private func startFoodSearch() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showLibrary = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.showFoodSearch = true }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.showFoodSearch = true }
                    else { self.showLibrary = true }
                }
            }
        default:
            self.showLibrary = true
        }
    }

    #if DEBUG
    // MARK: - AI-päättely (vain DEBUG)
    @ViewBuilder
    private func reasoningSheetView() -> some View {
        NavigationView {
            ScrollView {
                Text(rawReasoningText())
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(loc("AI-päättely", en: "AI reasoning"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func rawReasoningText() -> String {
        guard let s = stageResult else { return "" }
        let t = s.analysis.totals
        return """
        \(loc("Makrot (arvio):", en: "Macros (estimate):"))
        Carbs: \(formatted(t.carbs_g)) g
        Fat: \(formatted(t.fat_g)) g
        Proteins: \(formatted(t.protein_g)) g
        """
    }
    #endif

    /// Peruutuksen tunnistus
    private func isUserCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlErr = error as? URLError, urlErr.code == .cancelled { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return true }
        if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError { return true }
        if Task.isCancelled { return true }
        return false
    }

    // MARK: - Analyze
    private func analyzeNow() async {
        guard let img = selectedImage else { return }

        // Offline-check
        if connectivity.isOnline == false {
            infoMessage = loc("Ei internet-yhteyttä. Yritä uudelleen, kun yhteys on palautunut.",
                              en: "No internet connection. Try again when you’re back online.")
            errorMessage = nil
            return
        }

        // Valitse max-dimensio mobiiliverkon ja asetuksen perusteella
        let maxDim: CGFloat = connectivity.isCellular ? 1024 : 1280

        // Valmistele data taustalla
        let data: Data
        do {
            data = try await makeJPEGDataAsync(from: img, maxDimension: maxDim, quality: 0.8)
        } catch {
            errorMessage = "Virhe: \(error.localizedDescription)"
            return
        }

        // --- täällä jatkuu nykyinen analysointipolku (isRunning, defer, try/await jne.) ---
        withAnimation { isRunning = true }
        errorMessage = nil
        infoMessage  = nil

        defer {
            withAnimation { isRunning = false }
            analysisTask = nil
        }

        do {
            // KOHTA 4: pehmää aikakatkaisua hyödyntävä kutsu:
            let (stage, raw) = try await analyzeWithTimeout(data, timeout: 25)
            self.stageResult = stage
            self.rawDebug = raw
            syncUIValuesFromStage()
        } catch {
            if isUserCancellation(error) {
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

    /// Kilpa-ajaa analyysin ja pehmeän aikakatkaisun (esim. 25 s).
    private func analyzeWithTimeout(_ data: Data, timeout: TimeInterval = 25) async throws -> (StageMealResult, String) {
        try await withThrowingTaskGroup(of: (StageMealResult, String).self) { group in
            group.addTask {
                try await MealAnalyzer.shared.analyzeMeal(imageData: data)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw URLError(.timedOut)
            }
            do {
                let result = try await group.next()!
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                throw error
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

    // MARK: - Helpers
    private func formatted(_ v: Double) -> String {
        let v1 = (v * 10).rounded() / 10
        if v1.rounded() == v1 { return String(Int(v1)) }
        return String(format: "%.1f", v1)
    }

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

    private func loc(_ fi: String, en: String? = nil) -> String {
        if Locale.preferredLanguages.first?.hasPrefix("fi") == true { return fi }
        return en ?? fi
    }

    private func currentMacroInts() -> (carbs: Int, fat: Int, protein: Int)? {
        let c = Int((carbsVal ?? stageResult?.analysis.totals.carbs_g ?? 0).rounded())
        let f = Int((fatVal ?? stageResult?.analysis.totals.fat_g ?? 0).rounded())
        let p = Int((proteinVal ?? stageResult?.analysis.totals.protein_g ?? 0).rounded())
        if c == 0, f == 0, p == 0 { return nil }
        return (c, f, p)
    }
    // Otsikko tuloslaatikkoon: AI:n antama nimi jos on, muuten fallback-teksti.
    private func mealTitle() -> String {
        let name = stageResult?.mealName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty {
            return loc("Analyysin tulos", en: "Analysis Result")
        }
        return String(name.prefix(60))
    }

    // MARK: - Shortcuts (compact JSON)
    private func buildCompactShortcutJSON() -> String? {
        guard let ints = currentMacroInts() else { return nil }
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

    func runShortcutWithOptionalJSON() {
        let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)

        var jsonString: String? = nil
        if shortcutSendJSON {
            jsonString = buildCompactShortcutJSON()
            if jsonString == nil {
                shortcutAlertMessage = loc("Ei lähetettäviä arvoja. Tee analyysi ensin tai säädä arvoja.",
                                           en: "No values to send. Run an analysis first or adjust values.")
                showShortcutAlert = true
                return
            }
        }

        runShortcutWithOptionalJSON(shortcutName: name, json: jsonString)
    }

    func runShortcutWithOptionalJSON(shortcutName: String, json: String?) {
        let trimmed = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            shortcutAlertMessage = loc("Määritä Shortcuttin nimi asetuksissa.",
                                       en: "Define the Shortcut name in Settings.")
            showShortcutAlert = true
            return
        }

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

    // MARK: - x-callback
    private func handleCallbackURL(_ url: URL) {
        guard url.scheme == "mealai" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch url.host {
        case "done":
            shortcutAlertMessage = loc("Pikakuvake suoritettu ✅", en: "Shortcut finished ✅")
            showShortcutAlert = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "error":
            let reason = comps?.queryItems?.first(where: { $0.name == "error" || $0.name == "message" })?.value
            shortcutAlertMessage = reason ?? loc("Pikakuvake epäonnistui ❌", en: "Shortcut failed ❌")
            showShortcutAlert = true
        case "cancel":
            break
        default:
            break
        }
    }

    /// Käsittelee kuvan taustalla ja palauttaa JPEG-datan.
    /// Käyttää autoreleasepoolia muistipiikkien pienentämiseksi.
    private func makeJPEGDataAsync(from image: UIImage, maxDimension: CGFloat, quality: CGFloat = 0.8) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let downsized = image.downscaled(maxDimension: maxDimension)
            return try autoreleasepool {
                if let d = downsized.jpegData(compressionQuality: quality) { return d }
                throw NSError(domain: "ContentView", code: -20, userInfo: [NSLocalizedDescriptionKey: "JPEG encoding failed"])
            }
        }.value
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
