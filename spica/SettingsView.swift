import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var settings = SettingsModel.shared
    @State private var tempPythonPath: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = "general"
    @State private var showFileChooser = false
    
    var body: some View {
        VStack(spacing: 0) {
            // macOS风格标签栏
            TabView(selection: $selectedTab) {
                generalSettingsView
                    .tabItem {
                        Label("通用", systemImage: "gear")
                    }
                    .tag("general")
                
                pythonSettingsView
                    .tabItem {
                        Label("Python", systemImage: "terminal")
                    }
                    .tag("python")
            }
            .padding()
            
            // 底部按钮区
            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("保存") {
                    settings.pythonExecutablePath = tempPythonPath
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 300)
        .onAppear {
            tempPythonPath = settings.pythonExecutablePath
        }
        .fileImporter(
            isPresented: $showFileChooser,
            allowedContentTypes: [UTType.executable],
            allowsMultipleSelection: false
        ) { result in
            do {
                let selectedFile = try result.get().first
                if let selectedFile = selectedFile {
                    if selectedFile.startAccessingSecurityScopedResource() {
                        tempPythonPath = selectedFile.path
                        selectedFile.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                alertMessage = "选择Python可执行文件出错: \(error.localizedDescription)"
                showingAlert = true
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Python 路径"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
        }
    }
    
    // 通用设置视图
    private var generalSettingsView: some View {
        VStack(alignment: .leading) {
            Text("通用设置")
                .font(.title2)
                .padding(.bottom, 10)
            
            Text("此页面将来会添加应用程序的通用设置选项。")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Python设置视图
    private var pythonSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Python 设置")
                .font(.title2)
                .padding(.bottom, 10)
            
            Text("设置用于解析音频标签的Python解释器路径")
                .foregroundColor(.secondary)
                .padding(.bottom, 10)
            
            HStack {
                Text("Python 路径:")
                TextField("输入Python可执行文件路径", text: $tempPythonPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: {
                    showFileChooser = true
                }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("浏览并选择Python可执行文件")
            }
            
            HStack {
                Button("测试路径") {
                    testPythonPath()
                }
                .buttonStyle(.bordered)
                
                Button("恢复默认") {
                    tempPythonPath = "/usr/bin/python3"
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func testPythonPath() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tempPythonPath)
        process.arguments = ["--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                alertMessage = "Python路径有效: \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
            } else {
                alertMessage = "Python路径无效：执行失败"
            }
        } catch {
            alertMessage = "Python路径无效：\(error.localizedDescription)"
        }
        showingAlert = true
    }
}
