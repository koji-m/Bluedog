from typing import Optional
from pathlib import Path
from urllib.parse import urlparse, unquote

from atproto_client import Client, Session, SessionEvent
import pyotherside


SESSION_FILE = "session"

_data_dir = None
_client = None

def _as_path(p: str) -> Path:
    if p is None:
        raise ValueError("data dir was None (did QML pass a QUrl without converting?)")
    s = str(p)
    if s.startswith("file://"):
        s = unquote(urlparse(s).path)
    return Path(s)


def set_data_dir(path: str) -> None:
    global _data_dir
    _data_dir = _as_path(path)
    _data_dir.mkdir(parents=True, exist_ok=True)


def _get_session() -> Optional[str]:
    base = _data_dir
    path = base / SESSION_FILE
    try:
        with path.open() as f:
            return f.read()
    except FileNotFoundError:
        return None


def _save_session(session_string: str) -> None:
    base = _data_dir
    path = base / SESSION_FILE
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as f:
        f.write(session_string)


def _on_session_change(event: SessionEvent, session: Session) -> None:
    print('Session changed:', event, repr(session))
    if event in (SessionEvent.CREATE, SessionEvent.REFRESH):
        print('Saving changed session')
        _save_session(session.export())
        # ToDo: notify QML of session change for update properties of MainView (myDid, myHandle, etc.)


def init_client() -> Client:
    global _client

    if _client:
        return _client

    client = Client()
    client.on_session_change(_on_session_change)

    session_string = _get_session()
    if session_string:
        print('Reusing session')
        client.login(session_string=session_string)
    else:
        print('Creating new session')
        raise Exception("No session found; please sign in first")

    _client = client

    return client


def sign_in(username, password):
    global _client
    try:
        client = Client()
        client.on_session_change(_on_session_change)
        client.login(username, password)
        _client = client
        return { "status": "ok" }
    except Exception as e:
        return { "status": "error", "message": str(e) }


def sign_out():
    global _client

    session_path = _data_dir / SESSION_FILE
    try:
        if session_path.exists():
            session_path.unlink()
    except Exception:
        pass

    _client = None
