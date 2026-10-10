# GitHub 배포 준비

## 현재 결과물

`bash scripts/release.sh`는 현재 소스로 universal 앱을 새로 빌드하고 `dist/v1.3.0/`에 DMG, 앱 ZIP, 소스 ZIP, 설치 안내, 릴리스 본문과 SHA-256 체크섬을 생성합니다. **GitHub 업로드나 저장소 생성은 하지 않습니다.** 같은 버전의 출력 폴더가 있으면 덮어쓰지 않고 중단합니다. 다시 만들 때는 기존 폴더를 다른 곳에 보관하세요.

DMG에는 Popvy.app, Applications 바로가기, 설치 안내와 라이선스가 들어 있습니다. 소스 ZIP은 지정한 소스와 문서만 포함합니다. 로컬 기록, `.git`, 빌드 로그, 이전 앱 백업은 포함하지 않습니다. `build/`와 `dist/`는 Git에서 제외합니다.

## 버전별 작업

1. `Resources/Info.plist`의 버전과 빌드 번호를 올립니다.
2. 앱 설정에 표시되는 버전, README의 파일명, `docs/INSTALL.txt`, `docs/RELEASE_NOTES.md`와 이 문서를 갱신합니다.
3. README의 테스트 명령을 실행합니다.
4. `bash scripts/release.sh`를 실행합니다.
5. DMG를 열어 앱과 Applications 바로가기, 설치 안내를 확인합니다. 실제 다운로드한 파일로 별도 Mac에서 설치, 첫 실행, 권한 설정, Option + V 호출과 자동 붙여넣기를 확인합니다.
6. 배포 대상 Intel Mac과 최소 지원 macOS도 확인합니다. 검증하지 못했다면 릴리스 본문에 범위를 명시합니다.

로컬 테스트 성공만으로 인터넷 다운로드 후 Gatekeeper 실행까지 검증되었다고 판단하지 마세요.

## GitHub 공개

공개 저장소는 [kwakhyun/Popvy](https://github.com/kwakhyun/Popvy)이며 설치 파일은 [GitHub Releases](https://github.com/kwakhyun/Popvy/releases)에 배포합니다.

1. 공개 저장소에 소스와 문서를 올립니다. `git status --short`로 대상 파일을 확인하세요. 검증 작업 메모인 `VALIDATION.md`는 배포 소스에서 제외되어 있습니다.
2. 준비한 소스 커밋에 `v1.3.0` 태그를 붙이고 GitHub에서 해당 태그의 **Draft Release**를 만듭니다.
3. 제목은 `Popvy 1.3.0`, 본문은 `docs/RELEASE_NOTES.md`를 사용합니다.
4. `dist/v1.3.0/`의 DMG, 앱 ZIP, 소스 ZIP, `INSTALL.txt`, `RELEASE_NOTES.md`, `SHA256SUMS.txt`를 첨부합니다.
5. 아래 서명 상태를 확인한 뒤 공개합니다. 미공증 상태로 배포하면 릴리스 본문의 해당 안내를 유지하세요.

다운로드한 파일을 같은 폴더에 둔 뒤 `shasum -a 256 -c SHA256SUMS.txt`로 무결성을 확인할 수 있습니다.

## 서명과 공증

기본 스크립트는 **로컬 임시 서명만** 합니다. GitHub에 올리는 것만으로 Apple 공증이 생기지는 않습니다. 첫 실행 과정을 단순하게 하려면 Apple Developer Program의 **Developer ID Application** 인증서로 서명하고 Apple에 공증을 요청해야 합니다. [Apple Developer ID 안내](https://developer.apple.com/developer-id/), [공증 문서](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)를 참고하세요.

현재 패키징 스크립트에는 Developer ID 서명 및 공증 자동화가 포함되어 있지 않습니다. 공증 배포로 전환할 때는 다음 순서로 확장해야 합니다.

1. universal 앱에 Developer ID 서명, hardened runtime과 secure timestamp를 적용합니다.
2. `notarytool`로 앱을 제출하고 Accepted 결과를 확인합니다.
3. `stapler`로 앱에 공증 티켓을 붙이고 검증합니다.
4. 그 앱으로 DMG와 ZIP을 만듭니다. DMG도 서명과 공증 후 티켓을 붙입니다.
5. Gatekeeper 평가와 별도 Mac에서의 다운로드 설치를 확인합니다.
6. 파일을 모두 확정한 뒤 체크섬을 새로 생성하고, README와 설치 안내, 릴리스 본문의 서명 상태를 실제 결과에 맞게 변경합니다.

공증 후 기본 `release.sh`를 다시 실행하면 새 임시 서명 빌드를 만들므로 공증된 앱을 유지할 수 없습니다. 인증서, 개인 키, 앱 전용 암호는 저장소나 배포 파일에 넣지 마세요.
