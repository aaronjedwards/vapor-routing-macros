import Vapor

public protocol ControllerDiscoverable: RouteCollection {
    init()
}
