# App Store 입력용 초안

실제 App Store용 빌드 기준입니다. 스토어 등록과 심사 완료 여부는 이 문서와 별개입니다.

## 이름

Popvy

## 부제

복사한 내용을 다시 꺼내 쓰는 클립보드

## 프로모션 텍스트

Option+V로 복사 기록을 열고, 필요한 항목을 골라 Command+V로 붙여넣으세요. 텍스트와 이미지를 Mac 안에 보관하고, 검색과 고정으로 다시 찾을 수 있습니다.

## 설명

Popvy(팝비)는 복사한 텍스트와 이미지를 다시 꺼내 쓰는 작은 클립보드 기록 앱입니다.

평소처럼 Command+C로 복사하세요. Option+V를 누르면 마우스 포인터 옆에 기록이 나타납니다. 원하는 항목을 클릭하거나 방향키와 Return으로 고른 다음, 원래 앱에서 Command+V로 붙여넣으면 됩니다.

• 텍스트, 링크, PNG/TIFF 이미지 기록
• 기록 검색과 자주 쓰는 항목 고정
• 최근 100개 보관, 최대 20개 고정
• 서식 없이 텍스트만 복사
• 단축키 변경과 선택 가능한 로그인 시 실행
• 기록 일시 정지와 개별 또는 전체 삭제
• 종료 후 기록을 남기지 않는 설정

계정이나 서버 없이 Mac 안에서 동작합니다. 클립보드 기록을 개발자에게 전송하지 않으며 광고, 분석 도구, 클라우드 동기화 기능이 없습니다.

App Store 버전은 손쉬운 사용 권한을 요청하지 않습니다. 항목을 고르면 클립보드에 복사되며, 다른 앱에 붙여넣을 때는 직접 Command+V를 누릅니다.

macOS 13 이상이 필요하며 Apple Silicon과 Intel Mac을 지원합니다. 현재 앱 화면은 한국어입니다. 기록은 전체 50 MiB, 항목당 5 MiB 이내로 보관합니다. 파일 복사는 수집하지 않습니다. 비밀번호 관리 앱이 민감한 내용으로 표시한 항목은 제외하지만 일반 텍스트로 복사한 비밀번호는 구분하지 못합니다. 기록 파일에는 앱 수준 암호화가 적용되지 않습니다.

## 키워드

클립보드,복사,붙여넣기,기록,검색,고정,텍스트,이미지,단축키,clipboard,copy,paste

## 심사 메모

Popvy is a sandboxed macOS menu bar clipboard history utility. The UI is currently in Korean. There is no sign-in, purchase, server, analytics SDK, network entitlement, external helper, or downloadable code.

To test: launch Popvy and find the clipboard icon in the menu bar (there is no Dock icon). Copy sample text in TextEdit with Command+C. Press Option+V, or click the menu bar icon. Select a history item; the panel closes and restores focus. Press Command+V in TextEdit to paste. Command+F searches. Item menus offer pin/delete. The panel's ellipsis menu opens Settings (설정). Settings includes the in-app privacy policy (개인정보 처리방침) and support link.

The Mac App Store build does not request Accessibility permission, inspect another application's accessibility tree, or synthesize keyboard input. Its popup appears near the mouse pointer. The separately distributed GitHub edition has different auto-paste behavior; it is not needed to use this app.

History is stored only inside this app's sandbox container. Turning off persistence (앱을 종료해도 기록 보관) deletes the on-disk history. No clipboard contents are sent to the developer. macOS may separately request pasteboard read access.

## 입력 전 확인

앱 개인정보는 현재 코드 기준 ‘데이터 수집 안 함’에 해당합니다. 공개 지원 URL과 개인정보 처리방침 URL은 문서가 공개된 뒤 실제 접근을 확인하고 입력합니다. 심사 연락처와 거래자 자격을 임의로 만들지 않습니다. 가격은 무료로 준비하되 출시 전 최종 확인합니다.
