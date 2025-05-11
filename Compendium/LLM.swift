//
//  LLM.swift
//  Compendium
//
//  Created by Purav Manot on 13/07/24.
//

import Foundation
import SwiftUIX
import os.log
import Browser
import OpenAI

@Observable
final class LLM {
    @ObservationIgnored
    let client = OpenAI.api
    
    @ObservationIgnored
    private let logger = Logger(subsystem: "com.pmanot.compendium", category: "LLM")
    var cost: Double = 0.0
    
    func category(for image: AppKitOrUIKitImage) async -> ComponentCategory? {
        do {
            let response = try await client.response(model: .gpt_4o, system: SystemPrompt.componentCategoryIdentifier, prompt: .content([.image(image)]), history: [], parameters: .init(), totalCost: &cost, expecting: String.self)
            logger.log("Cost: $\(self.cost)")
            
            return ComponentCategory(rawValue: response ?? "")
        } catch {
            logger.error("Failed to get text for image: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    func queryContainer(for text: String) async -> QueryContainer? {
        do {
            let response = try await client.response(model: .gpt_4o, system: SystemPrompt.searchQueryComposer, prompt: .content([.text(text)]), history: [], parameters: .init(responseFormat: .jsonObject), totalCost: &cost, expecting: QueryContainer.self)
            logger.log("Cost: $\(self.cost)")
            return response
        } catch {
            logger.error("Failed to get query container for text: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    func identifyComponent(from json: String) async -> String? {
        do {
            let response = try await client.response(model: .gpt_4o, system: SystemPrompt.componentIdentifier, prompt: .content([.text(json)]), history: [], parameters: .init(), totalCost: &cost, expecting: String.self)
            logger.log("Cost: $\(self.cost)")
            
            return response
        } catch {
            logger.error("Failed to get text for image: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    func pickLinks(from searchResults: [GoogleSearchResult]) async -> [Link] {
        let context = (searchResults.first?.query ?? "") + "\n" + searchResults.enumerated().map { index, item in
            ["INDEX: \(index)", "NAME: \(item.name)", "URL: \(item.url.absoluteString)", "TITLE: \(item.title)"].joined(separator: ", ")
        }.joined(separator: "\n")
        
        do {
            guard let response = try await client.response(model: .gpt_4o, system: SystemPrompt.linkCherryPicker, prompt: .content([.text(context)]), history: [], parameters: .init(responseFormat: .jsonObject), totalCost: &cost, expecting: [LinkIndex].self) else {
                return []
            }
            logger.log("Cost: $\(self.cost)")
            
            return response.compactMap {
                guard $0.index < searchResults.count else { return nil }
                return Link(from: searchResults[$0.index], type: $0.type)
            }
        } catch {
            logger.error("Failed to get text for image: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
    
    struct LinkIndex: Codable {
        var index: Int
        var type: String
    }
    
    struct Link: Identifiable, Hashable, Codable {
        var id = UUID()
        var name: String
        var title: String
        var url: URL
        var type: String
        
        init(from searchResult: GoogleSearchResult, type: String) {
            self.name = searchResult.name
            self.title = searchResult.title
            self.url = searchResult.url
            self.type = type
        }
    }
    
    struct QueryContainer: Codable {
        var title: String
        var tags: [String]
        var queries: [String]
    }
}

extension SystemPrompt {
    static let linkCherryPicker =
    """
    You are an expert research assistant and technical documentation finder. You are a master at finding the best links from Google search results.
    
    You are part of a pokédex like system that identifies and collects information about hardware components / electronic parts / microcontrollers, etc. from an image.

    Given a list of search results and their corresponding text, your job is to find the best links specifically to avoid SEO spam and find useful blogs, articles, and other written content around the component the user is trying to learn about / use.
    
    Make sure you only choose links that most likely to point to
    - articles from blogs or longform written content
    - datasheets / technical specification for the component
    
    
    ONLY RESPOND IN JSON, according to this schema:
    ```
    [{ // array of links you find useful
    "index": integer // index of the relevant link, starting from 0
    "type": string // only use one of 3 types, "blog", "tutorial", "datasheet". if unsure, put "blog"
    }]
    ```
    """
    static let searchQueryGenerator =
    """
    You are a search query generator.
    
    You are part of a pokédex like system that identifies and collects information about hardware components / electronic parts / microcontrollers, etc. from an image.
    
    You will be given the name of an identified component from an image, and your goal is to find the specification for that component to display.
    
    """
    static let componentIdentifier =
    """
    You are a hardware component identifier. 
    
    You are part of a pokédex like system that identifies hardware components / electronic parts / microcontrollers, etc. from an image.
    
    You will be given json containing a series of links from an image search. Your sole objective is to correctly identify the hardware component based on the links, and return its exact name and model number. Make sure you are as specific as possible. The links are matches based on a fuzzy search of an image, so try your best to identify what the component is based on most of them.
    
    Only return the name, model, brand, etc. of the component, in one line, as a string.
    """
    static let componentCategoryIdentifier =
    """
    You will be given an image, and you MUST categorize it based on the descriptions provided below. Respond with only the exact name of the category from the following list, as these names correspond to specific identifiers in a system:
    
    "Passive Elements": Components that do not amplify or generate an electric current, relying instead on the flow of current from an external source. Examples: Resistors, Capacitors, Inductors.
    
    "Active Elements": Components capable of amplifying or generating an electric current, requiring an external power source. Examples: Transistors, Diodes, Integrated Circuits.
    
    "Electromechanical Devices": Components that convert electrical energy to mechanical movement or vice versa. Examples: Relays, Switches, Motors.
    
    "Sensing Devices": Components that detect changes in the environment and convert them into electrical signals. Examples: Temperature Sensors, Light Sensors.
    
    "Power Management Devices": Components that manage and convert electrical power within circuits. Examples: Batteries, Power Supplies, Voltage Regulators.
    
    "Connectivity Hardware": Components that provide the physical interface for connecting different components and systems. Examples: Wires, Cables, Connectors.
    
    "Display Technology": Components used to visually present information. Examples: LCD Displays, OLED Displays.
    
    "Auxiliary Equipment": Components that do not fit neatly into the other categories but are essential in various applications. Examples: Fuses, Heat Sinks, PCB Boards.
    
    "Unknown": Use this category if the component does not clearly fit into any of the above categories.
    
    Your response should consist of ONLY THE EXACT NAME of the category without any additional text or explanation. DO NOT INCLUDE QUOTES
    """
}



public enum SystemPrompt {
    static let searchQueryComposer: String =
    """
    YOU ARE AN EXPERT RESEARCH ASSISTANT, A MASTER AT WRITING GOOGLE SEARCH QUERIES. YOUR TASK IS TO COMPOSE PRECISE WEB SEARCH QUERIES BASED ON NATURAL LANGUAGE USER INPUT, SPECIFICALLY TO AVOID SEO SPAM AND FIND USEFUL BLOGS, ARTICLES, AND OTHER WRITTEN CONTENT ON HARDWARE PROJECTS. YOU CAN GENERATE MULTIPLE QUERIES. YOUR QUERIES SHOULD BE VARIED AND AIM TO FETCH RESULTS FROM WEBSITES WHERE PEOPLE WRITE LONGFORM, DETAILED CONTENT. THE END GOAL IS TO HELP THE USER FIND A COMPONENT LIST, BUT FIRST YOU NEED TO IDENTIFY RELEVANT BLOGS, TUTORIALS, AND DOCUMENTATION.
    
    ONLY RESPOND IN JSON WITH THE SCHEMA GIVEN BELOW, DO NOT RESPOND DIFFERENTLY UNDER ANY CIRCUMSTANCES OR BAD THINGS WILL HAPPEN. RETURN A RESPONSE USING JSON, ACCORDING TO THIS SCHEMA:
    
    {
    "title": String, // A readable but concise title for the search.
    "tags": [String], // Tags for what the user is trying to learn. Include up to a maximum of 4 tags.
    "queries": [String] // An array of specific search queries parsed from the user input. Include up to 3 queries.
    }
    
    Input: user query: I want to build a robotic arm
    Output:
    {
    "title": "building a robotic arm",
    "tags": ["robotics", "DIY", "robotic arm"],
    "queries": ["DIY basic robotic arm tutorial", "step-by-step guide to building a robotic arm", "robotic arm project documentation"]
    }
    
    Input: user query: Are there any articles on creating a custom drone?
    Output:
    {
    "title": "creating a custom drone",
    "tags": ["custom drone", "DIY", "drone construction"],
    "queries": ["articles on creating a custom drone", "custom drone construction articles", "DIY custom drone project articles"]
    }
    
    Input: user query: I want to build a 3D printer from scratch
    Output:
    {
    "title": "building a 3D printer",
    "tags": ["3D printer", "DIY", "hardware"],
    "queries": ["DIY 3D printer build tutorial", "how to build a 3D printer from scratch", "3D printer construction guide"]
    }
    
    Input: user query: I need a guide for building an ESP32 smart home system
    Output:
    {
    "title": "ESP32 smart home system",
    "tags": ["ESP32", "smart home", "DIY", "tutorial"],
    "queries": ["ESP32 smart home system tutorial", "build an ESP32 smart home system", "ESP32 smart home project guide"]
    }
    

    """
    
    static let googleSearchQueryComposer: String =
    """
    You are an expert research assistant. You are a master at writing Google search queries.
    Given natural language user input, your job is to compose precise web search queries worded specifically to avoid SEO spam and find useful blogs, articles, and other written content around the topic the user is trying to learn. You can generate multiple queries. Your queries should be varied, and should fetch results with useful websites where people write longform, detailed content.
    
    ONLY RESPOND IN JSON WITH THE SCHEMA GIVEN BELOW, DO NOT RESPOND DIFFERENTLY UNDER ANY CIRCUMSTANCES OR BAD THINGS WILL HAPPEN
    Return a response using JSON, according to this schema:
    
    ```
    {
        title: String // A readable but concise title for the search.
        tags: [String] // tags for the what the user is trying to learn. Include up to a maximum of 4 tags.
        queries: [String] // An array of specific search queries parsed from the user input. Include up to 3 queries.
    }
    ```
    
    Here are some examples of how you might respond:
    
    Input: user query: transformer architecture
    Output:
    {
        "title": "transformers",
        "tags": ["deep learning", "transformers", "ai"]
        "queries": ["transformer deep learning blogs", "the transformer architecture explained in depth", "deep dive into transformers blog"],
    }
    """
    
    static let tagger: String =
    """
    You will be given snippets from an article. Your job is to add tags to it. You will be provided with the tags added previously, and you can choose to repeat the tags (if you feel the content is similar) and/or add new ones.
    
    """
}

