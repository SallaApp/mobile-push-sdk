import ObjectiveC
import XCTest

/// The compiler only warns when RNSallaPush.mm lacks a method of the codegen spec or of SallaPushEventEmitter, and the
/// app would then fail when JavaScript calls that method or SallaPush emits that event.
final class RNSallaPushTests: XCTestCase {
    func testTheModuleImplementsEveryMethodOfTheSpecAndOfTheEmitterProtocol() throws {
        let module: AnyClass = try XCTUnwrap(NSClassFromString("RNSallaPush"))
        for name in ["NativeRNSallaPushSpec", "SallaPushEventEmitter"] {
            let methods = try requiredInstanceMethods(of: name)
            XCTAssertFalse(methods.isEmpty, name)
            for selector in methods {
                XCTAssertTrue(class_respondsToSelector(module, selector), "\(name): \(NSStringFromSelector(selector))")
            }
        }
    }

    private func requiredInstanceMethods(of name: String) throws -> [Selector] {
        let declared = try XCTUnwrap(objc_getProtocol(name), name)
        var count: UInt32 = 0
        guard let methods = protocol_copyMethodDescriptionList(declared, true, true, &count) else { return [] }
        defer { free(methods) }
        return UnsafeBufferPointer(start: methods, count: Int(count)).compactMap(\.name)
    }
}
