import SwiftSyntax
import SwiftSyntaxMacros

public struct ControllerMacro: MemberMacro {
    public static var formatMode: FormatMode = .disabled
    
    public static func expansion<D, C>(
        of node: AttributeSyntax,
        providingMembersOf decl: D,
        in context: C
    ) throws -> [SwiftSyntax.DeclSyntax]
    where D: DeclGroupSyntax, C: MacroExpansionContext {
        
        guard
            let classDeclaration = decl.as(ClassDeclSyntax.self),
            classDeclaration.modifiers?.first(where: { $0.name.text == "final" }) != nil
        else {
            throw CustomError.message("@Controller only works with classes including the 'final' modifier")
        }
        
        guard let arguments = node.argument?.as(TupleExprElementListSyntax.self),
              let pathArgValue = arguments.first?.expression.description,
              pathArgValue != "\"\""
        else {
            throw CustomError.message("@Controller requires that the provided path be non-empty")
        }
        
        var middlewareArg: String? = nil
        if let arguments = node.argument?.as(TupleExprElementListSyntax.self),
           let middlewareArgValue = arguments.first(where: { $0.label?.description == "middleware" })?.expression.description {
            middlewareArg = middlewareArgValue
        }
        
        let handlers = try classDeclaration.memberBlock.members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
            .enumerated()
            .map { index, fun in try expansion(of: fun, with: pathArgValue, in: context, at: index) }
            .compactMap { $0 }
        
        let functionDecl = try FunctionDeclSyntax("public func boot(routes: RoutesBuilder)") {
            DeclSyntax("let controllerPath = \(raw: pathArgValue)")
            if let middlewareArg = middlewareArg {
                DeclSyntax("let routesWithMiddleware = routes.grouped(\(raw: middlewareArg))")
                DeclSyntax("let controller = routesWithMiddleware.grouped(controllerPath.pathComponents)")
            } else {
                DeclSyntax("let controller = routes.grouped(controllerPath.pathComponents)")
            }
            for (index, handler) in handlers.enumerated() {
                if let path = handler.path {
                    DeclSyntax("let handler\(raw: index)Path = \(raw: StringLiteralExprSyntax(content: path).description)")
                }
                handler.fun
            }
        }
        
        return [functionDecl.formatted().as(DeclSyntax.self)].compactMap { $0 }
    }
    
    private static func expansion(
        of declaration: FunctionDeclSyntax,
        with controllerPath: String?,
        in context: some MacroExpansionContext,
        at index: Int
    ) throws -> (path: String?, fun: FunctionCallExprSyntax)? {
        guard
            let attributes = declaration.attributes,
            let (method, path, streamingStrategy) = try getMethodAndPath(attributes)
        else {
            return nil
        }
        
        let closureSignature = ClosureSignatureSyntax(
            leadingTrivia: .space,
            input: .simpleInput(
                ClosureParamListSyntax {
                    ClosureParamSyntax(name: .identifier("req"))
                }
            )
            ,
            effectSpecifiers: TypeEffectSpecifiersSyntax(asyncSpecifier: .keyword(.async), throwsSpecifier: .keyword(.throws))
        )
        
        let handlerParams = getHandlerParameters(decl: declaration)
        let validHandlerParams = handlerParams.filter { $0.valid }
        let validHandlerParamsWithoutRequest = validHandlerParams.filter { $0.type != "Request" }
        let guardStatments = validHandlerParamsWithoutRequest
                            .filter { $0.attribute != "QueryParam" }
                            .map { expandHandlerParam(param: $0)}
                            .compactMap { $0 }
        let queryParamStatements = validHandlerParamsWithoutRequest
                                .filter { $0.attribute == "QueryParam" }
                                .map { DeclSyntax("let \(raw: $0.name)Param: \(raw: $0.type) = req.query[\"\(raw: $0.name)\"]")
}
        
        let argumentList = validHandlerParams
            .map { $0.type == "Request" ? "\($0.argName): req" : "\($0.argName): \($0.name)Param" }
            .joined(separator: ",")
        
        let expr = "self.\(raw: declaration.identifier.text)(\(raw: argumentList))" as ExprSyntax
        var finalExpr = expr
        if declaration.signature.effectSpecifiers?.asyncSpecifier != nil, declaration.signature.effectSpecifiers?.throwsSpecifier != nil {
            if let tryAwaitExpr = TryExprSyntax(expression: AwaitExprSyntax(expression: expr)).as(ExprSyntax.self) {
                finalExpr = tryAwaitExpr
            }
        } else if declaration.signature.effectSpecifiers?.asyncSpecifier != nil, declaration.signature.effectSpecifiers?.throwsSpecifier == nil {
            if let awaitExpr = AwaitExprSyntax(expression: expr).as(ExprSyntax.self) {
                finalExpr = awaitExpr
            }
        } else if declaration.signature.effectSpecifiers?.asyncSpecifier == nil, declaration.signature.effectSpecifiers?.throwsSpecifier != nil {
            if let tryExpr = TryExprSyntax(expression: expr).as(ExprSyntax.self) {
                finalExpr = tryExpr
            }
        }
        
        let functionCall = FunctionCallExprSyntax(
            calledExpression: ExprSyntax("controller.on"),
            leftParen: .leftParenToken(),
            argumentList: TupleExprElementListSyntax {
                TupleExprElementSyntax(expression: "\(raw: method)" as ExprSyntax)
                if path != nil {
                    TupleExprElementSyntax(expression: "handler\(raw: index)Path.pathComponents" as ExprSyntax)
                }
                if let strategy = streamingStrategy {
                    TupleExprElementSyntax(label: "body", expression: "\(raw: strategy)" as ExprSyntax)
                }
                TupleExprElementSyntax(label: "use", expression: ClosureExprSyntax(signature: closureSignature) {
                    for stmt in guardStatments {
                        stmt
                    }
                    for stmt in queryParamStatements {
                        stmt
                    }
                    ReturnStmtSyntax(expression: finalExpr)
                })
            },
            rightParen: .rightParenToken()
        )
        
        return (path, functionCall)
    }
    
    private static func expandHandlerParam(param: HandlerParam) -> GuardStmtSyntax? {
        let expression: ExprSyntax
        switch param.attribute {
        case "PathParam":
            expression = "req.parameters.get(\"\(raw: param.name)\", as: \(raw: param.type).self)" as ExprSyntax
        case "QueryContent":
            expression = "try? req.query.decode(\(raw: param.type).self)" as ExprSyntax
        case "BodyContent":
            expression = "try? req.content.decode(\(raw: param.type).self)" as ExprSyntax
        default:
            return nil
        }
        return expandParameterGuardStatement(param: param, expression: expression)
    }
    
    private static func expandParameterGuardStatement(param: HandlerParam, expression: ExprSyntax) -> GuardStmtSyntax? {
        GuardStmtSyntax(conditions: ConditionElementListSyntax {
            ConditionElementSyntax(
                condition: .optionalBinding(
                    OptionalBindingConditionSyntax(
                        bindingKeyword: .keyword(.let),
                        pattern: PatternSyntax(stringLiteral: param.name + "Param"),
                        initializer: InitializerClauseSyntax(value: expression)
                    )
                )
            )
        }, body: CodeBlockSyntax {
            ThrowStmtSyntax(expression: "Abort(.badRequest)" as ExprSyntax)
        })
    }
}

extension ControllerMacro: ConformanceMacro {
    public static func expansion<Declaration, Context>(
        of node: AttributeSyntax,
        providingConformancesOf declaration: Declaration,
        in context: Context
    ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
        return [ ("RouteCollection", nil) ]
    }
}
