import ArgumentParser
import Foundation
import SwiftParser
import SwiftSyntax

enum ControllerDiscoveryError: Error {
    case failedToCreateFile(String)
    case missingInputDirectory
    case noControllersFound
}

@main
struct ControllerDiscoveryCLI: ParsableCommand {
    
    /// Entrypoint of the command
    mutating func run() throws {
        try generateControllerRegistrationFile()
    }
    
    /// The directory that contains controllers to be discovered
    @Argument(help: "The name of the target")
    var targetName: String
    
    /// The directory that contains controllers to be discovered
    @Argument(help: "The designated controllers directory")
    var inputDirectory: URL
    
    /// The output directory for the generated source file
    @Argument(help: "The directory in which to generate code")
    var outputDirectory: URL
    
    /// Generates an extension on Vapors `Application` that registers each of the "controllers"
    /// Controllers are considered any types that conform to the `ControllerProtocol` or that are decorated with the `@Controller`.
    private func generateControllerRegistrationFile() throws {
        
        do {
            let controllerFiles = try findPotentialControllerFiles()
            var registrations: [String] = []
            for fileUrl in controllerFiles {
                let source = try String(contentsOf: fileUrl, encoding: .utf8)
                let sourceFile = Parser.parse(source: source)
                
                let visitor = ControllerVisitor(viewMode: .sourceAccurate)
                visitor.walk(sourceFile)
                
                for identifier in visitor.identifiers.sorted() {
                    registrations.append("\(identifier)().boot(routes: self)")
                }
            }
            
            let contents = """
              import Vapor
              
              extension Application {
                func registerControllers() {
                  \(registrations.joined(separator: "\n\t"))
                }
              }
              """
            
            if !FileManager.default.fileExists(atPath: outputDirectory.path, isDirectory: nil) {
                try FileManager.default.createDirectory(
                    at: outputDirectory,
                    withIntermediateDirectories: true)
            }
            
            try FileManager.default.createFileThrows(
                atPath: outputDirectory.appendingPathComponent("ControllerDiscovery.generated.swift").path,
                contents: contents.data(using: .utf8))
        } catch ControllerDiscoveryError.missingInputDirectory {
            let contents = """
              import Vapor
              
              extension Application {
                func registerControllers() {
                    #warning(\"\"\"
                    No controllers will be registered because none were found during the controller discovery process.
                    Controllers should be added to the 'Controllers' directory at the root of your target ('\(targetName)').
                    \"\"\")
                }
              }
              """
            
            if !FileManager.default.fileExists(atPath: outputDirectory.path, isDirectory: nil) {
                try FileManager.default.createDirectory(
                    at: outputDirectory,
                    withIntermediateDirectories: true)
            }
            
            try FileManager.default.createFileThrows(
                atPath: outputDirectory.appendingPathComponent("ControllerDiscovery.generated.swift").path,
                contents: contents.data(using: .utf8))
        }
    }
    
    /// Gathers the URLs for all potential files containing a controller, which in this case could be all swift files
    private func findPotentialControllerFiles() throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(atPath: inputDirectory.path) else {
            throw ControllerDiscoveryError.missingInputDirectory
        }
        
        var controllerFiles: [URL] = []
        while let file = enumerator.nextObject() as? String {
            let swiftSuffix = ".swift"
            guard file.hasSuffix(swiftSuffix) else {
                continue
            }
            let fileURL = inputDirectory.appendingPathComponent(file)
            controllerFiles.append(fileURL)
        }
        
        return controllerFiles
    }
}

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(fileURLWithPath: argument, isDirectory: true)
    }
}
