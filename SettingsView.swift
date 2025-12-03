import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var showAddKeySheet = false
    @State private var newKeyStr = ""
    @State private var newKeyLabel = ""
    @AppStorage("customHost") var customHost: String = "https://gemini.yamadaryo.me"
    
    var body: some View {
        List {
            Section(header: Text("API Keys")) {
                if viewModel.savedKeys.isEmpty {
                    Text("请添加 Key").foregroundColor(.red)
                }
                ForEach(viewModel.savedKeys) { key in
                    Button {
                        viewModel.selectKey(id: key.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(key.label).font(.headline).foregroundColor(.white)
                                Text(key.key.prefix(8) + "......").font(.caption2).foregroundColor(.gray)
                            }
                            Spacer()
                            if viewModel.currentKeyId == key.id {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            }
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteKey)
                
                Button { showAddKeySheet = true } label: {
                    Label("添加新 Key", systemImage: "plus").foregroundColor(.blue)
                }
            }
            
            Section(header: Text("模型")) {
                ForEach(viewModel.savedModels) { model in
                    Button { viewModel.selectedModelId = model.id } label: {
                        HStack {
                            Text(model.shortName)
                                .fontWeight(viewModel.selectedModelId == model.id ? .bold : .regular)
                            Spacer()
                            if viewModel.selectedModelId == model.id {
                                Image(systemName: "checkmark").foregroundColor(.green).font(.caption)
                            }
                        }
                    }
                }
                NavigationLink { OnlineModelListView(viewModel: viewModel) } label: {
                    Text("获取更多模型...").font(.caption).foregroundColor(.gray)
                }
            }
            
            Section {
                TextField("代理 Host", text: $customHost).font(.caption)
                Button("清空当前对话", role: .destructive) {
                    viewModel.clearCurrentChat()
                }
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showAddKeySheet) {
            VStack(spacing: 15) {
                Text("添加 API Key").font(.headline)
                TextField("备注", text: $newKeyLabel).padding().background(Color.gray.opacity(0.2)).cornerRadius(8)
                TextField("Key (AIzaSy...)", text: $newKeyStr).padding().background(Color.gray.opacity(0.2)).cornerRadius(8)
                Button("保存") {
                    if !newKeyStr.isEmpty {
                        let label = newKeyLabel.isEmpty ? "Key \(viewModel.savedKeys.count + 1)" : newKeyLabel
                        viewModel.addKey(key: newKeyStr, label: label)
                        newKeyLabel = ""
                        newKeyStr = ""
                        showAddKeySheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
}

struct OnlineModelListView: View {
    @ObservedObject var viewModel: ChatViewModel
    var body: some View {
        List {
            Button("刷新列表") { Task { await viewModel.fetchOnlineModels() } }
            if viewModel.availableModels.isEmpty { Text("暂无数据，请刷新").font(.caption).foregroundColor(.gray) }
            ForEach(viewModel.availableModels) { model in
                HStack {
                    Text(model.shortName).font(.caption)
                    Spacer()
                    if !viewModel.savedModels.contains(where: { $0.id == model.id }) {
                        Button { viewModel.addToFavorites(model: model) } label: {
                            Image(systemName: "plus.circle")
                        }.buttonStyle(.plain)
                    } else {
                        Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                    }
                }
            }
        }
    }
}
