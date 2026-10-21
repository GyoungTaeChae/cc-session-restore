# cc-session-restore

컴퓨터를 껐다 켜도 [Claude Code](https://docs.claude.com/en/docs/claude-code) 세션을 **Terminator 창 배치 그대로** 다시 여는 도구입니다.

- 10분마다 열려 있는 Claude Code 세션 목록과 Terminator 레이아웃(창, 탭 순서, 화면 분할, 칸별 폴더)을 저장합니다.
- 독 아이콘을 한 번 누르면 저장된 레이아웃으로 Terminator를 열고, 세션이 있던 칸에서 `claude --resume <id>`로 대화를 이어서 엽니다.

> Anthropic 공식 도구가 아닙니다. Claude Code의 내부 파일(`~/.claude/sessions/*.json`)을 읽기 때문에 Claude Code가 업데이트되면 동작이 바뀔 수 있습니다.

## 요구 사항

- Linux + GNOME (독 고정 기능만 GNOME 전용, 나머지는 systemd 사용자 세션이면 동작)
- Terminator 2.x
- `jq`, `python3-configobj`, `zenity`
- Claude Code CLI (`claude`)

Ubuntu 기준:

```bash
sudo apt install terminator jq python3-configobj zenity
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

평소에는 할 일이 없습니다. 세션이 사라졌을 때 독 아이콘을 누르면 됩니다.

| 상황 | 아이콘을 누르면 |
|---|---|
| 재부팅 등으로 Terminator가 **꺼져 있을 때** | 마지막 기록의 세션이 저장된 창, 탭 순서, 분할 그대로 **바로** 열림 |
| Terminator는 떠 있는데 **창 일부가 닫히거나 튕겼을 때** | 최근 24시간 안에 기록됐지만 지금 안 돌고 있는 세션 목록 창이 뜸. **가장 최근에 사라진 세션들이 미리 체크**되어 있으니 확인만 누르면 됨 |

- 이미 실행 중인 세션은 다시 열지 않습니다(같은 대화가 두 번 열리는 것 방지).
- 기존 Terminator 창에 탭을 끼워 넣지 않고 **새 창**으로 엽니다.
- 저장된 레이아웃이 없는 세션(플러그인이 켜지기 전, 저장 직전에 연 세션)은 새 창 하나에 탭으로 모아 엽니다.
- Claude가 아닌 칸은 원래 폴더의 빈 셸로 엽니다. 폴더가 사라진 세션은 건너뜁니다.

| 하고 싶은 것 | 독 아이콘 | 터미널 |
|---|---|---|
| 복원 | 클릭 | `cc-restore` |
| 무엇이 열릴지 미리 보기 | 우클릭 → 열린 세션 목록 보기 | `cc-restore --list` |
| 레이아웃 무시, 창 하나에 탭으로 | 우클릭 → 레이아웃 없이 탭으로 열기 | `cc-restore --tabs` |
| 레이아웃 무시, 세션마다 창 하나 | 우클릭 → 탭 대신 창으로 열기 | `cc-restore --windows` |
| 지금 바로 기록 | 우클릭 → 지금 세션 기록하기 | `cc-snapshot` |

실행 기록은 저장 폴더의 `cc-restore.log`에 남습니다.

## 저장되는 파일

기록은 덮어쓰지 않고 시각별 파일로 3일간 보관합니다. 창이 튕긴 뒤에 타이머가 돌아도 튕기기 전 기록이 남습니다.

| 파일 | 내용 | 저장 주기 |
|---|---|---|
| `history/YYYYmmdd-HHMMSS.json` | 세션 id, 이름, 시작 폴더, 있던 Terminator 칸(uuid) | 10분 + 로그아웃·종료 시 |
| `layouts/YYYYmmdd-HHMMSS-<pid>.json` | 창, 탭 순서, 분할 비율, 칸별 uuid와 폴더 | 10분 (Terminator 플러그인) |
| `open-sessions.json` | 가장 최근 세션 기록 사본 | 10분 |

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
