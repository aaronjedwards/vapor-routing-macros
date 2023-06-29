import SwiftSyntax
import SwiftSyntaxMacros

struct HandlerParam {
    let name: String
    let argName: String
    let attribute: String?
    let type: String
    let valid: Bool
    let index: Int
}

func getHandlerParameters(decl: FunctionDeclSyntax) -> [HandlerParam]  {
    let parameterList = decl.signature.input.parameterList
    var handlerParams: [HandlerParam] = []
    
    let attributeNames = ["PathParam", "QueryParam", "QueryContent", "BodyContent"]

    for (index, param) in parameterList.enumerated(){
        let attr = param.attributes?.first (where: {
            guard case let .attribute(attribute) = $0,
                  let attributeType = attribute.attributeName.as(SimpleTypeIdentifierSyntax.self)
            else {
                return false
            }
            return attributeNames.contains(attributeType.name.text)
        })
        
        if case let .attribute(attribute) = attr,
           let attributeType = attribute.attributeName.as(SimpleTypeIdentifierSyntax.self) {
            
            var name = param.firstName.text
            if attributeType.name.text == "PathParam", let nameArg = attribute.argument?.as(TupleExprElementListSyntax.self)?.first {
                if let stringLiteralValue = nameArg.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                    name = stringLiteralValue
                }
            } else if attributeType.name.text == "QueryParam", let nameArg = attribute.argument?.as(TupleExprElementListSyntax.self)?.first {
                if let stringLiteralValue = nameArg.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                    name = stringLiteralValue
                }
            }
            
            handlerParams.append(.init(name: name, argName: param.firstName.text, attribute: attributeType.name.text, type: param.type.description, valid: true, index: index))
        } else {
            handlerParams.append(.init(name: param.firstName.text, argName: param.firstName.text, attribute: nil, type: param.type.description, valid: param.type.description == "Request" ? true : false, index: index))
        }
    }
    
    return handlerParams
}

func getMethodAndPath(_ attributes: AttributeListSyntax) throws -> (String, String?, String?)? {
    let macroNames = ["Get", "Post", "Put", "Delete", "Patch", "Handler"]
    let attr = attributes.first (where: {
        guard case let .attribute(attribute) = $0,
              let attributeType = attribute.attributeName.as(SimpleTypeIdentifierSyntax.self)
        else {
            return false
        }
        return macroNames.contains(attributeType.name.text)
    })
    
    guard
        case let .attribute(attribute) = attr,
        let attributeType = attribute.attributeName.as(SimpleTypeIdentifierSyntax.self)
    else {
        return nil
    }
    
    let macroName = attributeType.name.text
    
    let method: String
    let path: String?
    let streamingStrategy: String?
    switch macroName {
    case "Handler":
        guard let methodArgValue = attribute.argument?.as(TupleExprElementListSyntax.self)?.first?.expression.description else {
            return nil
        }
        method = methodArgValue
        let pathArg = attribute.argument?.as(TupleExprElementListSyntax.self)?.first(where: { $0.label?.text == "path" })
        path = pathArg?.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text
        let streamingStrategyArg = attribute.argument?.as(TupleExprElementListSyntax.self)?.first(where: { $0.label?.text == "body" })
        streamingStrategy = streamingStrategyArg?.expression.description
    default:
        method = ".\(macroName.uppercased())"
        path = attribute.argument?.as(TupleExprElementListSyntax.self)?.first?.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text
        let streamingStrategyArg = attribute.argument?.as(TupleExprElementListSyntax.self)?.first(where: { $0.label?.text == "body" })
        streamingStrategy = streamingStrategyArg?.expression.description
    }
    
    return (method, path, streamingStrategy)
}

func validateHandler<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
>(
    of node: AttributeSyntax,
    providingPeersOf declaration: Declaration,
    in context: Context
) throws -> [DeclSyntax] {
    let attributeName = node.attributeName.as(SimpleTypeIdentifierSyntax.self)!.name.text
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
        throw CustomError.message("@\(attributeName) only works on functions")
    }
    
    let handlerParams = getHandlerParameters(decl: funcDecl)
    let otherParams = handlerParams.filter { $0.valid == false }
    
    guard otherParams.count == 0 else {
        throw CustomError.message("@\(attributeName) must be attached to a handler containing only parameters of type 'Request' or parameters decorated with '@PathParam', '@QueryParam', '@QueryContent' or '@BodyContent' attributes")
    }
    
//    if let attributes = funcDecl.attributes, let (_, path, _) = try getMethodAndPath(attributes){
//        let pathArgs = path?.split(separator: "/").filter { $0.starts(with: ":")}.map { String($0.dropFirst()) } ?? []
//        let pathParams = handlerParams.filter { $0.attribute == "PathParam" && $0.valid }
//        for param in pathParams {
//            let paramName = param.name
//            guard pathArgs.contains(paramName) else {
//                throw CustomError.message("""
//                @\(attributeName) was attached to a handler with a @PathParam named \"\(paramName)\", but no corresponding parameter with that name was specified in the path.
//                
//                Either remove the \"\(paramName)\" parameter from the handler, or add a it to the path.
//                """)
//            }
//        }
//    }
    
    return []
}
