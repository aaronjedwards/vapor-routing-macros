import XCTest
import VaporRoutingMacrosMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

final class VaporRoutingMacrosTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Controller": ControllerMacro.self,
        "Get": HandlerMacro.self,
        "Post": HandlerMacro.self,
    ]
    
    func testMacrosWithQueryParams() {
        assertMacroExpansion(
            """
            @Controller("hello")
            final class HelloController {
                @Get
                func hello(req: Request, @QueryParam("name") provided: String?) -> String {
                    return "Hi, there!"
                }
            }
            """,
            expandedSource: """
            
            final class HelloController {
                func hello(req: Request, @QueryParam("name") provided: String?) -> String {
                    return "Hi, there!"
                }
                public func boot(routes: RoutesBuilder) {
                    let controllerPath = "hello"
                    let controller = routes.grouped(controllerPath.pathComponents)
                    controller.on(.GET, use: { req async throws in
                            let nameParam: String? = req.query["name"]
                            return self.hello(req: req, provided: nameParam)
                        })
                }
            }
            extension HelloController: RouteCollection {
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacrosWithPathParam() {
        assertMacroExpansion(
            """
            @Controller("hello")
            final class HelloController {
                @Get(path: "there")
                func hello(req: Request, @PathParam name: String) -> String {
                    return "Hi, there!"
                }
            }
            """,
            expandedSource: """
            
            final class HelloController {
                func hello(req: Request, @PathParam name: String) -> String {
                    return "Hi, there!"
                }
                public func boot(routes: RoutesBuilder) {
                    let controllerPath = "hello"
                    let controller = routes.grouped(controllerPath.pathComponents)
                    let handler0Path = "there"
                    controller.on(.GET, handler0Path.pathComponents, use: { req async throws in
                            guard let nameParam = req.parameters.get("name", as: String.self) else {
                                throw Abort(.badRequest)
                            }
                            return self.hello(req: req, name: nameParam)
                        })
                }
            }
            extension HelloController: RouteCollection {
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacrosWithQueryContent() {
        assertMacroExpansion(
            """
            @Controller("hello")
            final class HelloController {
                
                struct Hello {
                    let name: String
                }
            
                @Get
                func hello(req: Request, @QueryContent hello: Hello) -> String {
                    return "Hi, there!"
                }
            }
            """,
            expandedSource: """
            
            final class HelloController {
            
                struct Hello {
                    let name: String
                }
                func hello(req: Request, @QueryContent hello: Hello) -> String {
                    return "Hi, there!"
                }
                public func boot(routes: RoutesBuilder) {
                    let controllerPath = "hello"
                    let controller = routes.grouped(controllerPath.pathComponents)
                    controller.on(.GET, use: { req async throws in
                            guard let helloParam = try? req.query.decode(Hello.self) else {
                                throw Abort(.badRequest)
                            }
                            return self.hello(req: req, hello: helloParam)
                        })
                }
            }
            extension HelloController: RouteCollection {
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacrosWithBodyContent() {
        assertMacroExpansion(
            """
            @Controller("hello")
            final class HelloController {
                
                struct Hello {
                    let name: String
                }
            
                @Post
                func hello(req: Request, @BodyContent hello: Hello) -> String {
                    return "Hi, there!"
                }
            }
            """,
            expandedSource: """
            
            final class HelloController {
            
                struct Hello {
                    let name: String
                }
                func hello(req: Request, @BodyContent hello: Hello) -> String {
                    return "Hi, there!"
                }
                public func boot(routes: RoutesBuilder) {
                    let controllerPath = "hello"
                    let controller = routes.grouped(controllerPath.pathComponents)
                    controller.on(.POST, use: { req async throws in
                            guard let helloParam = try? req.content.decode(Hello.self) else {
                                throw Abort(.badRequest)
                            }
                            return self.hello(req: req, hello: helloParam)
                        })
                }
            }
            extension HelloController: RouteCollection {
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacrosWithStreamingStrategy() {
        assertMacroExpansion(
            """
            @Controller("hello")
            final class HelloController {
                @Post(path: "there", body: .collect)
                func hello(req: Request) -> String {
                    return "Hi, there!"
                }
            }
            """,
            expandedSource: """
            
            final class HelloController {
                func hello(req: Request) -> String {
                    return "Hi, there!"
                }
                public func boot(routes: RoutesBuilder) {
                    let controllerPath = "hello"
                    let controller = routes.grouped(controllerPath.pathComponents)
                    let handler0Path = "there"
                    controller.on(.POST, handler0Path.pathComponents, body: .collect, use: { req async throws in
                            return self.hello(req: req)
                        })
                }
            }
            extension HelloController: RouteCollection {
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacrosWithMiddleware() {
        assertMacroExpansion(
            """
            @Controller("hello", middleware: AddVersionHeaderMiddleware())
            final class HelloController {
                @Get
                func hello() -> String {
                    return "Hi, there!"
                }
            }
            """,
            expandedSource: """
            
            final class HelloController {
                func hello() -> String {
                    return "Hi, there!"
                }
                public func boot(routes: RoutesBuilder) {
                    let controllerPath = "hello"
                    let routesWithMiddleware = routes.grouped(AddVersionHeaderMiddleware())
                    let controller = routesWithMiddleware.grouped(controllerPath.pathComponents)
                    controller.on(.GET, use: { req async throws in
                            return self.hello()
                        })
                }
            }
            extension HelloController: RouteCollection {
            }
            """,
            macros: testMacros
        )
    }
}
