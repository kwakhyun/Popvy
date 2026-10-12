import AppKit
import SwiftUI

struct PermissionSetupView: View {
    @ObservedObject var app: AppController
    @ObservedObject var setup: AccessibilitySetup
    @State private var showsHelp = false

    /// 0: open settings, 1: waiting for the switch, 2: ready to use.
    private var phase: Int { setup.isTrusted ? 2 : (setup.isWaiting ? 1 : 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            steps
            if !setup.isTrusted {
                Label("이 권한은 입력 위치를 찾고 붙여넣기(⌘ V)를 보내는 데만 사용합니다. 언제든 시스템 설정에서 끌 수 있어요.",
                      systemImage: "lock.shield")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                troubleshooting
            }
            if let error = app.accessibilitySetupError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            footer
        }
        .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 24)
        .frame(width: 490).fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.25), value: phase)
        .animation(.easeInOut(duration: 0.2), value: showsHelp)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 56, height: 56)
                    .overlay(alignment: .bottomTrailing) {
                        if setup.isTrusted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white, .green)
                                .offset(x: 4, y: 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Popvy · 팝비").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Text(setup.isTrusted ? "바로 붙여넣을 준비가 됐어요" : "한 번 클릭으로 바로 붙여넣기")
                        .font(.system(size: 22, weight: .bold))
                }
            }
            Text(setup.isTrusted
                 ? "권한을 확인했어요. 이제 복사한 내용을 커서 옆에서 바로 꺼내 쓸 수 있습니다."
                 : "선택한 기록을 입력하던 앱에 바로 붙여넣으려면 macOS의 ‘손쉬운 사용’ 권한이 필요해요.")
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 4) {
            SetupStep(number: 1, state: state(of: 0), title: "시스템 설정 열기",
                      detail: "아래 버튼을 누르면 개인정보 보호 및 보안 → 손쉬운 사용으로 이동합니다.")
            SetupStep(number: 2, state: state(of: 1), title: "Popvy 스위치 켜기",
                      detail: "macOS가 요청하면 Touch ID 또는 Mac 로그인 암호로 인증하세요.") {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("허용을 기다리는 중… 켜면 자동으로 감지해요.")
                }
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 4)
            }
            SetupStep(number: 3, state: state(of: 2), title: "\(app.shortcut.title)로 꺼내 쓰기",
                      detail: "복사한 뒤 입력할 곳에서 단축키를 누르고, 항목을 클릭하면 바로 붙여넣어요.") {
                HStack(spacing: 6) {
                    ForEach(app.shortcut.label.split(separator: " ").map(String.init), id: \.self) { key in
                        Keycap(key: key)
                    }
                    Text("시작하기를 누른 뒤 입력할 곳에서 눌러 보세요")
                        .font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 4)
                }
                .padding(.top, 6)
            }
        }
        .padding(6)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private var troubleshooting: some View {
        DisclosureGroup(isExpanded: $showsHelp) {
            VStack(alignment: .leading, spacing: 6) {
                Text("• 목록에 없다면 + 버튼을 눌러 응용 프로그램 폴더의 Popvy.app을 추가하세요.")
                Text("• 이미 켜져 있는데도 감지되지 않으면, 목록에서 Popvy를 선택해 − 버튼으로 제거한 뒤 다시 추가하세요.")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        } label: {
            Text("Popvy가 목록에 없거나, 켜도 감지되지 않나요?")
                .font(.system(size: 12))
                .contentShape(Rectangle())
                .onTapGesture { showsHelp.toggle() }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if setup.isTrusted {
                    Label(app.canAutoPaste ? "자동 붙여넣기가 켜졌어요" : "시작하면 자동 붙여넣기가 켜져요",
                          systemImage: "checkmark.shield.fill")
                        .font(.system(size: 12)).foregroundStyle(.green)
                } else {
                    Button("나중에 하기") { app.finishAccessibilitySetup() }
                        .controlSize(.large).keyboardShortcut(.cancelAction)
                }
                Spacer()
                Button(primaryTitle) {
                    if setup.isTrusted { app.finishAccessibilitySetup() }
                    else { app.openAccessibilitySettings() }
                }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
            if !setup.isTrusted {
                Text("나중에 허용해도 괜찮아요. 기록을 고른 뒤 ⌘ V로 직접 붙여넣을 수 있고, 설정에서 언제든 다시 열 수 있어요.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var primaryTitle: String {
        switch phase {
        case 2: return "Popvy 시작하기"
        case 1: return "설정 다시 열기"
        default: return "시스템 설정 열기"
        }
    }

    private func state(of step: Int) -> StepState {
        step < phase ? .done : (step == phase ? .current : .upcoming)
    }
}

private enum StepState { case done, current, upcoming }

private struct SetupStep<Accessory: View>: View {
    let number: Int
    let state: StepState
    let title: String
    let detail: String
    let accessory: Accessory

    init(number: Int, state: StepState, title: String, detail: String,
         @ViewBuilder accessory: () -> Accessory) {
        self.number = number
        self.state = state
        self.title = title
        self.detail = detail
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            badge
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(state == .upcoming ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
                if state != .done {
                    Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if state == .current { accessory }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(state == .current ? Color.accentColor.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number)단계, \(title), \(stateDescription)")
    }

    private var badge: some View {
        ZStack {
            switch state {
            case .done:
                Circle().fill(Color.green)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            case .current:
                Circle().fill(Color.accentColor)
                Text("\(number)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            case .upcoming:
                Circle().strokeBorder(Color.primary.opacity(0.2))
                Text("\(number)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 24, height: 24)
    }

    private var stateDescription: String {
        switch state {
        case .done: return "완료"
        case .current: return "진행 중"
        case .upcoming: return "대기"
        }
    }
}

extension SetupStep where Accessory == EmptyView {
    init(number: Int, state: StepState, title: String, detail: String) {
        self.init(number: number, state: state, title: title, detail: detail) { EmptyView() }
    }
}

private struct Keycap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .frame(minWidth: 28, minHeight: 28).padding(.horizontal, 4)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.15)))
            .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 1)
    }
}
