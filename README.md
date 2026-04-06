# Claude Code Init

새로운 PC에서 동일한 Claude Code 환경을 구성하기 위한 가이드.  
설정 파일은 GitHub에서 관리하며, 설치 스크립트로 한 줄 설치 가능.  

https://github.com/codestream/claude-code-init

## 1단계: Claude Code 설치

### Windows (PowerShell)
```powershell
irm https://claude.ai/install.ps1 | iex
git clone https://github.com/codestream/claude-code-init.git $env:TEMP\claude-init; & $env:TEMP\claude-init\install.ps1
```

### Mac/Linux
```bash
curl -fsSL https://claude.ai/install.sh | bash
git clone https://github.com/codestream/claude-code-init.git /tmp/claude-init && bash /tmp/claude-init/install.sh
```

## 2단계: 설치 결과 확인

설치 스크립트는 단순 파일 복사가 아니라, `~/.claude/`를 이 저장소와 연결된 git 저장소로 만듭니다.

**설치 방식**

1. 임시 경로에 저장소를 clone
2. `.git`만 `~/.claude/`로 이동
3. `~/.claude/`에서 `git reset --hard`로 파일 배포

결과적으로 `~/.claude/` 자체가 git 저장소가 됩니다. 원격 origin은 이 GitHub 저장소를 가리킵니다.

**설치 후 적용되는 파일**

- `settings.json`
- `statusline.js`
- `commands/ct/`
- `CLAUDE.md`

## 주의사항

### 기존 파일 백업

`~/.claude/`가 git 저장소가 아닌 상태에서 설치하면, 아래 파일이 있을 경우 자동으로 백업됩니다.

- `settings.json` → `settings.json~backup`
- `statusline.js` → `statusline.js~backup`
- `CLAUDE.md` → `CLAUDE.md~backup`

백업 후 이 저장소의 파일로 덮어씁니다. 기존 설정을 유지하려면 설치 후 백업 파일을 직접 병합하세요.

이미 git 저장소로 관리 중인 경우에는 백업 없이 `git fetch origin && git reset --hard origin/main`으로 최신 상태로 업데이트됩니다.

### skipDangerousModePermissionPrompt

`settings.json`에는 `skipDangerousModePermissionPrompt: true`가 포함되어 있습니다.
위험 작업(파일 삭제, 강제 푸시 등) 실행 시 확인 프롬프트를 건너뛰는 설정입니다.
필요에 따라 `false`로 변경하거나 해당 항목을 제거하세요.

## 3단계: 설정 변경 후 동기화

`~/.claude/`가 git 저장소이므로, 로컬에서 설정을 바꾼 뒤 바로 push해 다른 PC와 동기화할 수 있습니다.

```bash
# Windows
cd $HOME/.claude && git add -A && git commit -m "update" && git push

# Mac/Linux
cd ~/.claude && git add -A && git commit -m "update" && git push
```
