//
//  ContentView.swift
//  Melodraw
//
//  Created by sami chougle on 07/01/25.
//

import AVFoundation
import SwiftUI

var soundPlayer: AVAudioPlayer?

func configureAudioSession() {
    let audioSession = AVAudioSession.sharedInstance()
    do {
        try audioSession.setCategory(.playback, mode: .default, options: [])
        try audioSession.setActive(true)
        print("Audio session configured successfully.")
    } catch {
        print("Failed to configure audio session: \(error.localizedDescription)")
    }
}

func playSound(for color: Color) {
    var soundName: String
    switch color {
    case .red:
        soundName = "drumNote"
    case .blue:
        soundName = "painoNote"
    case .green:
        soundName = "harpNote"
    case .yellow:
        soundName = "guitarNote"
    case .orange:
        soundName = "violinNote"
    case .purple:
        soundName = "electric-guitarNote"
    case .pink:
        soundName = "fluteNote"
    case .brown:
        soundName = "clarinetNote"
    default:
        soundName = "accordionNote"
    }

    if let path = Bundle.main.path(forResource: soundName, ofType: "mp3") {
        let url = URL(fileURLWithPath: path)
        do {
            soundPlayer = try AVAudioPlayer(contentsOf: url)
            soundPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    } else {
        print("Sound file not found: \(soundName).mp3")
    }
}

struct Line {
    let id = UUID()
    var color: Color
    var points: [CGPoint]
    var isComplete = false
}

extension Color {
    static func random() -> Color {
        let randomValue = Double.random(in: 0...1)
        switch randomValue {
        case 0..<0.125: return .red
        case 0.125..<0.25: return .blue
        case 0.25..<0.375: return .green
        case 0.375..<0.5: return .yellow
        case 0.5..<0.625: return .orange
        case 0.625..<0.75: return .purple
        case 0.75..<0.875: return .pink
        case 0.875...1: return .brown
        default: return .black
        }
    }
}

struct ContentView: View {
    @State private var lines: [Line] = []
    @State private var undoneLines: [Line] = []
    @State private var showResetButton = false
    @State private var isDrawing = false
    @State private var canvasImage: UIImage?
    @State private var showShareSheet = false

    init() {
        configureAudioSession()
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)

                ForEach(lines, id: \.id) { line in
                    Path { path in
                        for point in line.points {
                            if point == line.points.first {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(
                        line.color.opacity(0.9),
                        style: StrokeStyle(
                            lineWidth: 12,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .blur(radius: 1)
                    .shadow(color: line.color.opacity(0.6), radius: 4, x: 2, y: 2)
                }

                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            undoLastLine()
                        }) {
                            Text("Undo")
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .shadow(radius: 3)
                        }
                        .disabled(lines.isEmpty)
                        .padding(.leading, 20)

                        Spacer()

                        if showResetButton {
                            Button(action: {
                                lines.removeAll()
                                undoneLines.removeAll()
                                showResetButton = false
                            }) {
                                Text("Clear Canvas")
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }

                        Spacer()

                        Button(action: {
                            redoLastLine()
                        }) {
                            Text("Redo")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(undoneLines.isEmpty)
                        .padding(.trailing, 20)
                    }
                    .padding(.bottom, 20)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newPoint = value.location
                        if !isDrawing {
                            isDrawing = true

                            if lines.isEmpty {
                                showResetButton = true
                            }
                        }

                        if lines.isEmpty || lines.last!.isComplete {
                            let newColor = Color.random()
                            let newLine = Line(color: newColor, points: [newPoint])
                            lines.append(newLine)
                            playSound(for: newColor)
                        } else {
                            lines[lines.count - 1].points.append(newPoint)
                        }
                    }
                    .onEnded { _ in
                        lines[lines.count - 1].isComplete = true
                        isDrawing = false
                    }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await shareCanvas()
                        }
                    }) {
                        Image(systemName: "arrowshape.turn.up.right")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = canvasImage {
                    ShareSheet(activityItems: [image])
                }
            }
        }
    }

    private func undoLastLine() {
        guard let lastLine = lines.popLast() else { return }
        undoneLines.append(lastLine)
    }

    private func redoLastLine() {
        guard let lastUndoneLine = undoneLines.popLast() else { return }
        lines.append(lastUndoneLine)
    }

    @MainActor
    private func shareCanvas() async {
        let canvasView = ZStack {
            Color.white.edgesIgnoringSafeArea(.all)

            ForEach(lines, id: \.id) { line in
                Path { path in
                    for point in line.points {
                        if point == line.points.first {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(
                    line.color.opacity(0.9),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                )
            }
        }

        let renderer = ImageRenderer(content: canvasView)
        if let image = renderer.uiImage {
            self.canvasImage = image
            self.showShareSheet = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
