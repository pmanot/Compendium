//
//  ItemCollectionView.swift
//  Compendium
//
//  Created by Purav Manot on 17/07/24.
//

import SwiftUI

struct ItemCollectionView: View {
    @State private var columns: Double = 4
    @State private var rows: Double = 4
    
    var body: some View {
        ScrollView {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(Array([Int](repeating: 1, count: Int(rows)).enumerated()), id: \.offset) { x, _ in
                    GridRow {
                        ForEach(Array([Int](repeating: 1, count: Int(columns)).enumerated()), id: \.offset) { y, _ in
                            ItemView()
                                .id("\(x)\(y))")
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .animation(.bouncy, value: rows)
        .animation(.bouncy, value: columns)
        .safeAreaInset(edge: .top) {
            GroupBox {
                Slider(value: $rows, in: 1...3, step: 1)
                Slider(value: $columns, in: 1...5, step: 1)
            }
        }
    }
    
    struct Item {
        var title: String
        var description: String
        
        static let example: Self = .init(title: "ESP32C3", description: "A small microcontroller by seeed studio")
    }
    
    struct ItemView: View {
        let item: Item = .example
        var body: some View {
            GroupBox {
                Text(item.title)
                    .fontDesign(.rounded)
                    .font(.headline)
                    .minimumScaleFactor(0.4)

                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.8))
                    .minimumScaleFactor(0.6)
                    .lineLimit(3)
            }
            .contentTransition(.numericText(countsDown: true))
        }
    }
}

#Preview {
    ItemCollectionView()
}
