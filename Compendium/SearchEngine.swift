//
//  SearchEngine.swift
//  GenUI
//
//  Created by Purav Manot on 28/04/24.
//

import Foundation
import SwiftUI
import OpenAI
import Browser

@Observable
class SearchEngine {
    @MainActor 
    var browser = Browser(mobile: false, allowsJS: true)
    //@MainActor private var internalBrowser = Browser(allowsJS: false)
    
    private var lastSearch: String = "github"
    private var params: [URLQueryItem] = []
    private var reuseCycles = 5
    
    @MainActor
    var progress: Double { browser.estimatedProgress }
    
    init() {
        
    }
    
    public func fetchCurrentResults() async throws -> [GoogleSearchResult] {
        try await browser.callJSFunction("return await fetchResults(1, 2000)", functionReturnType: .jsonString, expecting: [Browser._JSGoogleSearchResult].self).compactMap { $0.googleSearchResult(for: "") }
    }
    
    public func imageSearchResults(for image: UIImage) async throws -> String {
        let base64String = try image
            .data(using: .jpeg(compressionQuality: 0.8))
            .unwrap()
            .base64EncodedString()
        let imageURL = "data:image/jpeg;base64,\(base64String)"
        
        try await browser.loadAndWaitForNavigation(URL(string: "https://www.google.com/?olud")!)
        try await Task.sleep(for: .milliseconds(500))
        try await browser.callJSFunction(
            """
            document.querySelector('[placeholder="Paste image link"]').value = encodedURL;
            document.querySelector('[jsAction="click:HiUbje"]').click()
            """,
            arguments: ["encodedURL" : imageURL]
        )
        
        try await Task.sleep(for: .milliseconds(500))
        try await browser.waitForNavigation()
        
        return try await browser.callJSFunction("""
        return JSON.stringify(Array.from(document.querySelector('[data-video-autoplay-mode="3"]').querySelectorAll('[href]')))
        """, expecting: String.self)
    }
    
    @MainActor
    public func results(for query: String, useSearchBar: Bool = true, n: Int = 6) -> AsyncThrowingStream<[GoogleSearchResult], Error> {
        defer {
            lastSearch = query
            reuseCycles -= 1
            
            if reuseCycles <= 0 {
                self.params = browser.url.extractQueryParameters()
                self.params.removeAll { $0.name == "q" || $0.name == "ei" }
            }
        }
        
        guard self.reuseCycles > 0 else {
            return AsyncThrowingStream { continuation in
                Task.detached(priority: .high) { @MainActor in
                    do {
                        let results = try await self.browser.getGoogleSearchResults(for: query, useSearchBar: true, n: n)
                        
                        continuation.yield(with: .success(results))
                        continuation.finish()
                        
                        self.reuseCycles = 5
                    } catch {
                        continuation.yield(with: .failure(error))
                    }
                }
            }
        }
        
        return AsyncThrowingStream<[GoogleSearchResult], Swift.Error> { continuation in
            continuation.onTermination = { status in
                print("Stream terminated with status \(status)")
                Task.detached { @MainActor in
                    self.browser.onDocumentChange = nil
                }
            }
            
            Task.detached(priority: .high) { @MainActor in
                self.browser.onDocumentChange = {
                    Task.detached(priority: .medium) { @MainActor in
                        if self.browser.isLoading {
                            do {
                                let uncheckedResults = try await self.browser.callJSFunction(
                                """
                                const element = document.querySelector('#fprs > a.spell_orig');
                                if (element && element.href) {
                                    console.log('searching for actual query')
                                    window.location.href = element.href;
                                }
                                return await fetchResults(1, 2000);
                                """, functionReturnType: .jsonString, expecting: [Browser._JSGoogleSearchResult].self)
                                let results = uncheckedResults.compactMap { $0.googleSearchResult(for: query) }
                                
                                continuation.yield(with: .success(results))
                            } catch {
                                return
                            }
                        }
                    }
                }
                
                do {
                    let url = try Browser.googleSearchURL(for: query, with: self.params).unwrap()
                    try await self.browser.loadAndWaitForNavigation(url)
                    try await Task.sleep(for: .milliseconds(100))
                    
                    let uncheckedResults: [Browser._JSGoogleSearchResult] = try await self.browser.callJSFunction(
                    """
                    const element = document.querySelector('#fprs > a.spell_orig');
                    if (element && element.href) {
                        console.log('searching for actual query')
                        window.location.href = element.href;
                    }
                    return await fetchResults(n, 10000);
                    """, arguments: ["n" : n], functionReturnType: .jsonString)
                    
                    let results = uncheckedResults.compactMap { $0.googleSearchResult(for: query) }
                    
                    continuation.yield(with: .success(results))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
