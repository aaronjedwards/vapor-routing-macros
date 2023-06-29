import Foundation
import SwiftSyntax

final class ControllerVisitor: SyntaxVisitor {
    var identifiers: [String] = []
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        guard
            node.isController
        else {
            return .skipChildren
        }
        identifiers.append(node.identifier.text)
        return .skipChildren
    }
    
    override func visit(_ node: TypeInheritanceClauseSyntax) -> SyntaxVisitorContinueKind {
        guard
            node.isController,
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

extension ClassDeclSyntax {
    var isController: Bool {
        let controllerAttribute = attributes?.first(where: { attribute in
            guard
                case let .attribute(attr) = attribute,
                let attributeType = attr.attributeName.as(SimpleTypeIdentifierSyntax.self)
            else {
                return false
            }
            let typeNameText = attributeType.name.text
            return typeNameText == "Controller"
        })
        return controllerAttribute != nil
    }
}

extension TypeInheritanceClauseSyntax {
  var isController: Bool {
    inheritedTypeCollection.contains { node in
      let typeNameText = SimpleTypeIdentifierSyntax(node.typeName)?.name.text
      return typeNameText == "ControllerProtocol"
    }
  }
}
