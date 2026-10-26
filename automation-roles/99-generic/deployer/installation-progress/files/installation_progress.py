#!/usr/bin/env python3

import argparse
import glob
import os
import re
import sys
import tempfile
import threading
import time
from datetime import datetime, timezone

try:
    import fcntl
except ImportError:
    fcntl = None
try:
    import msvcrt
except ImportError:
    msvcrt = None

TITLE = "IBM Cloud Pak Deployer - Installation Progress"
LOG_DIR = "log"
LOG_FILE = "installation-progress.log"

STATUS_PENDING = "PENDING"
STATUS_RUNNING = "RUNNING"
STATUS_COMPLETED = "COMPLETED"
STATUS_FAILED = "FAILED"
STATUS_SKIPPED = "SKIPPED"
KNOWN_STATUSES = (STATUS_PENDING, STATUS_RUNNING, STATUS_COMPLETED, STATUS_FAILED, STATUS_SKIPPED)

RESULT_IN_PROGRESS = "IN PROGRESS"
RESULT_SUCCESS = "SUCCESS"
RESULT_FAILED = "FAILED"

HEADER_ORDER = (
    "Installation ID",
    "Playbook",
    "Status directory",
    "Started",
    "Status",
    "Completed",
    "Failure",
)

COMMON_LOG_FILES = (
    "log/cloud-pak-deployer.log",
    "log/deployer-activities.log",
)

STEP_LOG_FILES = {
    "10": ("log/record-deployer-state.log",),
    "30": ("terraform/plan.log", "terraform/apply.log"),
    "50": ("log/cloud-pak-mirror-images.log", "log/cp4i-mirror-images.log"),
    "80": ("log/record-deployer-state.log",),
}

NOT_CREATED = "(not created)"
DIRECTORY_MARKER = "(directory)"

LOCK_TIMEOUT = 10.0
MAX_TEXT_LENGTH = 300

_SECRET_PATTERN = re.compile(
    r"(?i)([a-z0-9_-]*(?:password|passwd|pwd|token|secret|api[_-]?key|apikey|"
    r"authorization|entitlement|credential)[a-z0-9_-]*)(\s*[:=]\s*)(\S+)"
)
_STEP_BLOCK_PATTERN = re.compile(r"^\[([A-Z ]+)\]\s+(.*)$")
_IMPORT_PATTERN = re.compile(r"^\s*-\s*import_playbook:\s*(\S+)\s*$")
_PLAY_NAME_PATTERN = re.compile(r"^-\s+name:\s*(.+?)\s*$")
_STAGE_PATTERN = re.compile(r"^(\d+)")

_THREAD_LOCK = threading.Lock()


def warn(message):
    sys.stderr.write("installation-progress: {}\n".format(message))


def clean_text(value, max_length=MAX_TEXT_LENGTH):
    text = str(value)
    text = re.sub(r"[\x00-\x1f\x7f]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    text = _SECRET_PATTERN.sub(r"\1\2***", text)
    if len(text) > max_length:
        text = text[: max_length - 3] + "..."
    return text


def now_timestamp():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def parse_timestamp(value):
    if not value or value == "-":
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed


def format_duration(started, finished):
    start = parse_timestamp(started)
    end = parse_timestamp(finished)
    if start is None or end is None:
        return "-"
    seconds = int((end - start).total_seconds())
    if seconds < 0:
        seconds = 0
    hours, remainder = divmod(seconds, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours:
        return "{}h {}m {}s".format(hours, minutes, secs)
    if minutes:
        return "{}m {}s".format(minutes, secs)
    return "{}s".format(secs)


def main_log_path(status_dir):
    return os.path.join(status_dir, LOG_DIR, "cloud-pak-deployer.log")


def read_lines(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read().splitlines()


def first_play_name(path):
    for line in read_lines(path):
        match = _PLAY_NAME_PATTERN.match(line)
        if match:
            return clean_text(match.group(1))
    raise ValueError("no play name found in {}".format(path))


def planned_steps(playbook_path):
    lines = read_lines(playbook_path)
    imported = []
    for line in lines:
        match = _IMPORT_PATTERN.match(line)
        if match:
            imported.append(match.group(1).strip("'\""))
    if not imported:
        steps = []
        for line in lines:
            match = _PLAY_NAME_PATTERN.match(line)
            if match:
                steps.append(clean_text(match.group(1)))
        if not steps:
            raise ValueError("no installation steps found in playbook {}".format(playbook_path))
        return steps
    playbook_dir = os.path.dirname(os.path.abspath(playbook_path))
    steps = []
    for item in imported:
        target = item
        if not os.path.isabs(target):
            target = os.path.join(playbook_dir, target)
        steps.append(first_play_name(target))
    return steps


def step_log_paths(step_name):
    paths = list(COMMON_LOG_FILES)
    match = _STAGE_PATTERN.match(step_name.strip())
    if match:
        paths.extend(STEP_LOG_FILES.get(match.group(1), ()))
    return paths


def log_entries(status_dir, step_name):
    entries = []
    for relative in step_log_paths(step_name):
        full_path = os.path.join(status_dir, *relative.split("/"))
        if os.path.exists(full_path):
            entries.append(full_path)
        else:
            entries.append("{} {}".format(full_path, NOT_CREATED))
    log_dir = os.path.join(status_dir, LOG_DIR)
    if os.path.isdir(log_dir):
        entries.append("{} {}".format(log_dir, DIRECTORY_MARKER))
    else:
        entries.append("{} {}".format(log_dir, NOT_CREATED))
    return entries


def render(state):
    lines = [TITLE, ""]
    header = state["header"]
    for key in HEADER_ORDER:
        if key in header:
            lines.append("{:<16}: {}".format(key, header[key]))
    lines.append("")
    for step in state["steps"]:
        status = step["status"]
        if status not in KNOWN_STATUSES:
            status = STATUS_PENDING
        lines.append("{:<12}{}".format("[{}]".format(status), step["name"]))
        started = step.get("started") or "-"
        completed = step.get("completed") or "-"
        lines.append("  Started:   {}".format(started))
        lines.append("  Completed: {}".format(completed))
        lines.append("  Duration:  {}".format(format_duration(step.get("started"), step.get("completed"))))
        if step.get("failure"):
            lines.append("  Failure:   {}".format(step["failure"]))
        lines.append("  Logs:")
        for entry in log_entries(header.get("Status directory", ""), step["name"]):
            lines.append("    - {}".format(entry))
        lines.append("")
    return "\n".join(lines) + "\n"


def parse(raw):
    lines = raw.splitlines()
    state = {"header": {}, "steps": []}
    position = 1 if lines else 0
    while position < len(lines):
        line = lines[position]
        if line.startswith("["):
            break
        key, separator, value = line.partition(":")
        if separator:
            state["header"][key.strip()] = clean_text(value, max_length=1000)
        position += 1
    current = None
    while position < len(lines):
        line = lines[position]
        match = _STEP_BLOCK_PATTERN.match(line)
        if match:
            status = match.group(1).strip()
            if status not in KNOWN_STATUSES:
                status = STATUS_PENDING
            current = {
                "name": clean_text(match.group(2)),
                "status": status,
                "started": None,
                "completed": None,
                "failure": None,
            }
            state["steps"].append(current)
        elif current is not None and line.startswith("  ") and not line.startswith("    - "):
            key, separator, value = line.strip().partition(":")
            if separator:
                field = key.strip().lower()
                text = value.strip()
                if field == "started" and text != "-":
                    current["started"] = text
                elif field == "completed" and text != "-":
                    current["completed"] = text
                elif field == "failure" and text != "-":
                    current["failure"] = clean_text(text, max_length=1000)
        position += 1
    return state


def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return parse(handle.read())


def remove_stale_temp_files(directory):
    for stale in glob.glob(os.path.join(directory, ".installation-progress-*")):
        try:
            os.remove(stale)
        except OSError:
            pass


def save(path, state):
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    file_descriptor, temp_path = tempfile.mkstemp(
        prefix=".installation-progress-", suffix=".tmp", dir=directory
    )
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(render(state))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
    except BaseException:
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass
        raise


class FileLock(object):
    def __init__(self, path):
        self.path = path
        self.handle = None
        self.acquired_thread = False
        self.acquired_file = False

    def __enter__(self):
        try:
            self.acquired_thread = _THREAD_LOCK.acquire(timeout=LOCK_TIMEOUT)
        except Exception:
            self.acquired_thread = False
        try:
            self.handle = open(self.path, "a")
        except OSError:
            return self
        deadline = time.time() + LOCK_TIMEOUT
        while True:
            try:
                if msvcrt is not None:
                    self.handle.seek(0)
                    msvcrt.locking(self.handle.fileno(), msvcrt.LK_NBLCK, 1)
                elif fcntl is not None:
                    fcntl.flock(self.handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.acquired_file = True
                return self
            except OSError:
                if time.time() >= deadline:
                    return self
                time.sleep(0.05)

    def __exit__(self, exc_type, exc_value, traceback):
        try:
            if self.handle is not None:
                try:
                    if self.acquired_file:
                        if msvcrt is not None:
                            self.handle.seek(0)
                            msvcrt.locking(self.handle.fileno(), msvcrt.LK_UNLCK, 1)
                        elif fcntl is not None:
                            fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN)
                except OSError:
                    pass
                self.handle.close()
        finally:
            if self.acquired_thread:
                try:
                    _THREAD_LOCK.release()
                except RuntimeError:
                    pass
        return False


class InstallationProgress(object):
    def __init__(self, status_dir):
        self.status_dir = str(status_dir)
        self.path = os.path.join(self.status_dir, LOG_DIR, LOG_FILE)
        self.lock_path = self.path + ".lock"

    def initialize(self, playbook, steps, install_id=None, now=None):
        if not steps:
            raise ValueError("no installation steps to track")
        identifier = str(install_id) if install_id else str(int(time.time()))
        if not re.match(r"^[A-Za-z0-9._-]+$", identifier):
            raise ValueError("invalid installation id: {}".format(identifier))
        ordered = []
        for step in steps:
            name = clean_text(step)
            if name and name not in ordered:
                ordered.append(name)
        if not ordered:
            raise ValueError("no installation steps to track")
        state = {
            "header": {
                "Installation ID": identifier,
                "Playbook": clean_text(playbook),
                "Status directory": clean_text(self.status_dir, max_length=1000),
                "Started": now or now_timestamp(),
                "Status": RESULT_IN_PROGRESS,
            },
            "steps": [
                {
                    "name": name,
                    "status": STATUS_PENDING,
                    "started": None,
                    "completed": None,
                    "failure": None,
                }
                for name in ordered
            ],
        }
        with FileLock(self.lock_path):
            directory = os.path.dirname(self.path) or "."
            os.makedirs(directory, exist_ok=True)
            remove_stale_temp_files(directory)
            save(self.path, state)
        return True

    def update(self, mutator):
        with FileLock(self.lock_path):
            if not os.path.exists(self.path):
                return False
            state = load(self.path)
            applied = mutator(state)
            if applied:
                save(self.path, state)
            return applied

    def start(self, step, now=None):
        name = clean_text(step)
        if not name:
            return False

        def mutate(state):
            current = find_step(state, name)
            timestamp = now or now_timestamp()
            if current is None:
                state["steps"].append(
                    {
                        "name": name,
                        "status": STATUS_RUNNING,
                        "started": timestamp,
                        "completed": None,
                        "failure": None,
                    }
                )
                return True
            if current["status"] == STATUS_PENDING:
                current["status"] = STATUS_RUNNING
                current["started"] = timestamp
                return True
            if current["status"] == STATUS_RUNNING:
                return False
            warn("step '{}' is {} and cannot be started again".format(name, current["status"]))
            return False

        return self.update(mutate)

    def complete(self, step, now=None):
        name = clean_text(step)
        if not name:
            return False

        def mutate(state):
            current = find_step(state, name)
            timestamp = now or now_timestamp()
            if current is None:
                state["steps"].append(
                    {
                        "name": name,
                        "status": STATUS_COMPLETED,
                        "started": None,
                        "completed": timestamp,
                        "failure": None,
                    }
                )
                return True
            if current["status"] in (STATUS_RUNNING, STATUS_PENDING):
                current["status"] = STATUS_COMPLETED
                current["completed"] = timestamp
                return True
            warn("step '{}' is {} and cannot be completed again".format(name, current["status"]))
            return False

        return self.update(mutate)

    def finalize(self, result, now=None):
        if result not in ("success", "failed"):
            raise ValueError("invalid result: {}".format(result))

        def mutate(state):
            header = state["header"]
            running = [step for step in state["steps"] if step["status"] == STATUS_RUNNING]
            if header.get("Status") in (RESULT_SUCCESS, RESULT_FAILED) and not running:
                return False
            timestamp = now or now_timestamp()
            if result == "success":
                for step in running:
                    step["status"] = STATUS_COMPLETED
                    step["completed"] = timestamp
                for step in state["steps"]:
                    if step["status"] == STATUS_PENDING:
                        step["status"] = STATUS_SKIPPED
                header["Status"] = RESULT_SUCCESS
            else:
                detail_log = clean_text(main_log_path(self.status_dir), max_length=1000)
                for step in running:
                    step["status"] = STATUS_FAILED
                    step["completed"] = timestamp
                    step["failure"] = "Step did not complete; see {}".format(detail_log)
                header["Status"] = RESULT_FAILED
                if running:
                    header["Failure"] = "Step '{}' did not complete; see {}".format(
                        running[0]["name"], detail_log
                    )
                elif "Failure" not in header:
                    header["Failure"] = "Deployment failed; see {}".format(detail_log)
            header["Completed"] = timestamp
            return True

        return self.update(mutate)


def find_step(state, name):
    for step in state["steps"]:
        if step["name"] == name:
            return step
    return None


def build_parser():
    parser = argparse.ArgumentParser(
        prog="installation_progress.py",
        description="Maintain the unified installation progress log of Cloud Pak Deployer",
    )
    subparsers = parser.add_subparsers(dest="command")
    subparsers.required = True
    init_parser = subparsers.add_parser("init")
    init_parser.add_argument("--status-dir", required=True)
    init_parser.add_argument("--playbook", required=True)
    init_parser.add_argument("--install-id", default=None)
    for command in ("start", "complete"):
        command_parser = subparsers.add_parser(command)
        command_parser.add_argument("--status-dir", required=True)
        command_parser.add_argument("--step", required=True)
    finalize_parser = subparsers.add_parser("finalize")
    finalize_parser.add_argument("--status-dir", required=True)
    finalize_parser.add_argument("--result", required=True, choices=("success", "failed"))
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    progress = InstallationProgress(args.status_dir)
    try:
        if args.command == "init":
            progress.initialize(args.playbook, planned_steps(args.playbook), install_id=args.install_id)
        elif args.command == "start":
            progress.start(args.step)
        elif args.command == "complete":
            progress.complete(args.step)
        else:
            progress.finalize(args.result)
        return 0
    except Exception as error:
        sys.stderr.write("installation-progress error: {}\n".format(error))
        return 2


if __name__ == "__main__":
    sys.exit(main())
