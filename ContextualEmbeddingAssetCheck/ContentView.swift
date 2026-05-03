//
//  ContentView.swift
//  ContextualEmbeddingAssetCheck
//
//  Created by 酒井雄太 on 2026/05/03.
//

import Combine
import NaturalLanguage
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var runner = EmbeddingAssetCheckRunner()
    @State private var selectedLanguage = EmbeddingLanguageOption.japanese
    @State private var timeoutSeconds = 180.0

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

                Text("Log")
                    .font(.headline)

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

        log("Device: \(UIDevice.current.model)")
        log("System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
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
                self?.finishRequestAssets(resultDescription: String(describing: result), embedding: embedding)
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

    private func finishRequestAssets(resultDescription: String, embedding: NLContextualEmbedding) {
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

#Preview {
    ContentView()
}
