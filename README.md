# VaporRoutingMacros

A collection of macros and utilities that offers a different approach for defining route handlers with Vapor. 

This package is a proof-of-concept and utilizes a beta version of Swift 5.9. At this point, it serves as inspiration for using macros to offer a new way of defining route handlers in Vapor. This approach could likewise be applied to other Swift web frameworks. Below are defined the set of features exposed by this package and how to use them.

[Concept](#concept) • [Installation](#installation) • [Macros](#macros) • [Controller Discovery Plugin](#controller-discovery-plugin) • [License](#license)

## Concept

Vapor (as well as other web frameworks) promotes utilizing "controllers" for grouping application logic. These controllers are typically types that define functions that act as request handlers. To assist with registering these route handlers, Vapor exposes the `RouteCollection` protocol, which has one function requirement that registers route handlers to a given `RoutesBuilder`.

Building on this idea, the macros exposed by this package implement the `boot(routes:)` requirement of `RouteCollection` and generate the boilerplate to transform functions decorated with various macros (`@Get`, `@Post`, etc.) into valid route handlers that are in turn registered to the provided `RoutesBuilder`.

Combined with a set of property wrappers, these macros allow you to easily create route handlers from basic functions with specialized arguments. Here is an example of using the utilities in this package to recreate the [basic hello example](https://docs.vapor.codes/basics/routing/#route-parameters) as shown in Vapor's documentation:

```swift
@Controller("hello")
final class HelloController {
    
    @Get(path: ":name")
    func hello(@PathParam name: String) async throws -> String {
        return "Hello, \(name)!"
    }
}
```
This is expanded to the following:
```swift
final class HelloController {
    
    func hello(@PathParam name: String) async throws -> String {
        return "Hello, \(name)!"
    }

    public func boot(routes: RoutesBuilder) {
        let controllerPath = "hello"
        let controller = routes.grouped(controllerPath.pathComponents)
        let handler0Path = ":name"
        controller.on(.GET, handler0Path.pathComponents, use: { req async throws in
                guard let nameParam = req.parameters.get("name", as: String.self) else {
                    throw Abort(.badRequest)
                }
                return try await self.hello(name: nameParam)
            })
    }
}
extension HelloController : RouteCollection {}
```
With the `@Controller` macro, `HelloController` now has a generated conformance to `RouteCollection`, and can easily register its handlers to a Vapor `Application` or other `RoutesBuilder` instances:
```swift
HelloController().boot(routes: app)
```
This package also contains a build tool plugin that automatically discovers route collections and exposes a helper method to quickly register them to a given `Application` instance. See [Controller Discovery Plugin](#controller-discovery-plugin) for more information.

## Installation

### Xcode
Go to `File > Add Package Dependency` and enter the repository URL:
```
https://github.com/aaronjedwards/vapor-routing-macros.git
```

### Swift Package Manager

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/aaronjedwards/vapor-routing-macros.git", branch: "main")
]
```

Then the `VaporRoutingMacros` dependency can be added to the relevant targets.

## Macros

This package provides a `@Controller` macro and a set of request handler macros. Request handler macros must be used within a type decorated with a `@Controller` macro. Unless used together, either an compiler error will be shown (incorrect usage) or an empty `RouteCollection` conformance will be generated.

## `@Controller` Macro

The `@Controller` macro does the heavy lifting and inspects the annotated class that it is attached to in order to generate the required `RouteCollection` boilerplate. The implementation inspects the class members and registers each function annotated with a [request handler macro](request-handler-macros) as a request handler. It takes in a required path parameter that defines the path with which request handlers will be grouped using `routes.grouped("path")`:
```swift
@Controller("api/todos")
final class TodoController {
    // functions decorated with @Get, @Post, etc...
}
```
Additionally, a middleware instance can be provided that will added to the middleware chain for all captured request handlers:
```swift
@Controller("api/todos", middleware: MyMiddleware())
final class TodoController {
    // functions decorated with @Get, @Post, etc...
}
```
This will expand to the following within the generated `boot(routes:)` function:
```swift
public func boot(routes: RoutesBuilder) {
    let controllerPath = "api/todos"
    let routesWithMiddleware = routes.grouped(MyMiddleware())
    let controller = routesWithMiddleware.grouped(controllerPath.pathComponents)

    // request handlers will be generated here...
}
```

## Request Handler Macros
This package provides the following macros for generating request handlers from functions:
* `@Get`
* `@Post`
* `@Patch`
* `@Put`
* `@Delete`
* `@Handler`

Each of these macros share the same undlerlying implementation and are identical in their usage, with the exception of the general purpose `@Handler` macro which requires 
specifying the HTTP method to be used. This can be used to generate a handler for other HTTP methods that do not have a corresponding macro. For example, this can be used to generate a request handler for requests made with the `HEAD` HTTP method:
```swift
@Handler(.HEAD, "path")
func handler(req: Request) -> Response {
  // do something based on the incoming request
}
```

### Usage

The functions decorated with one of these macros will result in a generated route handler with the corresponding HTTP method within the `boot(routes:)` function that is generated by the `@Controller` macro.

Every request handler macro can be provided with an optional `path` to specify which route should be handled. This path follows the same conventions that Vapor does elsewhere for defining path components. For example:
```swift
@Get(":id")
func find(@PathParam id: String) -> Todo {
  // find a given Todo with the provided path parameter
}

@Put(path: "create")
func create() -> Todo {
  // create a Todo
}
```
Will generate the following handlers:
```swift
public func boot(routes: RoutesBuilder) {
    // other boilerplate here...
    controller.on(.GET, ":id", use: { req async throws in
        // more boilerplate here...
    })
    controller.on(.PUT, "create", use: { req async throws in
        // more boilerplate here...
    })
}
```
Additionally, each macro can aceept a `body` parameter that specifies the `HTTPBodyStreamStrategy` to be used in the request handler:
```swift
@Post(body: .stream)
func upload(req: Request) -> Todo {
  // handle a file upload with a stream
}
```
Generates:
```swift
public func boot(routes: RoutesBuilder) {
    // other boilerplate here
    controller.on(.POST, body: .stream, use: { req async throws in
        // more boilerplate here...
    })
}
```

### Handler Parameters
Any function decorated with one of the above macros must only accept arguments with the following types or property wrappers:
* `Request`
  * If an argument of type `Request` is present, the incoming request instance will automatically passed into the call to the handler.
* `@PathParam`
  * Arguments using this property wrapper will result in attempting to extract a path parameter from the incoming request. For example, the following:
    ```swift
    @Get(":name")
    func hello(@PathParam name: String) -> String {
      return "Hello, \(name)!"
    }
    ```
    Will generate the following request handler:
    ```swift
    controller.on(.GET, ":name", use: { req async throws in
          guard let nameParam = req.parameters.get("name", as: String.self) else {
              throw Abort(.badRequest)
          }
          return self.hello(name: nameParam)
      })
    ```
    The argument name will be used to extract the path parameter from the request, which can be overriden by using `@PathParam("otherName")`. If no path parameter is found with the specified name, this will result in an `Abort(.badRequest)` error being thrown from the request handler.
* `@QueryParam`
  * Arguments using this property wrapper will result in attempting to extract a query parameter from the incoming request. For example, the following:
    ```swift
    @Get("hello")
    func hello(@QueryParam name: String?) -> String {
      return "Hello, \(name ?? "Anonymous")!"
    }
    ```
    Will generate the following request handler:
    ```swift
    controller.on(.GET, "hello", use: { req async throws in
          let nameParam: String? = req.query["name"]
          return self.hello(name: nameParam)
      })
    ```
    As with `@PathParam`, the argument name will be used to extract the query parameter from the request, which can be overriden by using `@QueryParam("otherName")`. By nature, query parameters are optional and the underlying type used with this property wrapper is required to also be optional.
* `@BodyContent`
  * Arguments using this property wrapper will result in attempting to decode the body of the incoming request as the specified argument type. For example, the following:
    ```swift
    @Put
    func create(@BodyContent todo: Todo) -> Todo {
      ...
    }
    ```
    Will generate the following request handler:
    ```swift
    controller.on(.PUT, use: { req async throws in
          guard let todoParam = try? req.content.decode(Todo.self) else {
              throw Abort(.badRequest)
          }
          return self.create(todo: todoParam)
      })
    ```
    If the specified type cannot be decoded from the body of the incoming request, this will result in an `Abort(.badRequest)` error being thrown from the request handler. The underlying type of this argument type must conform to Vapor's `Content` protocol.
* `@QueryContent`
  * Arguments using this property wrapper will result in attempting to decode the query content of the incoming request as the specified argument type. For example, the following:
    ```swift
    struct Hello {
        let name: String?
    }

    @Get
    func hello(@QueryContent hello: Hello) -> String {
      return "Hello, \(hello.name ?? "Anonymous")!"
    }
    ```
    Will generate the following request handler:
    ```swift
    controller.on(.GET, use: { req async throws in
          guard let helloParam = try? req.query.decode(Hello.self) else {
              throw Abort(.badRequest)
          }
          return self.hello(hello: helloParam)
      })
    ```
    If the specified type cannot be decoded from the query of the incoming request, this will result in an `Abort(.badRequest)` error being thrown from the request handler. The underlying type of this argument type must conform to Vapor's `Content` protocol.

A function decorated a request handler macro can use all of these together, to for example, easily decode the body, extract path parameters and get access to the underlying request:
```swift
@Patch(path: ":id")
func update(req: Request, @BodyContent content: Todo, @PathParam("id") idToUpdate: String) throws -> Todo {
    ...
}
```
These aruments can be freely specified in any order, but a handler that contains arguments of types other than what is specified above will result in a compiler error.

## Controller Discovery Plugin

This package also provides a build tool plugin that strives to provide a proof-of-concept for auto-discovery of "controllers" within a Vapor projects. Following the folder structure recommended from the Vapor docs, the plugin looks in the `/Controllers` directory of the target that it is applied to and finds all types that conform to the `ControllerDiscoverable` protocol, which is defined as:
```swift
public protocol ControllerDiscoverable: RouteCollection {
    init()
}
```
It then generates an extension on `Application` with a function that registers the request handlers of each discovered type with the `boot(routes:)` function from the `RouteCollection` conformance. This can then be used to easily register all discovered controllers with:
```swift
app.registerControllers()
```
To get a working concept, this auto-discovery of "controllers" requires types to have an empty initializer. Because there is utility in leveraging the routing macros in this package separately from this discovery mechanism, the `@Controller` macro does not require or generate a conformance to `ControllerDiscoverable`. These could potentially be combined by placing limitations on `RouteCollection`, but for now this package adds a purpose built protocol and requires opting in.

## License

VaporRoutingMacros is available under the MIT license. See the [LICENSE](LICENSE) for details.
