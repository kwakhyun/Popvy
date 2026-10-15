# 업데이트와 손쉬운 사용 권한

## 현재 상태와 원인

GitHub에 공개된 1.3.1은 임시 서명(ad-hoc) 빌드입니다. 이 서명의 앱 식별 조건은 실행 파일의 해시를 사용하므로 내용이 바뀌면 이전에 허용한 앱과 동일한 앱으로 인정되지 않을 수 있습니다. 앱 이름과 번들 ID만 유지하는 것으로는 해결되지 않습니다.

[Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)은 임시 서명의 지정 요구사항이 특정 코드 버전에 묶인다고 설명합니다.

배포 버전은 같은 개발자 팀의 **Developer ID Application** 인증서와 `app.popvy.mac` 번들 ID를 유지해야 합니다. macOS의 기본 서명 식별 조건을 사용하며, 인증서와 앱 신원을 확인하지 않는 느슨한 조건으로 바꾸지 않습니다. 설치 경로도 한 곳으로 유지하고 기존 앱을 종료한 뒤 교체하세요.

임시 서명에서 Developer ID로 처음 전환할 때는 권한을 한 번 다시 허용해야 할 수 있습니다. 이후에도 사용자의 권한 철회, 운영체제 정책 변경 등으로 재승인이 필요할 수 있으므로 모든 상황에서 영구적으로 유지된다고 보장하지는 않습니다.

## 필요한 인증서

Mac의 키체인에 Popvy를 배포할 개발자 팀의 **Developer ID Application** 인증서와 해당 개인 키가 필요합니다. `Apple Development`나 `Apple Distribution` 인증서와는 용도가 다릅니다. 빌드 도구는 개인 또는 회사 계정을 자동으로 고르지 않습니다.

Xcode의 계정 및 인증서 관리 또는 [Apple 개발자 인증서 관리](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)에서 발급하세요. 조직 계정은 해당 팀의 권한이 필요할 수 있습니다. 인증서 개인 키는 GitHub에 올리지 마세요.

사용 가능한 인증서 이름 확인:

```sh
security find-identity -v -p codesigning
```

## Xcode에서 발급하기

1. **Xcode → Settings → Apple Accounts**에서 배포할 Apple 계정을 선택합니다. 인증이 만료됐다면 **Sign in Again**으로 로그인합니다.
2. Apple Developer Program에 가입된 배포 팀을 선택합니다. 무료 Personal Team만 있다면 유료 프로그램 가입이 먼저 필요합니다. 회사 팀과 개인 팀은 구분해서 선택하세요.
3. 팀의 **Manage Certificates…**를 열고 추가 메뉴의 **Developer ID Application**을 선택합니다. 메뉴가 없거나 비활성 상태라면 해당 팀의 Account Holder 권한과 멤버십 상태를 확인하세요.
4. 발급이 끝나면 이 Mac의 키체인에 인증서와 개인 키가 함께 있는지 확인합니다. 아래 설정 명령은 키체인에서 사용할 수 있는 유효한 인증서만 허용합니다.

Xcode에서 진행할 수 없다면 Apple 개발자 사이트의 **Certificates, Identifiers & Profiles → Certificates → + → Developer ID Application**을 사용합니다. 이 Mac의 키체인 접근 앱에서 인증서 서명 요청(CSR)을 만들고 사이트에 제출한 뒤, 내려받은 `.cer`를 열어 설치합니다. [Apple의 CSR 생성 안내](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request)를 참고하세요. Popvy의 앱 및 DMG 서명에는 Developer ID Application을 사용하며, 별도의 `.pkg` 설치 프로그램을 만들지 않으므로 Developer ID Installer는 필요하지 않습니다.

## 이 Mac에 서명 설정 저장

인증서를 발급한 다음 **실제 인증서 전체 이름과 Team ID**로 한 번 실행합니다.

```sh
bash scripts/configure-signing.sh 'Developer ID Application: Your Name (ABCDEFGHIJ)' ABCDEFGHIJ
```

이 명령은 키체인의 인증서를 확인한 후 `.popvy-signing.plist`에 이름과 Team ID만 저장합니다. 개인 키나 암호는 저장하지 않습니다. 파일은 Git에서 제외되며 사용자만 읽고 쓸 수 있습니다. 이후 일반 빌드, 설치 스크립트와 배포 스크립트가 같은 인증서를 자동으로 사용합니다. 인증서가 사라지거나 만료되면 임시 서명으로 돌아가지 않고 중단합니다.

환경 변수로 `POPVY_SIGNING_IDENTITY`를 명시하면 저장 설정보다 우선합니다. CI에서도 아래 환경 변수 방식을 사용할 수 있습니다. 로컬 설정을 명시적으로 건너뛰어 임시 서명 테스트를 하려면 `POPVY_SIGNING_IDENTITY=- POPVY_TEAM_ID= bash scripts/build.sh`를 사용하세요.

## 빌드와 배포

환경 변수에는 본인의 실제 인증서 이름과 Team ID를 넣습니다. 다음 값은 예시입니다.

```sh
export POPVY_SIGNING_IDENTITY='Developer ID Application: Your Name (ABCDEFGHIJ)'
export POPVY_TEAM_ID='ABCDEFGHIJ'
bash scripts/build.sh universal
bash scripts/release.sh
```

Developer ID 빌드는 hardened runtime과 secure timestamp를 적용합니다. 빌드 후 실제 인증서와 Team ID도 다시 확인합니다. 지정한 인증서가 없거나 다른 종류이면 빌드 전에 실패하며, 임시 서명으로 자동 전환하지 않습니다.

배포 스크립트는 Developer ID 설정을 기본으로 요구합니다. 개발 중 임시 서명 테스트 패키지가 꼭 필요할 때만 명시적으로 허용합니다. 이 파일은 업데이트 후 권한 재설정을 요구할 수 있습니다.

```sh
POPVY_ALLOW_ADHOC_RELEASE=1 bash scripts/release.sh
```

저장된 설정도 환경 변수도 없이 `build.sh`만 실행하면 기존처럼 로컬 임시 서명으로 빌드하며 경고를 출력합니다. 권한을 유지하려는 설치에 이 개발 빌드를 덮어쓰지 마세요.

## 업데이트 전 서명 검사

첫 Developer ID 배포 이후에는 이전에 배포한 Developer ID 앱과 새 앱을 비교합니다.

```sh
bash scripts/verify-update-signature.sh /path/to/previous/Popvy.app build/universal/Popvy.app

# 배포 과정에도 같은 검사를 포함하려면
export POPVY_PREVIOUS_APP='/path/to/previous/Popvy.app'
bash scripts/release.sh
```

검사는 서명 유효성, 번들 ID, Team ID를 확인한 뒤 macOS의 `codesign`으로 서로의 지정 요구사항을 만족하는지 평가합니다. 임시 서명 앱, 팀이 바뀐 앱, 기존 앱의 요구사항을 만족하지 못하는 앱은 거절합니다. 첫 임시 서명 → Developer ID 전환에서는 이 검사를 통과할 수 없습니다. 그 전환을 배포할 때는 `POPVY_PREVIOUS_APP`을 지정하지 않고 재승인 안내를 제공하세요.

서명 검사는 운영체제 권한 데이터베이스를 변경하지 않습니다. 실제 권한 유지 여부는 별도 Mac에서 이전 버전을 허용한 뒤 새 버전으로 업데이트해 확인해야 합니다.

## 공증은 별도 절차

**같은 앱 신원으로 서명하는 것**이 업데이트 권한 유지의 핵심이고, **Apple 공증**은 다운로드한 앱의 보안 검사 및 첫 실행에 관한 별도 절차입니다. 현재 스크립트는 서명까지만 지원하며 공증이나 업로드는 하지 않습니다. [배포 안내](RELEASING.md)에 따라 공증을 추가하세요. 첫 Developer ID 배포 때 README와 릴리스 노트의 서명 상태 설명도 실제 결과에 맞게 갱신해야 합니다.
