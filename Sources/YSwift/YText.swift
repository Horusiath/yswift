import Combine
import Foundation
import Yniffi

public final class YText: Transactable {
    private let _text: YrsText
    let document: YDocument

    init(text: YrsText, document: YDocument) {
        _text = text
        self.document = document
    }

    public func append(_ text: String, in transaction: YrsTransaction? = nil) {
        withTransaction(transaction) { txn in
            self._text.append(tx: txn, text: text)
        }
    }

    public func insert(
        _ text: String,
        at index: UInt32,
        in transaction: YrsTransaction? = nil
    ) {
        withTransaction(transaction) { txn in
            self._text.insert(tx: txn, index: index, chunk: text)
        }
    }

    public func insertWithAttributes(
        _ text: String,
        attributes: [String: Any],
        at index: UInt32,
        in transaction: YrsTransaction? = nil
    ) {
        withTransaction(transaction) { txn in
            self._text.insertWithAttributes(tx: txn, index: index, chunk: text, attrs: Coder.encoded(attributes))
        }
    }

    public func insertEmbed<T: Encodable>(
        _ embed: T,
        at index: UInt32,
        in transaction: YrsTransaction? = nil
    ) {
        withTransaction(transaction) { txn in
            self._text.insertEmbed(tx: txn, index: index, content: Coder.encoded(embed))
        }
    }

    public func insertEmbedWithAttributes<T: Encodable>(
        _ embed: T,
        attributes: [String: Any],
        at index: UInt32,
        in transaction: YrsTransaction? = nil
    ) {
        withTransaction(transaction) { txn in
            self._text.insertEmbedWithAttributes(tx: txn, index: index, content: Coder.encoded(embed), attrs: Coder.encoded(attributes))
        }
    }

    public func format(
        at index: UInt32,
        length: UInt32,
        attributes: [String: Any],
        in transaction: YrsTransaction? = nil
    ) {
        withTransaction(transaction) { txn in
            self._text.format(tx: txn, index: index, length: length, attrs: Coder.encoded(attributes))
        }
    }

    public func removeRange(
        start: UInt32,
        length: UInt32,
        in transaction: YrsTransaction? = nil
    ) {
        withTransaction(transaction) { txn in
            self._text.removeRange(tx: txn, start: start, length: length)
        }
    }

    public func getString(in transaction: YrsTransaction? = nil) -> String {
        withTransaction(transaction) { txn in
            self._text.getString(tx: txn)
        }
    }

    public func length(in transaction: YrsTransaction? = nil) -> UInt32 {
        withTransaction(transaction) { txn in
            self._text.length(tx: txn)
        }
    }

    public func observe() -> AnyPublisher<[YTextChange], Never> {
        let subject = PassthroughSubject<[YTextChange], Never>()
        let subscriptionId = observe { subject.send($0) }
        return subject.handleEvents(receiveCancel: { [weak self] in
            self?._text.unobserve(subscriptionId: subscriptionId)
        })
        .eraseToAnyPublisher()
    }

    public func observe(_ callback: @escaping ([YTextChange]) -> Void) -> UInt32 {
        _text.observe(
            delegate: YTextObservationDelegate(
                callback: callback,
                decoded: Coder.decoded(_:)
            )
        )
    }

    public func unobserve(_ subscriptionId: UInt32) {
        _text.unobserve(subscriptionId: subscriptionId)
    }
}

extension YText: Equatable {
    public static func == (lhs: YText, rhs: YText) -> Bool {
        lhs.getString() == rhs.getString()
    }
}

public extension String {
    init(_ yText: YText) {
        self = yText.getString()
    }
}

extension YText: CustomStringConvertible {
    public var description: String {
        getString()
    }
}

class YTextObservationDelegate: YrsTextObservationDelegate {
    private var callback: ([YTextChange]) -> Void
    private var decoded: (String) -> [String: Any]

    init(
        callback: @escaping ([YTextChange]) -> Void,
        decoded: @escaping (String) -> [String: Any]
    ) {
        self.callback = callback
        self.decoded = decoded
    }

    func call(value: [YrsDelta]) {
        let result: [YTextChange] = value.map { rsChange -> YTextChange in
            switch rsChange {
            case let .inserted(value, attrs):
                return YTextChange.inserted(value: value, attributes: decoded(attrs))
            case let .retained(index, attrs):
                return YTextChange.retained(index: index, attributes: decoded(attrs))
            case let .deleted(index):
                return YTextChange.deleted(index: index)
            }
        }
        callback(result)
    }
}

public enum YTextChange {
    case inserted(value: String, attributes: [String: Any])
    case deleted(index: UInt32)
    case retained(index: UInt32, attributes: [String: Any])
}