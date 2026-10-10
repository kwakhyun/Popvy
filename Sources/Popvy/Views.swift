import AppKit
import SwiftUI

private let accent = Color.accentColor

struct HistoryView: View {
    @ObservedObject var app: AppController
    @ObservedObject var store: HistoryStore
    @ObservedObject var monitor: ClipboardMonitor
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if app.isSearchVisible { search }
            if monitor.clipboardAccessDenied {
                message("클립보드 읽기가 차단되어 있습니다. 시스템 설정에서 허용해 주세요.")
            } else if let notice = app.notice ?? store.persistenceError {
                message(notice)
            }
            if app.visibleEntries.isEmpty { emptyState }
            else { entryList }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.12)))
        .tint(accent)
        .onReceive(NotificationCenter.default.publisher(for: .focusPopvySearch)) { _ in searchFocused = true }
        .onChange(of: app.isSearchVisible) { searchFocused = $0 }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Popvy").accessibilityLabel("팝비 클립보드").font(.system(size: 14, weight: .semibold))
            Spacer()
            Button { app.toggleSearch() } label: {
                Image(systemName: "magnifyingglass").frame(width: 24, height: 26)
            }.buttonStyle(.plain).help("검색 (⌘ F)").accessibilityLabel("검색")
            Menu {
                Button("모든 기록") { app.filter = .all }
                Button("고정한 기록") { app.filter = .pinned }
                Divider()
                Button(monitor.isPaused ? "기록 다시 시작" : "기록 일시 정지") { app.togglePause() }
                Button("고정하지 않은 기록 삭제…") { app.confirmClear(includingPinned: false) }
                Divider()
                Button("설정…") { app.openSettings() }
                Button("Popvy 종료") { NSApp.terminate(nil) }
            } label: { Image(systemName: "ellipsis").frame(width: 24, height: 26) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel("기록 관리")
            Button { app.hidePanel(restoreFocus: true) } label: {
                Image(systemName: "xmark").font(.system(size: 11)).frame(width: 22, height: 26)
            }.buttonStyle(.plain).help("닫기 (Esc)").accessibilityLabel("닫기")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12).frame(height: 44)
    }

    private var search: some View {
        HStack(spacing: 6) {
            TextField("기록 검색", text: $app.query)
                .textFieldStyle(.plain).font(.system(size: 12)).focused($searchFocused)
                .accessibilityLabel("기록 검색")
            if !app.query.isEmpty {
                Button { app.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 10).frame(height: 32)
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 10).padding(.bottom, 10)
        .onAppear { searchFocused = true }
    }

    private func message(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
            Text(text).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            if app.notice != nil {
                Button { app.notice = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("안내 닫기")
            }
        }.font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).frame(height: 56)
    }

    private var entryList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(app.visibleEntries) { entry in
                        CompactEntryRow(entry: entry, selected: app.selectedID == entry.id,
                            use: { app.use(entry) }, copy: { app.use(entry, copyOnly: true) },
                            plainText: { app.use(entry, plainText: true) },
                            pin: { app.pin(entry) }, remove: { store.remove(entry.id) })
                            .id(entry.id)
                    }
                }.padding(.horizontal, 8).padding(.vertical, 8)
            }
            .onChange(of: app.selectedID) { id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: app.query.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 24, weight: .light)).foregroundStyle(.tertiary)
            Text(emptyLabel).font(.system(size: 12)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyLabel: String {
        if !app.query.isEmpty { return "일치하는 기록이 없습니다" }
        if monitor.isPaused { return "기록이 일시 정지되어 있습니다" }
        if app.filter == .pinned { return "고정한 기록이 없습니다" }
        return "복사한 내용이 여기에 표시됩니다"
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if app.showCopied {
                Label("복사했습니다. ⌘ V로 붙여넣기", systemImage: "checkmark")
                    .foregroundStyle(accent)
            } else {
                Text(app.canAutoPaste ? "클릭 또는 ↩로 붙여넣기" : "선택 후 ⌘ V로 붙여넣기")
                Spacer(minLength: 0)
                if !app.accessibilityGranted && app.autoPaste {
                    Button("바로 붙여넣기 허용") { app.requestAccessibility() }.buttonStyle(.link)
                } else if monitor.isPaused {
                    Image(systemName: "pause.fill").help("기록 일시 정지 중")
                } else {
                    Text("esc 닫기").foregroundStyle(.tertiary)
                }
            }
        }.font(.system(size: 10)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).frame(height: 30)
    }
}

private struct CompactEntryRow: View {
    let entry: ClipboardEntry
    let selected: Bool
    let use: () -> Void
    let copy: () -> Void
    let plainText: () -> Void
    let pin: () -> Void
    let remove: () -> Void
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // The entire card is a single paste target, including its padding and whitespace.
            Button(action: use) {
                HStack(alignment: .top, spacing: 6) {
                    if let image = entry.image {
                        Image(nsImage: image).resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 52, alignment: .leading)
                    } else {
                        Text(entry.text).font(.system(size: 13)).lineLimit(3).lineSpacing(2)
                            .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    if entry.isPinned {
                        Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 12).padding(.trailing, 34).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isImage ? "이미지 붙여넣기" : "붙여넣기: \(entry.preview)")
            Menu {
                Button(entry.isPinned ? "고정 해제" : "고정", action: pin)
                Button("복사만 하기", action: copy)
                if !entry.isImage { Button("서식 없이 붙여넣기", action: plainText) }
                Divider()
                Button("삭제", role: .destructive, action: remove)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 12))
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .foregroundStyle(.secondary).padding(5).accessibilityLabel("항목 관리")
        }
        .frame(height: PopupPlacement.rowHeight)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected || hovering ? accent.opacity(0.65) : .primary.opacity(0.08)))
        .onHover { hovering = $0 }
        .contextMenu {
            Button("붙여넣기", action: use)
            Button(entry.isPinned ? "고정 해제" : "고정", action: pin)
            Button("복사만 하기", action: copy)
            Button("삭제", role: .destructive, action: remove)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SettingsView: View {
    @ObservedObject var app: AppController
    @ObservedObject var store: HistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(systemName: "square.on.square").font(.system(size: 26, weight: .medium)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("내 Mac에 맞게").font(.system(size: 21, weight: .bold))
                    Text("Popvy(팝비) 설정").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("기록 창 단축키")
                    Spacer()
                    Picker("기록 창 단축키", selection: Binding(get: { app.shortcut }, set: { app.changeShortcut($0) })) {
                        ForEach(Shortcut.allCases) { shortcut in Text(shortcut.title).tag(shortcut) }
                    }.labelsHidden().frame(width: 205)
                }
                Toggle("로그인할 때 자동 실행", isOn: Binding(get: { app.launchAtLogin }, set: { app.setLaunchAtLogin($0) }))
                Divider()
                Toggle("선택한 항목 바로 붙여넣기", isOn: $app.autoPaste)
                HStack(spacing: 7) {
                    Image(systemName: app.accessibilityGranted ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(app.accessibilityGranted ? .green : .secondary)
                    Text(app.accessibilityGranted ? "손쉬운 사용 권한이 허용되어 있습니다." : "권한이 없으면 복사 후 ⌘ V로 붙여넣습니다.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if !app.accessibilityGranted { Button("권한 설정") { app.requestAccessibility() }.font(.system(size: 11)) }
                }
                Divider()
                Toggle("앱을 종료해도 기록 보관", isOn: $app.keepHistory)
                Text("최근 100개, 최대 50 MB를 이 Mac에 저장합니다. 고정은 최대 20개입니다. 끄면 디스크의 기록을 지우고 실행 중에만 보관합니다.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(4)
            }.font(.system(size: 13)).padding(18)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 8) {
                Label("내 기기에서만 보관", systemImage: "lock.shield").font(.system(size: 12, weight: .semibold))
                Text("네트워크 전송 없이 텍스트와 이미지만 보관합니다. 비밀번호 앱이 민감한 내용으로 표시한 항목은 제외합니다. 일반 텍스트로 복사한 비밀번호는 구분할 수 없으니, 민감한 작업 전에는 기록을 잠시 멈춰 주세요.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
            if let notice = app.notice ?? store.persistenceError {
                Text(notice).font(.system(size: 11)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("모든 기록 삭제…", role: .destructive) { app.confirmClear(includingPinned: true) }
                Spacer()
                Text("Popvy 1.3.0").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }.padding(28).frame(width: 510).fixedSize(horizontal: false, vertical: true).tint(accent)
    }
}
