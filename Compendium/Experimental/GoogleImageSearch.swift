//
//  GoogleImageSearch.swift
//  Compendium
//
//  Created by Purav Manot on 14/07/24.
//

import SwiftUI
import Browser

struct GoogleImageSearch: View {
    @State var browser = Browser(url: URL(string: "https://www.google.com/?olud"))
    
    var body: some View {
        VStack {
            BrowserView(browser: browser)
            
            Button("Search") {
                Task {
                    do {
                        try await browser.callJSFunction(
                        """
                        document.querySelector('[placeholder="Paste image link"]').value = encodedURL;
                        document.querySelector('[jsAction="click:HiUbje"]').click()
                        """,
                        arguments: ["encodedURL" : "<base 64 url>"]
                        )
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }
}

#Preview {
    GoogleImageSearch()
}
