# Privacy notes

goldenrave is local-first and macOS-only.

## Stored fields

- Usage sessions: start, end, active seconds, and tracking mode.
- Break events: date and action (`started`, `postponed`, `skipped`, `completed`).
- Detailed mode only: app name, optional window title, and optional browser URL.

## Never collected

The app does not save keystrokes, mouse coordinates, screenshots, clipboard contents, account identifiers, passwords, or cloud sync data. Private mode never calls the detailed activity reader. Detailed mode is never enabled implicitly and fails safely when Accessibility permission is unavailable.

## Permission

Accessibility is requested only when the user chooses Detailed mode. The permission is used to read the frontmost app/window information needed for that mode. Unsupported browser data becomes an absent URL; it does not prevent the app name and window portion from being stored.

## Network

The only network request is a check of the latest release at `api.github.com/repos/learnpytest/goldenrave/releases/latest`, at launch, at most once a day, and when settings open. It sends no usage data; opening the download page is left to the user.
