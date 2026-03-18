# WinTab

Windows 사용자를 위한 macOS 키보드 단축키 변환 메뉴바 앱

## 기능

- **Ctrl+Tab** → 현재 앱의 탭 전환 (⌘⇧])
- **Ctrl+Shift+Tab** → 반대 방향 탭 전환 (⌘⇧[)
- **[AltTab 연동]** Control+Tab으로 앱 전환 (AltTab 앱 필요)
- 특정 앱 제외 설정
- 로그인 시 자동 실행

## 설치

1. [Releases](../../releases)에서 최신 `WinTab.dmg` 다운로드
2. DMG 열고 `WinTab.app`을 `/Applications`로 드래그
3. 처음 실행 시 **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 WinTab 허용

## 요구사항

- macOS 12 Monterey 이상
- 손쉬운 사용 권한

## 빌드

```bash
cd WinTabApp
xcodebuild -project WinTabApp.xcodeproj -scheme WinTab -configuration Release
```

## 라이선스

MIT
