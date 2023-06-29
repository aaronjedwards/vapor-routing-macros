import Vapor

@propertyWrapper
public struct PathParam<Value: LosslessStringConvertible> {
    public var wrappedValue: Value
    let name: String?
    
    public init(wrappedValue: Value, _ name: String? = nil) {
        self.wrappedValue = wrappedValue
        self.name = name
    }
}

@propertyWrapper
public struct QueryParam<Value: Decodable> {
    public var wrappedValue: Value?
    let name: String?
    
    public init(wrappedValue: Value?, _ name: String? = nil) {
        self.wrappedValue = wrappedValue
        self.name = name
    }
}

@propertyWrapper
public struct QueryContent<Value: Content> {
    public var wrappedValue: Value
    
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

@propertyWrapper
public struct BodyContent<Value: Content> {
    public var wrappedValue: Value
    
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

@attached(conformance)
@attached(member, names: named(boot), named(init))
public macro Controller(_ path: String, middleware: Middleware? = nil) = #externalMacro(
    module: "VaporRoutingMacrosMacros",
    type: "ControllerMacro"
)

@attached(peer)
public macro Get(path: String? = nil, body: HTTPBodyStreamStrategy? = nil) = #externalMacro(
    module: "VaporRoutingMacrosMacros",
    type: "HandlerMacro"
)

@attached(peer)
public macro Post(path: String? = nil, body: HTTPBodyStreamStrategy? = nil) = #externalMacro(
    module: "VaporRoutingMacrosMacros",
    type: "HandlerMacro"
)

@attached(peer)
public macro Patch(path: String? = nil, body: HTTPBodyStreamStrategy? = nil) = #externalMacro(
    module: "VaporRoutingMacrosMacros",
    type: "HandlerMacro"
)

@attached(peer)
public macro Put(path: String? = nil, body: HTTPBodyStreamStrategy? = nil) = #externalMacro(
    module: "VaporRoutingMacrosMacros",
    type: "HandlerMacro"
)

@attached(peer)
public macro Delete(path: String? = nil, body: HTTPBodyStreamStrategy? = nil) = #externalMacro(
    module: "VaporRoutingMacrosMacros",
    type: "HandlerMacro"
)

@attached(peer)
public macro Handler(_ method: HTTPMethod, path: String = "") = #externalMacro(
    module: "VaporRoutingMacrosMacros",
    type: "HandlerMacro"
)


