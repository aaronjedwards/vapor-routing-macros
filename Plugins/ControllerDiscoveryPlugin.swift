import Foundation
import PackagePlugin

enum ControllerDiscoveryPluginError: Error {
    case missingControllersDirectory
}

@main
struct ControllerDiscoveryPlugin: BuildToolPlugin {
    
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        let controllersDirectory = target.directory.appending(["Controllers"])
        let tempDirectory = context.pluginWorkDirectory.appending(["tmp"])
        let outputDirectory = context.pluginWorkDirectory.appending(["generated"])
        
        do {
            let inputPaths = try copyFiles(from: controllersDirectory, to: tempDirectory)
            let outputPaths = [
                outputDirectory.appending(["ControllerDiscovery.generated.swift"])
            ]
            
            return [
                .buildCommand(
                    displayName: "ControllerDiscoveryCLI",
                    executable: try context.tool(named: "ControllerDiscoveryCLI").path,
                    arguments: [
                        target.name,
                        tempDirectory,
                        outputDirectory,
                    ],
                    inputFiles: inputPaths,
                    outputFiles: outputPaths)
            ]
        } catch ControllerDiscoveryPluginError.missingControllersDirectory {
            return []
        }
    }
    
    func copyFiles(
        from controllersDirectory: Path,
        to tempDirectory: Path
    ) throws -> [Path] {
        /// Delete `tempDirectory` if it exists (from a previous run)
        if FileManager.default.fileExists(atPath: tempDirectory.string, isDirectory: nil) {
            try FileManager.default.removeItem(atPath: tempDirectory.string)
        }
        
        
        guard let enumerator = FileManager.default.enumerator(atPath: controllersDirectory.string) else {
            return []
        }
        
        try FileManager.default.copyItem(
            atPath: controllersDirectory.string,
            toPath: tempDirectory.string)
        
        var inputPaths: [Path] = []
        while let file = enumerator.nextObject() as? String {
            let swiftSuffix = ".swift"
            guard file.hasSuffix(swiftSuffix) else {
                continue
            }
            let inputPath = controllersDirectory.appending([file])
            inputPaths.append(inputPath)
        }
        return inputPaths
    }
}
