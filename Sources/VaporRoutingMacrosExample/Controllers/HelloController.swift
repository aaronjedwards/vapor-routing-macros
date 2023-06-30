import Vapor
import VaporRoutingMacros

// Example Middleware from Vapor Docs
struct AddVersionHeaderMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        next.respond(to: request).map { response in
            response.headers.add(name: "My-App-Version", value: "v2.5.9")
            return response
        }
    }
}

@Controller("hello", middleware: AddVersionHeaderMiddleware())
final public class HelloController: ControllerDiscoverable {
    
    public init() {}
    
    struct Hello: Content {
        let name: String?
    }
    
    @Get
    func hello(@QueryParam("name") provided: String?) -> String {
        sayHello(to: provided)
    }
    
    @Get(path: ":name")
    func hello(@PathParam name: String) async throws -> String {
        sayHello(to: name)
    }
    
    @Post
    func hello(@BodyContent hello: Hello, req: Request) throws -> String {
        sayHello(to: hello.name)
    }
    
    func sayHello(to name: String?) -> String {
        "Hello, \(name ?? "Anonymous")!"
    }
}