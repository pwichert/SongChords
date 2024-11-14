//
//  FileExport.swift
//  SongChords
//
//  Created by Peter Wichert on 14.11.24.
//

import SwiftUI
import UniformTypeIdentifiers

// Export ChordPro als .txt
//struct TextFile: FileDocument {
//    static var readableContentTypes: [UTType] { [.plainText] }
//    var song: Song
//    
//    init(song: Song) {
//        self.song = song
//    }
//    
//    init(configuration: ReadConfiguration) throws {
//        if let data = configuration.file.regularFileContents,
//           let string = String(data: data, encoding: .utf8) {
//            song = Song(title: "")
//            song.srcText = string
//        } else {
//            throw CocoaError(.fileReadCorruptFile)
//        }
//    }
//    
//    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
//        let data = song.songToData()
//        return FileWrapper(regularFileWithContents: data)
//    }
//}

#if os(macOS)
//import AppKit
//
//struct DirectoryPickerView: NSViewControllerRepresentable {
////    @Binding var selectedDirectory: URL?
//
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(self)
//    }
//
//    func makeNSViewController(context: Context) -> NSViewController {
//        let viewController = NSViewController()
//        DispatchQueue.main.async {
//            let panel = NSOpenPanel()
//            panel.canChooseFiles = false
//            panel.canChooseDirectories = true
//            panel.allowsMultipleSelection = false
//            if panel.runModal() == .OK {
////                self.selectedDirectory = panel.url
//                print(panel.url ?? "")
//            }
//        }
//        return viewController
//    }
//
//    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
//
//    class Coordinator: NSObject {
//        var parent: DirectoryPickerView
//        init(_ parent: DirectoryPickerView) {
//            self.parent = parent
//        }
//    }
//}

//struct ContentView: View {
//    @State private var selectedDirectory: URL?
//
//    var body: some View {
//        VStack {
//            Button("Verzeichnis auswählen") {
//                selectedDirectory = nil
//            }
//            .background(DirectoryPicker(selectedDirectory: $selectedDirectory))
//            
//            if let selectedDirectory = selectedDirectory {
//                Text("Ausgewähltes Verzeichnis: \(selectedDirectory.path)")
//            } else {
//                Text("Kein Verzeichnis ausgewählt")
//            }
//        }
//        .frame(width: 400, height: 200)
//    }
//}
#else
struct DirectoryPickerView: UIViewControllerRepresentable {
    var pickerDelegate: DirectoryPickerDelegate
    
    init(playlist: PlayList) {
        self.pickerDelegate = DirectoryPickerDelegate(playlist: playlist)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        controller.delegate = pickerDelegate
        controller.allowsMultipleSelection = false
        return controller
    }
    
    func updateUIViewController(_ uiView: UIDocumentPickerViewController, context: Context) { }
}

class DirectoryPickerDelegate: NSObject, UIDocumentPickerDelegate {
    var playlist: PlayList

    init(playlist: PlayList) {
        self.playlist = playlist
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            let startSecurityScope = url.startAccessingSecurityScopedResource()

            print(url.absoluteString)
            
            do {
                var cnt = 0
                for song in playlist.songs ?? [] {
                    cnt += 1
                    let data = song.songToData()
                    let filename = song.title.count > 0 ? song.title : "title " + String(cnt)
                    var fileurl = url.appending(component: filename)
                    fileurl.appendPathExtension(for: .plainText)
                    
                    try data.write(to: fileurl, options: Data.WritingOptions.withoutOverwriting)
                }
            } catch {
                print("Error exporting Playlist: \(error.localizedDescription)")
                alertMessage(title: "Aborted", message: error.localizedDescription)
            }
            
            if startSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    func alertMessage(title: String, message: String) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
        }
        alertVC.addAction(okAction)
        
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first
                  as? UIWindowScene)?.windows.first?.rootViewController
              else {return}
        
        presentingViewController.present(alertVC, animated: true, completion: {})
    }
}

//struct ContentView: View {
//    @State private var selectedDirectory: URL?
//
//    var body: some View {
//        VStack {
//            Button("Verzeichnis auswählen") {
//                selectedDirectory = nil
//            }
//            .background(DirectoryPicker(selectedDirectory: $selectedDirectory))
//
//            if let selectedDirectory = selectedDirectory {
//                Text("Ausgewähltes Verzeichnis: \(selectedDirectory.path)")
//            } else {
//                Text("Kein Verzeichnis ausgewählt")
//            }
//        }
//        .frame(width: 400, height: 200)
//    }
//}
#endif
