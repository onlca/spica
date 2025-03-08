import SwiftUI


struct ContentView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @State private var showFileImporter = false
    
    var body: some View {
        NavigationSplitView {
            PlaylistView(viewModel: viewModel, showFileImporter: $showFileImporter)
        } detail: {
            PlayerDetailView(viewModel: viewModel)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result: result)
        }
        .alert("发生错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            viewModel.addSongs(urls)
        } catch {
            viewModel.errorMessage = "文件导入失败: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
