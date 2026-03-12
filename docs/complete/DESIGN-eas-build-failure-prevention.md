# EAS Build 실패 방지 설계

## 날짜: 2026-03-17
## 상태: 구현 완료

## 문제 분석

### Build #64, #65 실패 원인
- **직접 원인**: `expo-updates-gradle-plugin:compileKotlin` 실패
- **에러**: `kotlin-stdlib-2.2.0.jar — Module was compiled with an incompatible version`
- **근본 원인**: Expo SDK 55 업그레이드 시 `expo` 코어만 업데이트하고 22개 companion 패키지를 업데이트하지 않음
  - `expo-updates` 29.0.16 (SDK 54) → 55.0.13 (SDK 55) 필요
  - EAS Build의 Gradle 9.0.0이 Kotlin 2.2.0을 번들하지만, 구버전 expo-updates의 gradle plugin은 구버전 Kotlin으로 컴파일됨

### 왜 발생했나
1. `npm install expo@~55.0.5`는 코어 expo만 업데이트
2. `npx expo install --fix`를 실행하지 않아 companion 패키지 버전 불일치
3. 로컬에서는 JavaScript만 실행하므로 네이티브 빌드 오류를 감지 불가
4. EAS Build가 GitHub push 시 자동 트리거되어 검증 없이 빌드 진행

## 해결 (적용 완료)

### 1. 패키지 업데이트 (`npx expo install --fix`)
- 22개 패키지 → SDK 55 호환 버전으로 일괄 업데이트
- `@sentry/react-native` 8.1.0 → 7.11.0 (SDK 55 권장)
- `react` 19.1.0 → 19.2.0, `react-native` 0.81.5 → 0.83.2

### 2. 누락 플러그인 추가 (`app.config.js`)
- `expo-image`, `expo-font` 플러그인 등록

### 3. 중복 의존성 해결 (`package.json` overrides)
- `@10play/tentap-editor` 내부의 `react-dom` 18.x → 루트 19.2.0으로 통일

### 4. Pre-build check 스크립트 (`scripts/pre-build-check.sh`)
5단계 자동 검증:
1. `npx expo install --check` — SDK 호환성
2. `npx tsc --noEmit` — TypeScript 컴파일
3. `npx expo-doctor` — 프로젝트 건강도
4. `verify.sh` — 중앙 레포 sync 정합성
5. `npx jest --ci` — 테스트

## 재발 방지 규칙

### Expo SDK 업그레이드 절차 (필수)
```bash
# 1. 코어 업데이트
npm install expo@~XX.0.0

# 2. 모든 companion 패키지 자동 수정 (★ 반드시 실행)
npx expo install --fix

# 3. 호환성 검증
npx expo install --check

# 4. expo-doctor 실행
npx expo-doctor

# 5. 테스트
npx jest --ci

# 6. pre-build check
bash scripts/pre-build-check.sh
```

### 빌드 전 체크리스트
- [ ] `npx expo install --check` → "Dependencies are up to date"
- [ ] `npx expo-doctor` → critical 오류 없음
- [ ] `bash scripts/pre-build-check.sh` → All checks passed

## 디버깅 가이드

### EAS Build 로그 접근
```bash
# 최근 빌드 목록
npx eas build:list --limit 5

# 특정 빌드 로그
npx eas build:view <build-id>

# 로그 URL에서 직접 다운로드 (JSONL 형식)
curl --compressed "https://logs.expo.dev/..." | python3 -c "
import json, sys
for line in sys.stdin:
    entry = json.loads(line)
    if entry.get('phase') == 'BUILD' and 'error' in entry.get('msg','').lower():
        print(entry['msg'])
"
```

### Kotlin/Gradle 호환성 오류
- EAS Build의 Gradle 버전 확인 → 번들 Kotlin 버전 파악
- expo-updates-gradle-plugin 등 네이티브 플러그인의 Kotlin 컴파일 버전 확인
- 해결: `npx expo install --fix`로 SDK 호환 버전 설치
