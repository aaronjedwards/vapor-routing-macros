import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct VaporRoutingMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ControllerMacro.self,
        HandlerMacro.self
    ]
}
