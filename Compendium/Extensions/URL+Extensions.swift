//
//  URL+Extensions.swift
//  BrowserAgent
//
//  Created by Purav Manot on 18/04/24.
//

import Foundation

extension URL {
    public init(string staticString: StaticString) {
        let string = staticString.withUTF8Buffer({ String(decoding: $0, as: UTF8.self) })
        self.init(string: string)!
    }
}

extension URL {
    var queryItems: [URLQueryItem]? {
        return URLComponents(string: self.absoluteString)?.queryItems
    }
}

extension Optional<URL> {
	func extractQueryParameters() -> [URLQueryItem] {
		guard let url = self,
			  let components = URLComponents(string: url.absoluteString),
			  let queryItems = components.queryItems else {
			return []
		}
		
		return queryItems
	}
}
