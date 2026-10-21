# cc-session-restore

컴퓨터를 껐다 켜도 [Claude Code](https://docs.claude.com/en/docs/claude-code) 세션을 **Terminator 창 배치 그대로** 다시 여는 도구입니다.

- 10분마다 열려 있는 Claude Code 세션 목록과 Terminator 레이아웃(창, 탭 순서, 화면 분할, 칸별 폴더)을 저장합니다.
- 독 아이콘을 한 번 누르면 저장된 레이아웃으로 Terminator를 열고, 세션이 있던 칸에서 `claude --resume <id>`로 대화를 이어서 엽니다.

> Anthropic 공식 도구가 아닙니다. Claude Code의 내부 파일(`~/.claude/sessions/*.json`)을 읽기 때문에 Claude Code가 업데이트되면 동작이 바뀔 수 있습니다.

## 요구 사항

- Linux + GNOME (독 고정 기능만 GNOME 전용, 나머지는 systemd 사용자 세션이면 동작)
- Terminator 2.x
- `jq`, `python3-configobj`
- Claude Code CLI (`claude`)

Ubuntu 기준:

```bash
sudo apt install terminator jq python3-configobj
```

## 설치

```bash
git clone https://github.com/GyoungTaeChae/cc-session-restore.git
cd cc-session-restore
./install.sh
```

설치 스크립트가 하는 일:

1. `cc-snapshot`, `cc-restore`, `cc-restore-layout`을 `~/.local/bin`에 복사
2. Terminator 플러그인(`LayoutSnapshot`)을 `~/.config/terminator/plugins`에 복사하고 설정에서 켬
3. systemd 사용자 타이머 등록 (10분마다 저장, 로그아웃·종료 때 한 번 더 저장)
4. 앱 목록에 **"Claude 세션 복원"** 아이콘 추가, GNOME 독에 고정

저장 위치를 바꾸려면 설치할 때 지정합니다. 기본값은 `~/.local/state/cc-session-restore`입니다.

```bash
CLAUDE_SESSIONS_DIR=~/my/sessions ./install.sh
```

### 설치 직후 한 번: Terminator 다시 시작

Terminator 플러그인은 Terminator가 **시작될 때만** 읽힙니다. Terminator 창은 여러 개여도 프로세스 하나이므로, 창을 **모두** 닫아야 플러그인이 켜집니다.

1. 터미널에서 `cc-snapshot` 실행 (지금 열린 세션 기록)
2. Terminator 창을 전부 닫기
3. 독의 **Claude 세션 복원** 아이콘 클릭. 이번 한 번은 레이아웃 기록이 없어서 탭으로만 열립니다.
4. 창을 원하는 모양으로 배치해 두면, 그때부터 10분마다 저장됩니다.

지금 바로 닫기 어렵다면 다음 재부팅 때 자연스럽게 적용되도록 두어도 됩니다.

## 사용법

평소에는 할 일이 없습니다. 재부팅한 뒤 독 아이콘을 누르면 됩니다.

| 하고 싶은 것 | 독 아이콘 | 터미널 |
|---|---|---|
| 저장된 배치 그대로 복원 | 클릭 | `cc-restore` |
| 저장된 세션 목록 보기 | 우클릭 → 열린 세션 목록 보기 | `cc-restore --list` |
| 레이아웃 무시, 세션마다 탭 하나 | 우클릭 → 레이아웃 없이 탭으로 열기 | `cc-restore --tabs` |
| 세션마다 창 하나 | 우클릭 → 탭 대신 창으로 열기 | `cc-restore --windows` |
| 지금 바로 저장 | 우클릭 → 지금 세션 기록하기 | `cc-snapshot` |

복원 규칙:

- Claude 세션이 있던 칸은 `claude --resume`으로, 나머지 칸은 원래 폴더의 빈 셸로 엽니다.
- Terminator가 **이미 열려 있으면** 레이아웃 대신 지금 실행 중이 아닌 세션만 탭으로 추가합니다(중복 방지).
- 레이아웃 저장 이후에 새로 연 세션은 탭으로 따로 붙습니다.
- 폴더가 사라진 세션은 건너뜁니다.

실행 기록은 저장 폴더의 `cc-restore.log`에 남습니다.

## 저장되는 파일

| 파일 | 내용 | 저장 주기 |
|---|---|---|
| `open-sessions.json` | 세션 id, 이름, 시작 폴더, 있던 Terminator 칸(uuid) | 10분 + 종료 시 |
| `terminator-layout.json` | 창, 탭 순서, 분할 비율, 칸별 uuid와 폴더 | 10분 |

## 제거

```bash
./uninstall.sh
```

설치한 파일, 타이머, 플러그인 설정, 독 고정을 되돌립니다. 저장된 기록 파일은 남겨 둡니다.

## 한계

- 마지막 저장 뒤 최대 10분 사이의 변화(새 탭, 분할)는 갑자기 꺼지면 빠질 수 있습니다.
- Claude가 아닌 칸은 폴더만 복원합니다. 그 칸에서 돌던 명령은 다시 실행하지 않습니다.
- 창 위치는 Terminator가 기억하는 범위(위치, 크기, 최대화)까지만 복원됩니다.

## 동작 확인

```bash
test/check_restore_layout.sh   # OK 가 나오면 레이아웃 변환이 정상
```

## 라이선스

MIT
