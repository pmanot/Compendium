//
//  ContentView.swift
//  Compendium
//
//  Created by Purav Mancot on 13/07/24.
//

import SwiftUIX
import Media
import Browser

struct ContentView: View {
    @State private var llm = LLM()
    @State private var searchEngine = SearchEngine()
    @State private var engines: [SearchEngine] = [.init(), .init(), .init()]
    @State private var category: ComponentCategory = .unknown
    @State private var screenshot: AppKitOrUIKitImage? = nil
    @State private var isDetecting: Bool = false
    @State private var query: String = ""
    @State private var component: Component?
    @State private var componentName: String?
    
    var body: some View {
        NavigationStack {            
            CameraViewReader { proxy in
                VStack(spacing: 40) {
                    indicatorGroupView
                    
                    Spacer()
                    
                    Button {
                        processImage(proxy: proxy)
                    } label: {
                        Group {
                            if let name = componentName {
                                Text(name)
                            } else {
                                Text("Identify")
                            }
                        }
                        .contentTransition(.interpolate)
                        .font(.title2)
                        .fontDesign(.monospaced)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.black)
                        .padding(5)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.white)
                    .phaseAnimator([true, false]) { content, phase in
                        if isDetecting {
                            content
                                .scaleEffect(phase ? 0.9 : 1.1)
                        } else {
                            content
                        }
                    }
                    .padding(.horizontal, 10)
                    
                    
                    SearchBar { query in
                        Task(priority: .high) {
                            let results = await searchResults(for: query)
                            let links = await llm.pickLinks(from: results)
                            
                            self.component = Component(name: query, links: links)
                            isDetecting = false
                        }
                    }
                }
                .background(alignment: .center) {
                    viewFinder
                        .background(Color.pokedex.ignoresSafeArea(.all))
                }
            }
            .sheet(item: $component, onDismiss: {
                component = nil
                componentName = nil
                isDetecting = false
            }) { component in
                ComponentDetailView(component: component)
                    .presentationBackground(Material.bar)
                    .presentationCornerRadius(25)
            }
            .animation(.bouncy, value: componentName)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(llm.cost, format: .currency(code: "USD"))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.red)
                }
                /*
                 ToolbarItem(placement: .navigation) {
                 Button("Search", systemImage: .magnifyingglass) {
                 Task {
                 do {
                 print("searching")
                 let image = try await camera.capturePhoto()
                 let result = try await searchEngine.imageSearchResults(for: image)
                 print(result)
                 } catch {
                 print(error)
                 }
                 
                 }
                 }
                 .buttonStyle(.borderedProminent)
                 .tint(.black)
                 }*/
                
                ToolbarItem(placement: .primaryAction) {
                    Label(category.rawValue, systemImage: category.symbolName)
                        .labelStyle(.titleAndIcon)
                        .tint(.yellow)
                }
            }
        }
    }
    
    @ViewBuilder
    var indicatorGroupView: some View {
        HStack(alignment: .top, spacing: 20) {
            Circle()
                .fill(.blue.gradient)
                .phaseAnimator([true, false]) { content, phase in
                    content
                        .overlay {
                            if isDetecting {
                                Circle().fill(.white.opacity(phase ? 0 : 0.75))
                            }
                        }
                }
            
                .frame(width: 50, height: 50)
                .overlay {
                    ZStack {
                        Circle()
                            .inset(by: 1.5)
                            .stroke(lineWidth: 3.0)
                            .fill(.white)
                        
                        Circle()
                            .inset(by: 3.0)
                            .stroke(lineWidth: 0.5)
                            .fill(.black)
                        
                        Circle()
                            .stroke(lineWidth: 0.5)
                            .fill(.black)
                    }
                }
            
            HStack {
                Group {
                    Circle()
                        .foregroundStyle(.red.gradient)
                    Circle()
                        .foregroundStyle(.yellow.gradient)
                    Circle()
                        .foregroundStyle(.black.gradient)
                }
                .shadow(radius: 1)
                .frame(width: 12, height: 12)
            }
            .padding(.vertical, 10)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    var viewFinder: some View {
        CameraView()
            .background(.black)
            .mask {
                GeometryReader { proxy in
                    ContainerRelativeShape()
                        .frame(height: proxy.size.width - 20)
                        .padding(.horizontal, 20)
                        .position(x: proxy.frame(in: .global).midX, y: proxy.frame(in: .global).midY)
                }
            }
            .overlay {
                GeometryReader { proxy in
                    ContainerRelativeShape()
                        .inset(by: 2)
                        .stroke(lineWidth: 4)
                        .foregroundStyle(Color.black)
                        .frame(height: proxy.size.width - 20)
                        .padding(.horizontal, 20)
                        .position(x: proxy.frame(in: .global).midX, y: proxy.frame(in: .global).midY)
                }
            }
            .containerShape(.rect(cornerRadius: 50))
            .ignoresSafeArea(.all)
    }
    
    func searchResults(for component: String) async -> [GoogleSearchResult] {
        let tutorialQuery = "\(component) tutorials"
        let blogQuery = "\(component) blogs and articles"
        let docQuery = "\(component) official datasheet"
        
        return await withTaskGroup(of: [GoogleSearchResult].self, returning: [GoogleSearchResult].self) { group in
            
            group.addTask {
                let stream = await self.engines[0].results(for: tutorialQuery)
                var results: [GoogleSearchResult] = []
                
                do {
                    for try await delta in stream {
                        results = delta
                    }
                } catch {
                    return []
                }
                
                return results
            }
            
            group.addTask {
                let stream = await self.engines[1].results(for: blogQuery)
                var results: [GoogleSearchResult] = []
                
                do {
                    for try await delta in stream {
                        results = delta
                    }
                } catch {
                    return []
                }
                
                return results
            }
            
            group.addTask {
                let stream = await self.engines[2].results(for: docQuery)
                var results: [GoogleSearchResult] = []
                
                do {
                    for try await delta in stream {
                        results = delta
                    }
                } catch {
                    return []
                }
                
                return results
            }
            
            var results: [GoogleSearchResult] = []
            let all = await group.collect()
            for item in all {
                results += item
            }
            
            return results
        }
    }
    
    func processImage(proxy: CameraViewProxy) {
        Task(priority: .high) {
            do {
                let image: AppKitOrUIKitImage = try await proxy.capturePhoto()
                
                isDetecting = true
                print("searching")
                
                let result = try await searchEngine.imageSearchResults(for: image)
                
                print("got image search results")
                
                guard let componentName = await llm.identifyComponent(from: result) else { return }
                self.componentName = componentName
                let results = await searchResults(for: componentName)
                
                let links = await llm.pickLinks(from: results)
                print(links)
                
                self.component = Component(name: componentName, links: links)
                isDetecting = false
            } catch {
                print(error)
            }
        }
    }
}

struct Component: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var links: [LLM.Link]
}

#Preview {
    ContentView()
}

extension Color {
    // Initialize Color with a hexadecimal string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex)
        
        if hex.hasPrefix("#") {
            scanner.currentIndex = hex.index(after: hex.startIndex)
        }
        
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    static var pokedex = Color(hex: "#BB0F1D")
}
