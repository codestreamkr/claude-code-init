#!/bin/bash
# Claude Code Init - Mac/Linux
# Usage: git clone https://github.com/fightmin/claude-code-init.git /tmp/claude-init && bash /tmp/claude-init/install.sh

set -e

REPO="${1:-https://github.com/fightmin/claude-code-init.git}"
CLAUDE_DIR="$HOME/.claude"

# [1/4] ~/.claude/ 디렉토리 준비
echo "[1/4] Preparing ~/.claude/ ..."
if [ ! -d "$CLAUDE_DIR" ]; then
    mkdir -p "$CLAUDE_DIR"
    echo "  ~/.claude/ created"
else
    echo "  ~/.claude/ already exists"
fi

# [2/4] git repo 연결
echo "[2/4] Connecting git repo..."

if [ -d "$CLAUDE_DIR/.git" ]; then
    # 이미 git repo → fetch + reset
    cd "$CLAUDE_DIR"
    existing=$(git remote get-url origin 2>/dev/null || true)
    if [ "$existing" != "$REPO" ]; then
        git remote set-url origin "$REPO"
    fi
    git fetch origin
    git reset --hard origin/main
    echo "  updated to latest"
else
    # git repo 없음 → 기존 파일 백업 후 clone
    for f in settings.json statusline.js CLAUDE.md; do
        if [ -f "$CLAUDE_DIR/$f" ]; then
            mv "$CLAUDE_DIR/$f" "$CLAUDE_DIR/${f}~backup"
            echo "  backed up: $f -> ${f}~backup"
        fi
    done

    # temp 경로에 clone 후 .git만 이동
    TEMP_DIR="$(mktemp -d)"
    git clone "$REPO" "$TEMP_DIR"
    mv "$TEMP_DIR/.git" "$CLAUDE_DIR/.git"
    rm -rf "$TEMP_DIR"

    # reset --hard로 최신 파일 배포
    cd "$CLAUDE_DIR"
    git reset --hard HEAD
    echo "  cloned and applied"
fi

# [3/5] MCP 서버 등록
echo "[3/5] Registering MCP servers..."
if command -v claude &>/dev/null; then
    claude mcp add magic npx -y @21st-dev/magic && echo "  registered: magic" || echo "  skipped: magic"
    claude mcp add sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking && echo "  registered: sequential-thinking" || echo "  skipped: sequential-thinking"
else
    echo "  skipped (claude not found)"
fi

# [4/5] Mac/Linux용 경로 패치
echo "[4/5] Patching settings for Mac/Linux..."
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
    sed -i.bak 's|\$HOME/\.claude/statusline\.js|~/.claude/statusline.js|g' "$SETTINGS" && rm -f "$SETTINGS.bak"
    echo "  statusLine command patched"
fi

# [5/5] 결과 확인
echo "[5/5] Verifying..."
echo ""
echo "Installed files:"
for f in CLAUDE.md settings.json statusline.js .gitignore; do
    [ -f "$CLAUDE_DIR/$f" ] && echo "  + $f"
done
find "$CLAUDE_DIR/commands" -type f 2>/dev/null | while read -r file; do
    echo "  + ${file#$CLAUDE_DIR/}"
done

echo ""
echo "Done!"
echo "  Location: $CLAUDE_DIR"
echo "  Push changes: cd $CLAUDE_DIR && git add -A && git commit -m 'update' && git push"
echo ""
echo "Next: run 'claude' to authenticate and verify."

# 임시 클론 디렉토리 정리
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
case "$SCRIPT_DIR" in
    /tmp/*)
        rm -rf "$SCRIPT_DIR"
        ;;
esac
