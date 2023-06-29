import SwiftSyntax
import SwiftSyntaxMacros

public struct HandlerMacro: PeerMacro {
    public static var formatMode: FormatMode = .disabled
    public static func expansion<
        Context: MacroExpansionContext,
        Declaration: DeclSyntaxProtocol
    >(
        of node: AttributeSyntax,
        providingPeersOf declaration: Declaration,
        in context: Context
    ) throws -> [DeclSyntax] {
        return try validateHandler(of: node, providingPeersOf: declaration, in: context)
    }
}
