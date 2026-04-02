# Claude Code Init

새로운 PC에서 동일한 Claude Code 환경을 구성하기 위한 가이드.  
설정 파일은 GitHub에서 관리하며, 설치 스크립트로 한 줄 설치 가능.  

https://github.com/fightmin/claude-code-init

## 1단계: Claude Code 설치

### Windows (PowerShell)
```powershell
irm https://claude.ai/install.ps1 | iex
git clone https://github.com/fightmin/claude-code-init.git $env:TEMP\claude-init; & $env:TEMP\claude-init\install.ps1
```

### Mac/Linux
```bash
curl -fsSL https://claude.ai/install.sh | bash
git clone https://github.com/fightmin/claude-code-init.git /tmp/claude-init && bash /tmp/claude-init/install.sh
```

## 2단계: 설정 파일 확인

설치 스크립트가 `~/.claude/`에 자동 적용한 파일 내역.

- `settings.json`
- `statusline.js`
- `commands/ct/`
- `CLAUDE.md`

## 3단계: 설정 변경 후 동기화

```bash
# Windows
cd $HOME/.claude && git add -A && git commit -m "update" && git push

# Mac/Linux
cd ~/.claude && git add -A && git commit -m "update" && git push
```
