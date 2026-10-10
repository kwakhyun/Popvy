import SwiftUI

struct PermissionSetupView: View {
    @ObservedObject var app: AppController
    @ObservedObject var setup: AccessibilitySetup

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(systemName: setup.isTrusted ? "checkmark.circle.fill" : "clipboard")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(setup.isTrusted ? Color.green : Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Popvy · 팝비").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Text(setup.isTrusted ? "바로 붙여넣을 준비가 됐어요" : "한 번 클릭으로 바로 붙여넣기")
                        .font(.system(size: 22, weight: .bold))
                }
            }

            if setup.isTrusted {
                Text("손쉬운 사용 권한을 확인했습니다. 창을 닫고 입력할 곳에서 \(app.shortcut.title)를 눌러 보세요.")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 16) {
                    step("1", "평소처럼 복사하기", "텍스트나 이미지를 ⌘ C로 복사하세요.")
                    step("2", "기록을 열고 선택하기", "입력할 곳에서 \(app.shortcut.title)를 누르고 항목을 클릭하면 됩니다.")
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                Label(app.canAutoPaste ? "자동 붙여넣기가 켜졌습니다" : "권한이 허용됐습니다. 시작하기를 누르면 자동 붙여넣기가 켜집니다.", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 12)).foregroundStyle(.green)
            } else {
                Text("선택한 기록을 원래 입력하던 앱에 붙여넣으려면 macOS의 ‘손쉬운 사용’ 권한이 필요합니다.")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 16) {
                    step("1", "아래 버튼으로 설정 열기", "개인정보 보호 및 보안 → 손쉬운 사용")
                    step("2", "Popvy 스위치 켜기", "macOS가 요청하면 Touch ID 또는 Mac 로그인 암호로 인증하세요.")
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                Text("목록에 없다면 + 버튼을 눌러 설치한 Popvy.app을 추가해 주세요.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: setup.isWaiting ? "clock" : "lock.shield")
                    Text(setup.isWaiting ? "허용을 기다리는 중… 켜면 자동으로 감지합니다." : "허용은 시스템 설정에서 직접 결정할 수 있습니다.")
                }.font(.system(size: 12)).foregroundStyle(.secondary)
                if setup.isWaiting {
                    Text("이미 켜져 있는데도 감지되지 않나요? 목록에서 Popvy를 제거한 뒤 + 버튼으로 현재 설치된 앱을 다시 추가해 주세요.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let error = app.accessibilitySetupError {
                Text(error).font(.system(size: 12)).foregroundStyle(.orange)
            }
            HStack {
                if !setup.isTrusted {
                    Button("나중에 하기") { app.finishAccessibilitySetup() }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Spacer()
                Button(setup.isTrusted ? "Popvy 시작하기" : (setup.isWaiting ? "설정 다시 열기" : "시스템 설정 열기")) {
                    if setup.isTrusted { app.finishAccessibilitySetup() }
                    else { app.openAccessibilitySettings() }
                }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
            if !setup.isTrusted {
                Text("나중에 허용해도 괜찮아요. 기록을 고른 뒤 ⌘ V로 직접 붙여넣을 수 있습니다.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(28).frame(width: 490).fixedSize(horizontal: false, vertical: true)
    }

    private func step(_ number: String, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24).background(.primary.opacity(0.06), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(description).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}
