//
//  OpenAI+Extensions.swift
//  BrowserAgent
//
//  Created by Purav Manot on 18/04/24.
//

import Foundation
import SwiftUI
import OpenAI

extension OpenAI {
    static public var api = OpenAI.Client(apiKey: "<apiKey>")
}

extension OpenAI.Client {
    func response(model: OpenAI.Model.Chat, system: String, prompt: OpenAI.ChatMessageBody, history: [OpenAI.ChatMessageBody] = [], parameters: ChatCompletionParameters, totalCost: inout Double) async throws -> OpenAI.ChatCompletion {
        let response = try await self.createChatCompletion(messages: self.constructChatMessages(system: system, prompt: prompt, history: history), model: model, parameters: parameters)
        let cost = response.usage.cost(for: model)
        totalCost += cost
        return response
    }
    
    func response<T: Codable>(model: OpenAI.Model.Chat, system: String, prompt: OpenAI.ChatMessageBody, history: [OpenAI.ChatMessageBody] = [], parameters: ChatCompletionParameters, totalCost: inout Double, expecting: T.Type? = nil) async throws -> T? {
        let rawResponse = try await self.response(model: model, system: system, prompt: prompt, history: history, parameters: parameters, totalCost: &totalCost)
        let topChoice = rawResponse.choices.first?.message.body
        
        return try self.processResponse(topChoice: topChoice)
    }
    
    func response<T: Codable>(model: OpenAI.Model.Chat, system: String, prompt: String, history: [OpenAI.ChatMessageBody] = [], parameters: ChatCompletionParameters = .init(), totalCost: inout Double, expecting: T.Type? = nil) async throws -> T? {
        try await self.response(model: model, system: system, prompt: .text(prompt), history: history, parameters: parameters, totalCost: &totalCost, expecting: T.self)
    }
    
    private func constructChatMessages(system: String, prompt: OpenAI.ChatMessageBody, history: [OpenAI.ChatMessageBody]) -> [OpenAI.ChatMessage] {
        var messages: [OpenAI.ChatMessage] = [OpenAI.ChatMessage(role: .system, content: system)]
        messages += history.enumerated().map { index, body in
            OpenAI.ChatMessage(role: index % 2 == 0 ? .user : .assistant, body: body)
        }
        messages.append(OpenAI.ChatMessage(role: .user, body: prompt))
        return messages
    }
    
    private func processResponse<T: Codable>(topChoice: OpenAI.ChatMessageBody?) throws -> T? {
        guard let topChoice = topChoice else { return nil }
        
        switch topChoice {
            case .text(let string):
                if T.self == String.self {
                    return string as? T
                } else if T.self == Int.self {
                    return Int(string) as? T
                } else {
                    let jsonString = string.removeCodeBlock()
                    
                    do {
                        let data = Data(jsonString.utf8)
                        return try JSONDecoder().decode(T.self, from: data)
                    } catch {
                        throw ConversionError.invalidJSON(error: error)
                    }
                }
                
            default:
                return nil
        }
    }
    
    enum ConversionError: Error {
        case invalidJSON(error: Error)
    }
}


extension OpenAI.Client {
    func response(model: OpenAI.Model.Chat, system: String, prompt: OpenAI.ChatMessageBody, history: [OpenAI.ChatMessageBody] = [], parameters: ChatCompletionParameters) async throws -> OpenAI.ChatCompletion {
        
        let messages: [OpenAI.ChatMessage] = [OpenAI.ChatMessage(role: .system, content: system)]
        + history.enumerated().map { index, body in
            OpenAI.ChatMessage(role: index % 2 == 0 ? .user : .assistant, body: body)
        }
        + [OpenAI.ChatMessage(role: .user, body: prompt)]
        
        return try await self.createChatCompletion(messages: messages, model: model, parameters: parameters)
    }
    
    func response<T: Codable>(model: OpenAI.Model.Chat, system: String, prompt: OpenAI.ChatMessageBody, history: [OpenAI.ChatMessageBody] = [], parameters: ChatCompletionParameters, expecting: T.Type? = nil) async throws -> T? {
        let rawResponse = try await self.response(model: model, system: system, prompt: prompt, history: history, parameters: parameters)
        let topChoice = rawResponse.choices.first?.message.body
        
        
        switch topChoice {
            case .text(let string):
                print(string)
                if T.self == String.self {
                    return (string as? T?).flatMap { $0 }
                } else if T.self == Int.self {
                    return (Int(string) as? T?).flatMap { $0 }
                } else {
                    let jsonString = string.removeCodeBlock()
                    
                    do {
                        let data: Data = try jsonString.data()
                        return try data.decode(T.self)
                    } catch {
                        throw ConversionError.invalidJSON(error: error)
                    }
                }
                
            default:
                return nil
        }
    }
    
    func response<T: Codable>(model: OpenAI.Model.Chat, system: String, prompt: String, history: [OpenAI.ChatMessageBody] = [], parameters: ChatCompletionParameters = .init(), expecting: T.Type? = nil) async throws -> T? {
        try await self.response(model: model, system: system, prompt: .text(prompt), parameters: parameters)
    }
}

extension OpenAI.Usage {
    func cost(for model: OpenAI.Model.Chat) -> Double {
        var promptCost: Double
        var completionCost: Double
        switch model {
            case .gpt_3_5_turbo, .gpt_3_5_turbo_0125:
                promptCost = 0.5/1000000
                completionCost = 1.5/1000000
            case .gpt_4_0125_preview, .gpt_4_turbo, .gpt_4_vision_preview:
                promptCost = 0.00001
                completionCost = 0.00003
            case .gpt_4o:
                promptCost = 5.00/1000000
                completionCost = 15.00/1000000
            default:
                print("cost function unimplemented for \(model.name)")
                promptCost = 0
                completionCost = 0
                
        }
        
        return Double(self.promptTokens)*promptCost + Double(self.completionTokens ?? 0)*completionCost
    }
}

extension String {
    func removeCodeBlock() -> String {
        self
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "'''", with: "")
    }
}

#if os(iOS) || os(tvOS) || os(visionOS)
extension OpenAI.ChatMessageBody._Content {
    static public func image(_ image: UIImage, compressionQuality: Double = 0.2) throws -> OpenAI.ChatMessageBody._Content {
        let base64String = try image
            .data(using: .jpeg(compressionQuality: compressionQuality))
            .unwrap()
            .base64EncodedString()
        let imageURL = URL(string: "data:image/jpeg;base64,\(base64String)")!

        return OpenAI.ChatMessageBody._Content.imageURL(ImageURL(url: imageURL, detail: .auto))
    }
}
#elseif os(macOS)
extension OpenAI.ChatMessageBody._Content {
    static public func image(_ image: NSImage, compressionQuality: Double = 0.2) throws -> OpenAI.ChatMessageBody._Content {
        let base64String = try image
            .data(using: .jpeg(compressionQuality: compressionQuality))
            .unwrap()
            .base64EncodedString()
        let imageURL = URL(string: "data:image/jpeg;base64,\(base64String)")!

        return OpenAI.ChatMessageBody._Content.imageURL(ImageURL(url: imageURL, detail: .high))
    }
}
#endif
