//
//  FastVLM.swift
//  FastVLM
//
//  Created by Peyton Randolph on 3/17/26.
//

import Foundation
import MLXVLM

public enum FastVLM {
    public static func resolveModelDirectory(searching bundles: [Bundle]? = nil) -> URL? {
        let searchBundles = bundles ?? [Bundle.module, .main]
        return resolveModelDirectory(searchRoots: searchBundles.compactMap(\.resourceURL))
    }

    public static func resolveModelDirectory(searchRoots: [URL]) -> URL? {
        let fileManager = FileManager.default
        let candidates = searchRoots.flatMap(Self.configurationFileCandidates(in:))

        guard let configurationURL = candidates.first(where: { candidate in
            fileManager.fileExists(atPath: candidate.path)
        }) else {
            return nil
        }

        return configurationURL.resolvingSymlinksInPath().deletingLastPathComponent()
    }

    public static func register(modelFactory: VLMModelFactory) {
        _ = modelFactory
    }

    private static func configurationFileCandidates(in root: URL) -> [URL] {
        [
            root.appendingPathComponent("FastVLM/model/config.json"),
            root.appendingPathComponent("model/config.json"),
            root.appendingPathComponent("config.json"),
        ]
    }
}
