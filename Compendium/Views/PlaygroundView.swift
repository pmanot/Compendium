//
//  PlaygroundView.swift
//  Compendium
//
//  Created by Purav Manot on 13/07/24.
//

import SwiftUI
import OpenAI
import Media

struct PlaygroundView: View {
    @State var llm = LLM()

    @State private var timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    @State private var image: Image = Image(systemName: .rectangleStack)
    @State private var text: String = "[waiting...]"
    
    @State private var task: Task<Void, Error>? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                CameraViewReader { proxy in
                    CameraView()
                        .onReceive(timer) { date in
                            guard self.task.isNil else { print("waiting"); return }
                            
                            self.task = Task { @MainActor in
                                let image = try await proxy.capturePhoto()
                                self.image = Image(image)
                                self.task = nil
                            }
                        }
                    
                    Button("Capture") {
                        Task {
                            let image = try await proxy.capturePhoto()
                            self.image = Image(image)
                        }
                    }
                }
                
                Text(text)
            }
        }
    }
}

#Preview {
    PlaygroundView()
}
