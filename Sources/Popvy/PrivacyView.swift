import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("개인정보 처리방침").font(.title2.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Popvy는 클립보드 기록이나 사용 정보를 개발자에게 전송하지 않습니다. 계정, 광고, 분석 도구, 클라우드 동기화 기능이 없습니다.")
                    Text("앱이 실행 중이고 기록이 활성화되어 있을 때 복사한 텍스트, 이미지, 복사 시각과 원본 앱 이름을 이 Mac에서 처리합니다. 검색과 고정, 다시 복사하기에 사용합니다.")
                    Text("기록 보관을 켜면 최근 100개, 전체 50 MiB, 항목당 5 MiB 이내로 저장합니다. 고정은 최대 20개입니다. 앱 수준 암호화는 적용하지 않습니다.")
                    Text("설정에서 ‘앱을 종료해도 기록 보관’을 끄면 저장 파일을 삭제하고 실행 중 메모리에서만 보관합니다. 항목별 삭제, 모든 기록 삭제, 기록 일시 정지도 사용할 수 있습니다. 시스템 클립보드나 사용자의 별도 백업은 이 작업으로 삭제되지 않습니다.")
                    Text("비밀번호 관리 앱이 민감한 내용으로 표시한 항목은 수집하지 않습니다. 일반 텍스트로 복사한 비밀번호나 인증번호까지 판별하지는 않습니다.")
                    if !Distribution.isAppStore {
                        Text("자동 붙여넣기는 사용자가 허용한 손쉬운 사용 권한으로 입력 위치를 확인하고 선택한 항목을 원래 앱에 붙여넣습니다.")
                    }
                    Text("문의 링크를 열면 브라우저에서 GitHub로 이동하며 GitHub의 개인정보 처리방침이 적용됩니다. 공개 이슈에는 비밀번호나 실제 클립보드 내용 등 개인정보를 올리지 마세요.")
                    Link("문의 및 버그 제보", destination: URL(string: "https://github.com/kwakhyun/Popvy/issues")!)
                    Text("2026년 10월 16일").foregroundStyle(.secondary)
                }.font(.system(size: 13)).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack { Spacer(); Button("닫기") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 480, height: 520)
    }
}
