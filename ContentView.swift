import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var packages: [TweakPackage] = []
    @State private var selected = Set<String>()
    @State private var search = ""
    @State private var includeSources = true
    @State private var includePreferences = true
    @State private var status = "Đang quét package..."
    @State private var isBusy = false
    @State private var backupFolder: URL?
    @State private var showImporter = false
    @State private var importedManifest: BackupManifest?
    @State private var restoreSelected = Set<String>()

    private var filtered: [TweakPackage] {
        guard !search.isEmpty else { return packages }
        return packages.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.package.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header
                HStack {
                    Button(action: scan) {
                        Label("Quét iPhone", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                    Button { showImporter = true } label: {
                        Label("Mở backup", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered)
                }

                if let manifest = importedManifest {
                    restoreView(manifest)
                } else {
                    packageView
                }

                Text(status).font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Dopamine Tweak Manager")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.folder],
                          allowsMultipleSelection: false, onCompletion: handleImport)
            .onAppear(perform: scan)
        }
        .tint(.cyan)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill").font(.system(size: 30)).foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 3) {
                Text("Dopamine Tweak Manager").font(.headline)
                Text("Rootless • Sileo • TrollStore").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("BETA").font(.caption2.bold()).padding(7)
                .background(.orange.opacity(0.2)).clipShape(Capsule())
        }
    }

    private var packageView: some View {
        VStack(spacing: 9) {
            HStack {
                Text("Danh sách package").font(.headline)
                Spacer()
                Text("\(selected.count)/\(packages.count) chọn").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Chọn tất cả") { selected = Set(filtered.map(\.package)) }
                Button("Bỏ chọn") { selected.removeAll() }
                Spacer()
            }.font(.caption)
            TextField("Tìm tên tweak hoặc Package ID", text: $search)
                .textFieldStyle(.roundedBorder)
            Toggle("Sao lưu repo Sileo", isOn: $includeSources)
            Toggle("Sao lưu plist Preferences", isOn: $includePreferences)

            List {
                ForEach(filtered) { item in
                    Button {
                        if selected.contains(item.package) { selected.remove(item.package) }
                        else { selected.insert(item.package) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selected.contains(item.package) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(item.package) ? .cyan : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).foregroundStyle(.primary)
                                Text("\(item.package) • \(item.version)")
                                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 230)

            Button(action: createBackup) {
                if isBusy { ProgressView().frame(maxWidth: .infinity) }
                else {
                    Label("Tạo backup \(selected.count) package", systemImage: "archivebox")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty || isBusy)

            if let folder = backupFolder {
                ShareLink(item: folder) {
                    Label("Chia sẻ thư mục backup", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
            }
        }
    }

    private func restoreView(_ manifest: BackupManifest) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Backup đã chọn").font(.headline)
                Spacer()
                Button("Đóng") { importedManifest = nil }
            }
            Text("\(manifest.jailbreak) • \(manifest.deviceOS)")
                .font(.caption).foregroundStyle(.secondary)
            Text("Chọn package muốn phục hồi. Bản beta chỉ đọc danh sách, chưa tự cài package.")
                .font(.footnote)
            List(manifest.packages) { item in
                Button {
                    if restoreSelected.contains(item.package) { restoreSelected.remove(item.package) }
                    else { restoreSelected.insert(item.package) }
                } label: {
                    HStack {
                        Image(systemName: restoreSelected.contains(item.package) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(.cyan)
                        VStack(alignment: .leading) {
                            Text(item.name).foregroundStyle(.primary)
                            Text("\(item.package) • \(item.version)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }.listRowBackground(Color.white.opacity(0.04))
            }
            .listStyle(.plain)
            .frame(minHeight: 250)
            Button {
                status = "Đã chọn \(restoreSelected.count) package. Hãy đối chiếu phiên bản và cài lại qua Sileo."
            } label: {
                Label("Xác nhận \(restoreSelected.count) package", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent)
        }
    }

    private func scan() {
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try RootlessStore.shared.loadPackages()
                DispatchQueue.main.async {
                    packages = result
                    selected = Set(result.map(\.package))
                    status = "Đã đọc \(result.count) package."
                    isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Quét thất bại: \(error.localizedDescription)"
                    isBusy = false
                }
            }
        }
    }

    private func createBackup() {
        let chosen = packages.filter { selected.contains($0.package) }
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let folder = try RootlessStore.shared.makeBackup(
                    selected: chosen,
                    includeSources: includeSources,
                    includePreferences: includePreferences
                )
                DispatchQueue.main.async {
                    backupFolder = folder
                    status = "Đã tạo thư mục backup tạm. Dùng nút Chia sẻ để lưu vào Files."
                    isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Backup lỗi: \(error.localizedDescription)"
                    isBusy = false
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let folder = try result.get().first else { return }
            let access = folder.startAccessingSecurityScopedResource()
            defer { if access { folder.stopAccessingSecurityScopedResource() } }
            let manifest = try RootlessStore.shared.readManifest(folder: folder)
            importedManifest = manifest
            restoreSelected = Set(manifest.packages.map(\.package))
            status = "Đã đọc backup gồm \(manifest.packages.count) package."
        } catch {
            status = "Không mở được backup: \(error.localizedDescription)"
        }
    }
}
