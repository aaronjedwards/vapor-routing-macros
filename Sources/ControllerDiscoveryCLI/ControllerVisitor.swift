import Foundation
import SwiftSyntax

final class ControllerVisitor: SyntaxVisitor {
    var identifiers: [String] = []
    
    override func visit(_ node: TypeInheritanceClauseSyntax) -> SyntaxVisitorContinueKind {
        guard
            node.isControllerDiscoverable,
            let parent = node.parent,
            let identifier = parent.classStructOrExtensionIdentifier
        else {
            return .skipChildren
        }
        identifiers.append(identifier)
        return .skipChildren
    }
}

extension Syntax {
    var classStructOrExtensionIdentifier: String? {
        let tokenSyntax: TokenSyntax
        if let asClass = self.as(ClassDeclSyntax.self) {
            tokenSyntax = asClass.identifier
        } else if let asStruct = self.as(StructDeclSyntax.self) {
            tokenSyntax = asStruct.identifier
        } else if let asExtension = self.as(ExtensionDeclSyntax.self), let token = asExtension.extendedType.as(SimpleTypeIdentifierSyntax.self)?.name {
            tokenSyntax = token
        } else {
            return nil
        }
        return tokenSyntax.text
    }
}

extension TypeInheritanceClauseSyntax {
  var isControllerDiscoverable: Bool {
    inheritedTypeCollection.contains { node in
      let typeNameText = SimpleTypeIdentifierSyntax(node.typeName)?.name.text
      return typeNameText == "ControllerDiscoverable"
    }
  }
}
