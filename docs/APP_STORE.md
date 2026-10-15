# Mac App Store 배포

App Store용은 `Popvy.xcodeproj`의 `PopvyAppStore` scheme으로 빌드합니다. Swift Package와 기존 DMG 빌드는 자동 붙여넣기를 지원하는 GitHub 버전입니다.

| 항목 | App Store용 |
| --- | --- |
| 번들 ID | `app.popvy.mac.store` |
| 개발자 팀 | `HYUN KWAK` / `NB4ZP7R5G7` |
| 플랫폼 | macOS 13 이상, arm64 + x86_64 |
| 언어 | 한국어 |
| 분류 | 생산성 |
| 현재 제출용 버전 / 빌드 | 1.3.1 / 6 |
| 컴파일 조건 | `APP_STORE` |
| 권한 | App Sandbox만 사용. 네트워크, 파일 접근 예외, 자동화 권한 없음 |

App Store Connect에 Popvy 앱을 등록하고 2026년 10월 16일 1.3.1(6) 패키지를 업로드했습니다. 업로드 성공과 심사 제출, 승인은 서로 다른 단계입니다. 현재 심사 제출은 완료하지 않았습니다.

App Store용은 마우스 포인터 옆에서 기록을 열고, 선택한 항목을 클립보드에 복사한 다음 창을 즉시 닫습니다. 사용자가 원래 앱에서 Command+V를 누릅니다. 다른 앱의 접근성 API 호출과 키 입력 생성 코드는 컴파일에서 제외합니다. 손쉬운 사용 안내도 표시하지 않습니다.

기록은 샌드박스 컨테이너에 저장하며 기존 GitHub/ClipShelf 기록을 자동으로 읽거나 옮기지 않습니다. 두 버전을 동시에 실행하면 단축키가 충돌하므로 하나를 종료하도록 안내합니다. 기존 설치 앱을 이 빌드로 덮어쓰지 마세요.

## 로컬 검증

```sh
bash scripts/appstore.sh check
```

이 명령은 서명 없는 앱을 `build/appstore-derived/Build/Products/Release/Popvy.app`에 만듭니다. Xcode 컴파일, 두 아키텍처, 개인정보 manifest, 식별자와 금지된 입력 API 참조 유무를 확인합니다. 이 결과만으로는 제출 가능한 배포본이 아닙니다.

## 서명과 업로드

Xcode의 Apple Accounts에 배포용 Apple 계정으로 로그인하고, `PopvyAppStore` 대상의 Signing & Capabilities에서 위 개인 팀을 선택합니다. 인증서, 프로비저닝 프로필, App Store Connect 접근 권한이 모두 필요합니다. Developer ID는 GitHub 직접 배포에 사용하는 별도 인증서입니다.

```sh
bash scripts/appstore.sh archive
```

생성된 `build/appstore/Popvy.xcarchive`를 Xcode Organizer에서 열어 Validate App을 실행한 뒤 Distribute App → App Store Connect로 업로드합니다. 서명 검증은 실제 배포 인증서, 프로필과 Xcode 업로드 검증을 대체하지 않습니다. 기존 archive는 자동 덮어쓰지 않습니다.

로컬 제출용 패키지만 만들려면 `bash scripts/appstore.sh export`를 실행합니다. `build/appstore/export/Popvy.pkg`를 만들며 자동으로 업로드하지 않습니다. 이 패키지는 App Store 제출용이고 GitHub 다운로드용 DMG를 대체하지 않습니다.

## 심사 자료

- [한국어 스토어 설명과 심사 메모](app-store/ko-KR.md)
- [개인정보 처리방침](PRIVACY.md)
- [지원 안내](SUPPORT.md)

스크린샷은 실제 App Store용 앱과 가상 기록으로 촬영합니다. 사용자의 실제 클립보드를 촬영하지 마세요. Apple은 Mac 스크린샷으로 16:10 비율의 1280×800, 1440×900, 2560×1600 또는 2880×1800 이미지를 지원하며 알파 채널 없는 PNG/JPEG를 요구합니다. 이미지가 준비되기 전에는 스크린샷 완료로 표시하지 않습니다.

Xcode의 `PopvyAppStoreDemo` scheme은 `--demo`로 실행해 가상 기록을 보여줍니다. 이 scheme의 실행 인수는 App Store archive에 포함되지 않습니다.

최종 제출 전에는 서명한 샌드박스 앱의 첫 실행, 텍스트/이미지 수집과 수동 붙여넣기, 검색/고정/삭제, 재실행 후 기록 복원, 로그인 실행을 실제로 확인합니다. App Store Connect의 앱 개인정보, 연령 등급, 가격과 제공 국가, 심사 연락처, 거래자 자격 질문도 완료해야 합니다. 거래자 자격과 연락처는 계정 소유자의 실제 정보로 입력합니다.

## Apple 참고 자료

- [App Sandbox 제한](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [App Review Guidelines 2.4.5](https://developer.apple.com/app-store/review/guidelines/)
- [앱 등록](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [개인정보 API 사용 사유](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
