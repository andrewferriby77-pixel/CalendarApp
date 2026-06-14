//
//  EventImageScanner.swift
//  TempoCal
//

import Foundation
import Vision

/// Runs on-device OCR (Vision) over a picked image so a flyer, invite, or screenshot
/// can be turned into event text and fed into the natural-language parser.
nonisolated enum EventImageScanner {
    enum ScanError: LocalizedError {
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .noTextFound: return "No readable text found in that image."
            }
        }
    }

    /// Recognizes text in the given image data and returns the detected lines joined by newlines.
    /// Runs off the main actor; safe to call from a background `Task`.
    static func recognizeText(in imageData: Data) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(data: imageData, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { throw ScanError.noTextFound }
        return lines.joined(separator: "\n")
    }
}
