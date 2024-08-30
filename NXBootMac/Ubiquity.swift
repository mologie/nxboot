import Foundation

@Observable
class UbiquityIdentityObserver: NSObject {
    var token: UbiquityToken?

    override init() {
        super.init()
        observeUbiquityChanges()
    }

    func observeUbiquityChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateToken),
            name: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil
        )
        updateToken()
    }

    @objc
    func updateToken() {
        if let opaqueToken = FileManager.default.ubiquityIdentityToken {
            token = UbiquityToken(wrapped: opaqueToken)
        } else {
            token = nil
        }
    }
}

struct UbiquityToken: Equatable {
    typealias OpaqueToken = (NSCoding & NSCopying & NSObjectProtocol)
    let wrapped: OpaqueToken

    static func == (lhs: UbiquityToken, rhs: UbiquityToken) -> Bool {
        return lhs.wrapped.isEqual(rhs.wrapped)
    }
}
