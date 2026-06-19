//
//  ContentView.swift
//  ContextualEmbeddingAssetCheck
//
//  Created by 酒井雄太 on 2026/05/03.
//

import Combine
import Foundation
import NaturalLanguage
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var runner = EmbeddingAssetCheckRunner()
    @State private var selectedLanguage = EmbeddingLanguageOption.japanese
    @State private var timeoutSeconds = 180.0
    @State private var copiedLog = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                statusPanel
                languagePicker

                HStack(spacing: 12) {
                    Button {
                        runner.start(languageOption: selectedLanguage, timeoutSeconds: timeoutSeconds)
                    } label: {
                        Label("Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(runner.isRunning)

                    Button {
                        runner.cancel()
                    } label: {
                        Label("Cancel", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!runner.isRunning)
                }

                timeoutControl

                Divider()

                HStack {
                    Text("Log")
                        .font(.headline)

                    Spacer()

                    Button {
                        Clipboard.copy(runner.logText)
                        copiedLog = true

                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            copiedLog = false
                        }
                    } label: {
                        Label(copiedLog ? "Copied" : "Copy All", systemImage: copiedLog ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(runner.entries.isEmpty)
                    .help("Copy the full log")
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(runner.entries) { entry in
                                Text(entry.text)
                                    .font(.system(.footnote, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(entry.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: runner.entries.count) { _, _ in
                        guard let lastID = runner.entries.last?.id else { return }
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                    .onChange(of: runner.entries.count) { _, _ in
                        copiedLog = false
                    }
                }
            }
            .padding()
            .navigationTitle("NLContextualEmbedding")
        }
    }

    private var statusPanel: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("Language")
                    .foregroundStyle(.secondary)
                Text(selectedLanguage.displayName)
            }
            GridRow {
                Text("State")
                    .foregroundStyle(.secondary)
                Text(runner.stateText)
            }
            GridRow {
                Text("Elapsed")
                    .foregroundStyle(.secondary)
                Text(runner.elapsedText)
                    .monospacedDigit()
            }
            GridRow {
                Text("Assets")
                    .foregroundStyle(.secondary)
                Text(runner.assetsText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var languagePicker: some View {
        Picker("Language", selection: $selectedLanguage) {
            ForEach(EmbeddingLanguageOption.allCases) { option in
                Text(option.displayName)
                    .tag(option)
            }
        }
        .pickerStyle(.menu)
        .disabled(runner.isRunning)
    }

    private var timeoutControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Timeout marker")
                Spacer()
                Text("\(Int(timeoutSeconds)) sec")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $timeoutSeconds, in: 30...600, step: 30)
                .disabled(runner.isRunning)
        }
    }
}

enum EmbeddingLanguageOption: String, CaseIterable, Identifiable {
    case japanese
    case english
    case simplifiedChinese
    case traditionalChinese
    case korean
    case french
    case german
    case spanish

    var id: Self { self }

    var displayName: String {
        switch self {
        case .japanese:
            return "Japanese"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .traditionalChinese:
            return "Traditional Chinese"
        case .korean:
            return "Korean"
        case .french:
            return "French"
        case .german:
            return "German"
        case .spanish:
            return "Spanish"
        }
    }

    var nlLanguage: NLLanguage {
        switch self {
        case .japanese:
            return .japanese
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .traditionalChinese:
            return .traditionalChinese
        case .korean:
            return .korean
        case .french:
            return .french
        case .german:
            return .german
        case .spanish:
            return .spanish
        }
    }

    var sampleText: String {
        switch self {
        case .japanese:
            return "今日は良い天気です。"
        case .english:
            return "The weather is nice today."
        case .simplifiedChinese:
            return "今天天气很好。"
        case .traditionalChinese:
            return "今天天氣很好。"
        case .korean:
            return "오늘 날씨가 좋습니다."
        case .french:
            return "Il fait beau aujourd'hui."
        case .german:
            return "Heute ist das Wetter schoen."
        case .spanish:
            return "Hoy hace buen tiempo."
        }
    }
}

@MainActor
final class EmbeddingAssetCheckRunner: ObservableObject {
    struct LogEntry: Identifiable {
        let id = UUID()
        let text: String
    }

    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var isRunning = false
    @Published private(set) var stateText = "Idle"
    @Published private(set) var elapsedText = "0.0 sec"
    @Published private(set) var assetsText = "Not checked"

    var logText: String {
        entries.map(\.text).joined(separator: "\n")
    }

    private var requestTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var startedAt: Date?
    private var requestFinished = false

    func start(languageOption: EmbeddingLanguageOption, timeoutSeconds: TimeInterval) {
        cancel()

        entries.removeAll()
        isRunning = true
        requestFinished = false
        startedAt = Date()
        stateText = "Starting"
        elapsedText = "0.0 sec"
        assetsText = "Not checked"

        log("Device: \(PlatformInfo.deviceModel)")
        log("System: \(PlatformInfo.systemName) \(PlatformInfo.systemVersion)")
        log("Language: \(languageOption.displayName) (\(languageOption.nlLanguage.rawValue))")

        guard let embedding = NLContextualEmbedding(language: languageOption.nlLanguage) else {
            stateText = "Embedding unavailable"
            isRunning = false
            log("NLContextualEmbedding(language: \(languageOption.nlLanguage.rawValue)) returned nil")
            return
        }

        let initialAssets = embedding.hasAvailableAssets
        assetsText = String(initialAssets)
        log("hasAvailableAssets before: \(initialAssets)")

        do {
            try embedding.load()
            stateText = "Loaded without requestAssets"
            isRunning = false
            requestFinished = true
            log("load() without requestAssets succeeded")
            runSmokeTest(embedding: embedding, languageOption: languageOption)
            return
        } catch {
            log("load() without requestAssets failed: \(describe(error))")
        }

        stateText = "requestAssets running"
        log("requestAssets() started")

        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }

        watchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            self?.markTimeoutIfStillRunning(timeoutSeconds: timeoutSeconds)
        }

        requestTask = Task { [weak self] in
            do {
                let result = try await embedding.requestAssets()
                self?.finishRequestAssets(resultDescription: String(describing: result), embedding: embedding, languageOption: languageOption)
            } catch {
                self?.finishWithError(error)
            }
        }
    }

    func cancel() {
        requestTask?.cancel()
        watchdogTask?.cancel()
        tickerTask?.cancel()
        requestTask = nil
        watchdogTask = nil
        tickerTask = nil

        if isRunning {
            isRunning = false
            stateText = "Cancelled"
            log("Cancelled by user")
        }
    }

    private func finishRequestAssets(resultDescription: String, embedding: NLContextualEmbedding, languageOption: EmbeddingLanguageOption) {
        guard isRunning else {
            log("requestAssets() returned after cancellation: \(resultDescription)")
            return
        }

        requestFinished = true
        watchdogTask?.cancel()
        tickerTask?.cancel()
        tick()

        log("requestAssets result: \(resultDescription)")
        let finalAssets = embedding.hasAvailableAssets
        assetsText = String(finalAssets)
        log("hasAvailableAssets after: \(finalAssets)")

        do {
            try embedding.load()
            stateText = "Load succeeded"
            log("load() after requestAssets succeeded")
            runSmokeTest(embedding: embedding, languageOption: languageOption)
        } catch {
            stateText = "Load failed"
            log("load() after requestAssets failed: \(describe(error))")
        }

        isRunning = false
        requestTask = nil
    }

    private func finishWithError(_ error: Error) {
        guard isRunning else {
            log("requestAssets() threw after cancellation: \(describe(error))")
            return
        }

        requestFinished = true
        watchdogTask?.cancel()
        tickerTask?.cancel()
        tick()

        stateText = "requestAssets failed"
        log("requestAssets() threw: \(describe(error))")
        isRunning = false
        requestTask = nil
    }

    private func markTimeoutIfStillRunning(timeoutSeconds: TimeInterval) {
        guard isRunning, !requestFinished else { return }
        stateText = "Still running after timeout marker"
        log("requestAssets() has not returned after \(Int(timeoutSeconds)) seconds")
    }

    private func runSmokeTest(embedding: NLContextualEmbedding, languageOption: EmbeddingLanguageOption) {
        let sampleText = languageOption.sampleText
        log("smoke test input: \(sampleText)")
        log("modelIdentifier: \(embedding.modelIdentifier)")
        log("model dimension: \(embedding.dimension)")
        log("maximumSequenceLength: \(embedding.maximumSequenceLength)")

        do {
            let result = try embedding.embeddingResult(for: sampleText, language: languageOption.nlLanguage)
            log("embeddingResult language: \(result.language.rawValue)")
            log("embeddingResult sequenceLength: \(result.sequenceLength)")

            var tokenCount = 0
            result.enumerateTokenVectors(in: sampleText.startIndex..<sampleText.endIndex) { vector, range in
                tokenCount += 1

                if tokenCount <= 3 {
                    let tokenText = String(sampleText[range])
                    let previewValues = vector.prefix(4).map { String(format: "%.4f", $0) }.joined(separator: ", ")
                    log("token \(tokenCount): \"\(tokenText)\" range=\(rangeDescription(range, in: sampleText)) vectorCount=\(vector.count) firstValues=[\(previewValues)]")
                }

                return true
            }

            log("enumerated token vectors: \(tokenCount)")
        } catch {
            log("embeddingResult smoke test failed: \(describe(error))")
        }
    }

    private func rangeDescription(_ range: Range<String.Index>, in text: String) -> String {
        let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
        let upperBound = text.distance(from: text.startIndex, to: range.upperBound)
        return "\(lowerBound)..<\(upperBound)"
    }

    private func tick() {
        guard let startedAt else { return }
        elapsedText = String(format: "%.1f sec", Date().timeIntervalSince(startedAt))
    }

    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let line = "[\(formatter.string(from: Date()))] \(message)"
        entries.append(LogEntry(text: line))
        print(line)
    }

    private func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
    }
}

private enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

private enum PlatformInfo {
    static var deviceModel: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.model
        #endif
    }

    static var systemName: String {
        #if os(macOS)
        return "macOS"
        #else
        return UIDevice.current.systemName
        #endif
    }

    static var systemVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
}

#Preview {
    ContentView()
}
