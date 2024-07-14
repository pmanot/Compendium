//
//  ComponentDetailView.swift
//  Compendium
//
//  Created by Purav Manot on 14/07/24.
//

import SwiftUIX
import Browser

struct ComponentDetailView: View {
    @State private var llm = LLM()
    @State private var searchEngine = SearchEngine()
    var component: Component // Injected component
    
    var groupedLinks: [String: [LLM.Link]] {
        Dictionary(grouping: component.links, by: { $0.type })
    }
    
    var body: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        
        ScrollView {
            VStack {
                ForEach(groupedLinks.keys.sorted(), id: \.self) { key in
                    Text(key)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.monospaced)
                        .padding()
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(groupedLinks[key] ?? [], id: \.url) { link in
                            VStack {
                                Text(link.type)
                                    .font(.headline)
                                    .fontDesign(.monospaced)
                                    .padding(5)
                                
                                LinkPresentationView(url: link.url)
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary)
                                    .frame(height: 150)
                                    .padding(5)
                            }
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 15).stroke(lineWidth: 1))
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            print("COMPONENT LINKS: \(component.links)")
        }
    }
}

/*
#Preview {
    NavigationStack {
        ComponentDetailView()
    }
}
*/
