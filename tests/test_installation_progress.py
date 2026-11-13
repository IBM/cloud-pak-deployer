import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULE_PATH = os.path.join(
    REPO_ROOT,
    "automation-roles",
    "99-generic",
    "deployer",
    "installation-progress",
    "files",
    "installation_progress.py",
)

try:
    import yaml
except ImportError:
    yaml = None


def load_module():
    spec = importlib.util.spec_from_file_location("installation_progress", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ip = load_module()

STEP_10 = "10 - Validate"
STEP_20 = "20 - Prepare"
STEP_30 = "30 - Provision infrastructure"
STEP_40 = "40 - Configure infrastructure"
STEP_50 = "50 - Install Cloud Pak"
STEP_60 = "60 - Configure Cloud Pak"
STEP_70 = "70 - Deploy assets"
STEP_80 = "80 - Smoke tests"

ALL_STEPS = [STEP_10, STEP_20, STEP_30, STEP_40, STEP_50, STEP_60, STEP_70, STEP_80]

T0 = "2026-10-26T10:00:00+00:00"
T1 = "2026-10-26T10:00:01+00:00"
T2 = "2026-10-26T10:00:05+00:00"
T3 = "2026-10-26T10:00:09+00:00"
T4 = "2026-10-26T10:01:09+00:00"


def write_file(path, content):
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(content)


class ProgressTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.status_dir = os.path.join(self.temp_dir.name, "status")
        self.progress = ip.InstallationProgress(self.status_dir)

    def initialize(self, steps=None, install_id="test-run"):
        return self.progress.initialize(
            "playbooks/playbook-env-apply.yml",
            steps if steps is not None else [STEP_10, STEP_20, STEP_30],
            install_id=install_id,
            now=T0,
        )

    def read_raw(self):
        with open(self.progress.path, "r", encoding="utf-8") as handle:
            return handle.read()

    def read_state(self):
        return ip.load(self.progress.path)


class TestTextHandling(ProgressTestCase):
    def test_clean_text_collapses_newlines(self):
        self.assertEqual(ip.clean_text("step one\r\nstep two\tend"), "step one step two end")

    def test_clean_text_masks_secret_values(self):
        cleaned = ip.clean_text("install with password=hunter2 and token: abc123")
        self.assertNotIn("hunter2", cleaned)
        self.assertNotIn("abc123", cleaned)
        self.assertIn("password=***", cleaned)
        self.assertIn("token: ***", cleaned)

    def test_clean_text_masks_identifier_style_secrets(self):
        cleaned = ip.clean_text("cp_entitlement_key=super-secret-value")
        self.assertNotIn("super-secret-value", cleaned)
        self.assertIn("cp_entitlement_key=***", cleaned)

    def test_clean_text_truncates_long_values(self):
        cleaned = ip.clean_text("x" * 500)
        self.assertEqual(len(cleaned), 300)

    def test_duration_formats_seconds(self):
        self.assertEqual(ip.format_duration(T1, T2), "4s")

    def test_duration_formats_minutes(self):
        self.assertEqual(
            ip.format_duration("2026-10-26T10:00:00+00:00", "2026-10-26T10:01:05+00:00"), "1m 5s"
        )

    def test_duration_formats_hours(self):
        self.assertEqual(
            ip.format_duration("2026-10-26T10:00:00+00:00", "2026-10-26T11:01:01+00:00"),
            "1h 1m 1s",
        )

    def test_duration_is_not_negative(self):
        self.assertEqual(ip.format_duration(T2, T1), "0s")

    def test_duration_requires_both_timestamps(self):
        self.assertEqual(ip.format_duration(T1, None), "-")
        self.assertEqual(ip.format_duration(None, T2), "-")
        self.assertEqual(ip.format_duration("-", "-"), "-")

    def test_duration_rejects_timezone_less_timestamps(self):
        self.assertEqual(ip.format_duration("2026-10-26T10:00:00", T1), "-")


class TestPlaybookParsing(unittest.TestCase):
    def stage_playbook_content(self, number, title):
        return (
            "---\n"
            "- name: {} - {}\n"
            "  hosts: localhost\n"
            "  tasks:\n"
            "  - name: dummy task\n"
            "    debug:\n"
            "      msg: hello\n".format(number, title)
        )

    def test_planned_steps_preserve_import_order(self):
        with tempfile.TemporaryDirectory() as directory:
            stage_files = []
            for number, title in (("10", "Validate"), ("20", "Prepare"), ("50", "Install Cloud Pak")):
                filename = "playbook-env-apply-{}-{}.yml".format(number, title.lower().replace(" ", "-"))
                write_file(os.path.join(directory, filename), self.stage_playbook_content(number, title))
                stage_files.append(filename)
            playbook = os.path.join(directory, "playbook-env-apply.yml")
            write_file(playbook, "".join("- import_playbook: {}\n".format(name) for name in stage_files))
            self.assertEqual(ip.planned_steps(playbook), [STEP_10, STEP_20, "50 - Install Cloud Pak"])

    def test_planned_steps_fall_back_to_play_names(self):
        with tempfile.TemporaryDirectory() as directory:
            playbook = os.path.join(directory, "playbook-env-destroy.yml")
            write_file(playbook, self.stage_playbook_content("99", "Destroy"))
            self.assertEqual(ip.planned_steps(playbook), ["99 - Destroy"])

    def test_missing_playbook_raises(self):
        with self.assertRaises(Exception):
            ip.planned_steps(os.path.join(REPO_ROOT, "playbooks", "does-not-exist.yml"))

    def test_repository_apply_playbook_lists_all_stages(self):
        playbook = os.path.join(REPO_ROOT, "playbooks", "playbook-env-apply.yml")
        self.assertEqual(ip.planned_steps(playbook), ALL_STEPS)

    def test_repository_check_only_playbook_lists_two_stages(self):
        playbook = os.path.join(REPO_ROOT, "playbooks", "playbook-env-apply-check-only.yml")
        self.assertEqual(ip.planned_steps(playbook), [STEP_10, STEP_20])

    def test_repository_cp_config_only_playbook_lists_five_stages(self):
        playbook = os.path.join(REPO_ROOT, "playbooks", "playbook-env-apply-cp-config-only.yml")
        self.assertEqual(
            ip.planned_steps(playbook), [STEP_10, STEP_20, STEP_60, STEP_70, STEP_80]
        )

    def test_repository_skip_cp_install_playbook_lists_six_stages(self):
        playbook = os.path.join(REPO_ROOT, "playbooks", "playbook-env-apply-skip-cp-install.yml")
        self.assertEqual(
            ip.planned_steps(playbook), [STEP_10, STEP_20, STEP_30, STEP_40, STEP_50, STEP_80]
        )


class TestInitialization(ProgressTestCase):
    def test_init_writes_header_and_pending_steps(self):
        self.initialize(steps=ALL_STEPS)
        state = self.read_state()
        self.assertEqual(state["header"]["Installation ID"], "test-run")
        self.assertEqual(state["header"]["Playbook"], "playbooks/playbook-env-apply.yml")
        self.assertEqual(state["header"]["Status directory"], self.status_dir)
        self.assertEqual(state["header"]["Started"], T0)
        self.assertEqual(state["header"]["Status"], "IN PROGRESS")
        self.assertEqual([step["name"] for step in state["steps"]], ALL_STEPS)
        self.assertTrue(all(step["status"] == "PENDING" for step in state["steps"]))
        self.assertTrue(all(step["started"] is None for step in state["steps"]))

    def test_init_writes_readable_title_and_statuses(self):
        self.initialize()
        raw = self.read_raw()
        self.assertTrue(raw.startswith("IBM Cloud Pak Deployer - Installation Progress\n"))
        self.assertIn("[PENDING]   10 - Validate", raw)
        self.assertIn("[PENDING]   20 - Prepare", raw)

    def test_init_generates_installation_id_when_not_provided(self):
        self.progress.initialize("playbooks/playbook-env-apply.yml", [STEP_10], now=T0)
        state = self.read_state()
        self.assertTrue(state["header"]["Installation ID"].isdigit())

    def test_init_rejects_invalid_installation_id(self):
        with self.assertRaises(ValueError):
            self.progress.initialize("p.yml", [STEP_10], install_id="bad id\nevil")

    def test_init_requires_steps(self):
        with self.assertRaises(ValueError):
            self.progress.initialize("p.yml", [])

    def test_init_removes_stale_temporary_files(self):
        self.initialize()
        log_dir = os.path.join(self.status_dir, "log")
        stale = os.path.join(log_dir, ".installation-progress-stale.tmp")
        write_file(stale, "leftover")
        self.initialize()
        self.assertFalse(os.path.exists(stale))

    def test_init_overwrites_previous_state(self):
        self.initialize(steps=[STEP_10])
        self.initialize(steps=[STEP_20])
        state = self.read_state()
        self.assertEqual([step["name"] for step in state["steps"]], [STEP_20])


class TestLifecycleTransitions(ProgressTestCase):
    def test_start_transitions_pending_to_running(self):
        self.initialize()
        self.assertTrue(self.progress.start(STEP_10, now=T1))
        state = self.read_state()
        step = state["steps"][0]
        self.assertEqual(step["status"], "RUNNING")
        self.assertEqual(step["started"], T1)
        self.assertIsNone(step["completed"])

    def test_update_is_visible_before_completion(self):
        self.initialize()
        self.progress.start(STEP_10, now=T1)
        raw = self.read_raw()
        self.assertIn("[RUNNING]   10 - Validate", raw)
        self.assertIn("IN PROGRESS", raw)
        self.assertNotIn("[COMPLETED]", raw)

    def test_complete_records_start_and_end_timestamps(self):
        self.initialize()
        self.progress.start(STEP_10, now=T1)
        self.assertTrue(self.progress.complete(STEP_10, now=T2))
        state = self.read_state()
        step = state["steps"][0]
        self.assertEqual(step["status"], "COMPLETED")
        self.assertEqual(step["started"], T1)
        self.assertEqual(step["completed"], T2)
        self.assertIn("Duration:  4s", self.read_raw())

    def test_start_registers_unknown_step(self):
        self.initialize(steps=[STEP_10])
        self.progress.start(STEP_80, now=T1)
        state = self.read_state()
        self.assertEqual(state["steps"][-1]["name"], STEP_80)
        self.assertEqual(state["steps"][-1]["status"], "RUNNING")

    def test_repeated_start_keeps_original_start_time(self):
        self.initialize()
        self.progress.start(STEP_10, now=T1)
        self.assertFalse(self.progress.start(STEP_10, now=T3))
        state = self.read_state()
        self.assertEqual(state["steps"][0]["started"], T1)
        self.assertEqual(state["steps"][0]["status"], "RUNNING")

    def test_start_after_completion_is_ignored(self):
        self.initialize()
        self.progress.start(STEP_10, now=T1)
        self.progress.complete(STEP_10, now=T2)
        self.assertFalse(self.progress.start(STEP_10, now=T3))
        state = self.read_state()
        self.assertEqual(state["steps"][0]["status"], "COMPLETED")
        self.assertEqual(state["steps"][0]["started"], T1)

    def test_complete_after_completion_is_ignored(self):
        self.initialize()
        self.progress.start(STEP_10, now=T1)
        self.progress.complete(STEP_10, now=T2)
        self.assertFalse(self.progress.complete(STEP_10, now=T3))
        state = self.read_state()
        self.assertEqual(state["steps"][0]["completed"], T2)

    def test_finalize_success_marks_running_as_completed_and_unreached_as_skipped(self):
        self.initialize(steps=[STEP_10, STEP_20, STEP_30])
        self.progress.start(STEP_10, now=T1)
        self.progress.complete(STEP_10, now=T2)
        self.progress.start(STEP_20, now=T3)
        self.assertTrue(self.progress.finalize("success", now=T4))
        state = self.read_state()
        self.assertEqual(state["steps"][0]["status"], "COMPLETED")
        self.assertEqual(state["steps"][1]["status"], "COMPLETED")
        self.assertEqual(state["steps"][1]["completed"], T4)
        self.assertEqual(state["steps"][2]["status"], "SKIPPED")
        self.assertEqual(state["header"]["Status"], "SUCCESS")
        self.assertEqual(state["header"]["Completed"], T4)

    def test_finalize_failure_marks_running_step_and_keeps_unknown_steps_pending(self):
        self.initialize(steps=[STEP_10, STEP_20, STEP_30])
        self.progress.start(STEP_10, now=T1)
        self.progress.complete(STEP_10, now=T2)
        self.progress.start(STEP_20, now=T3)
        self.assertTrue(self.progress.finalize("failed", now=T4))
        state = self.read_state()
        failed = state["steps"][1]
        self.assertEqual(failed["status"], "FAILED")
        self.assertEqual(failed["completed"], T4)
        self.assertEqual(state["steps"][2]["status"], "PENDING")
        self.assertEqual(state["header"]["Status"], "FAILED")
        self.assertIn(STEP_20, state["header"]["Failure"])
        main_log = os.path.join(self.status_dir, "log", "cloud-pak-deployer.log")
        self.assertIn(main_log, state["header"]["Failure"])
        self.assertIn(main_log, failed["failure"])
        self.assertIn("Duration:  1m 0s", self.read_raw())

    def test_finalize_failure_without_started_step_reports_overall_failure(self):
        self.initialize(steps=[STEP_10])
        self.progress.finalize("failed", now=T4)
        state = self.read_state()
        self.assertEqual(state["header"]["Status"], "FAILED")
        self.assertIn("Deployment failed", state["header"]["Failure"])
        self.assertEqual(state["steps"][0]["status"], "PENDING")

    def test_finalize_is_idempotent(self):
        self.initialize(steps=[STEP_10])
        self.progress.start(STEP_10, now=T1)
        self.assertTrue(self.progress.finalize("failed", now=T3))
        self.assertFalse(self.progress.finalize("failed", now=T4))
        state = self.read_state()
        self.assertEqual(state["header"]["Completed"], T3)

    def test_finalize_first_result_wins(self):
        self.initialize(steps=[STEP_10])
        self.progress.start(STEP_10, now=T1)
        self.progress.complete(STEP_10, now=T2)
        self.assertTrue(self.progress.finalize("success", now=T3))
        self.assertFalse(self.progress.finalize("failed", now=T4))
        self.assertEqual(self.read_state()["header"]["Status"], "SUCCESS")

    def test_finalize_rejects_unknown_result(self):
        self.initialize(steps=[STEP_10])
        with self.assertRaises(ValueError):
            self.progress.finalize("exploded")

    def test_interrupted_run_leaves_step_running(self):
        self.initialize(steps=[STEP_10, STEP_20])
        self.progress.start(STEP_10, now=T1)
        state = self.read_state()
        self.assertEqual(state["header"]["Status"], "IN PROGRESS")
        self.assertEqual(state["steps"][0]["status"], "RUNNING")
        self.assertIsNone(state["steps"][0]["completed"])
        self.assertEqual(state["steps"][1]["status"], "PENDING")
        self.assertIn("[RUNNING]   10 - Validate", self.read_raw())

    def test_round_trip_preserves_state(self):
        self.initialize(steps=ALL_STEPS)
        self.progress.start(STEP_10, now=T1)
        self.progress.complete(STEP_10, now=T2)
        self.progress.start(STEP_20, now=T3)
        before = self.read_state()
        after = ip.parse(self.read_raw())
        self.assertEqual(before, after)


class TestLogPaths(ProgressTestCase):
    def touch(self, *parts):
        path = os.path.join(self.status_dir, *parts)
        write_file(path, "log content\n")
        return path

    def test_existing_component_logs_are_listed_without_marker(self):
        self.initialize(steps=[STEP_10])
        main_log = self.touch("log", "cloud-pak-deployer.log")
        activity_log = self.touch("log", "deployer-activities.log")
        self.progress.start(STEP_10, now=T1)
        raw = self.read_raw()
        self.assertIn(main_log, raw)
        self.assertIn(activity_log, raw)
        self.assertNotIn(main_log + " " + ip.NOT_CREATED, raw)

    def test_missing_component_logs_are_marked_not_created(self):
        self.initialize(steps=[STEP_10])
        self.progress.start(STEP_10, now=T1)
        raw = self.read_raw()
        main_log = os.path.join(self.status_dir, "log", "cloud-pak-deployer.log")
        activity_log = os.path.join(self.status_dir, "log", "deployer-activities.log")
        self.assertIn(main_log + " " + ip.NOT_CREATED, raw)
        self.assertIn(activity_log + " " + ip.NOT_CREATED, raw)

    def test_stage_specific_log_paths_are_associated(self):
        self.initialize(steps=[STEP_10, STEP_30, STEP_50])
        terraform_log = self.touch("terraform", "plan.log")
        mirror_log = self.touch("log", "cloud-pak-mirror-images.log")
        self.progress.start(STEP_30, now=T1)
        self.progress.start(STEP_50, now=T1)
        raw = self.read_raw()
        self.assertIn(terraform_log, raw)
        self.assertNotIn(terraform_log + " " + ip.NOT_CREATED, raw)
        self.assertIn(mirror_log, raw)
        state = self.read_state()
        step30_block = self.block_for(raw, STEP_30)
        step50_block = self.block_for(raw, STEP_50)
        self.assertIn(terraform_log, step30_block)
        self.assertNotIn(mirror_log, step30_block)
        self.assertIn(mirror_log, step50_block)
        self.assertNotIn(terraform_log, step50_block)
        self.assertEqual(state["steps"][1]["name"], STEP_30)

    def test_log_directory_is_listed_for_every_step(self):
        self.initialize(steps=[STEP_10, STEP_20])
        raw = self.read_raw()
        log_dir = os.path.join(self.status_dir, "log")
        blocks = raw.split("[PENDING]")
        for block in blocks[1:]:
            self.assertIn(log_dir + " " + ip.DIRECTORY_MARKER, block)

    def test_missing_log_directory_is_marked_not_created(self):
        rendered = ip.render(
            {
                "header": {"Status directory": os.path.join(self.temp_dir.name, "absent")},
                "steps": [
                    {"name": STEP_10, "status": "PENDING", "started": None, "completed": None, "failure": None}
                ],
            }
        )
        log_dir = os.path.join(self.temp_dir.name, "absent", "log")
        self.assertIn(log_dir + " " + ip.NOT_CREATED, rendered)

    def block_for(self, raw, step_name):
        collecting = False
        collected = []
        for line in raw.splitlines():
            if line.startswith("["):
                if collecting:
                    break
                collecting = step_name in line
            if collecting:
                collected.append(line)
        return "\n".join(collected)


class TestRedaction(ProgressTestCase):
    def test_step_names_are_sanitized_on_start(self):
        self.initialize(steps=[STEP_10])
        self.progress.start("50 - Install password=hunter2\n[FAKE] injected", now=T1)
        state = self.read_state()
        name = state["steps"][-1]["name"]
        self.assertNotIn("hunter2", name)
        self.assertNotIn("\n", name)
        self.assertIn("password=***", name)
        self.assertEqual(state["steps"][-1]["status"], "RUNNING")

    def test_failure_details_mask_secrets_found_in_paths(self):
        odd_dir = os.path.join(self.temp_dir.name, "password=hunter2")
        progress = ip.InstallationProgress(odd_dir)
        progress.initialize("p.yml", [STEP_10], install_id="run-1", now=T0)
        progress.start(STEP_10, now=T1)
        self.assertTrue(progress.finalize("failed", now=T3))
        state = ip.load(progress.path)
        failure = state["header"]["Failure"]
        self.assertNotIn("hunter2", failure)
        self.assertIn("password=***", failure)
        self.assertTrue(failure.startswith("Step '10 - Validate' did not complete; see "))
        self.assertNotIn("hunter2", state["header"]["Status directory"])


class TestConcurrency(ProgressTestCase):
    def test_parallel_updates_keep_the_file_consistent(self):
        steps = ["10 - Step {:02d}".format(index) for index in range(12)]
        self.initialize(steps=steps)
        errors = []

        def worker(step):
            try:
                local = ip.InstallationProgress(self.status_dir)
                local.start(step, now=T1)
                local.complete(step, now=T2)
            except Exception as error:
                errors.append(error)

        threads = [threading.Thread(target=worker, args=(step,)) for step in steps]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=30)
        self.assertEqual(errors, [])
        state = self.read_state()
        self.assertEqual([step["name"] for step in state["steps"]], steps)
        for step in state["steps"]:
            self.assertEqual(step["status"], "COMPLETED", step["name"])
            self.assertEqual(step["started"], T1, step["name"])
            self.assertEqual(step["completed"], T2, step["name"])


class TestCli(ProgressTestCase):
    def run_cli(self, *arguments):
        return ip.main(list(arguments))

    def test_start_without_progress_log_is_a_no_op(self):
        code = self.run_cli("start", "--status-dir", self.status_dir, "--step", STEP_10)
        self.assertEqual(code, 0)
        self.assertFalse(os.path.exists(self.progress.path))

    def test_finalize_without_progress_log_is_a_no_op(self):
        code = self.run_cli("finalize", "--status-dir", self.status_dir, "--result", "failed")
        self.assertEqual(code, 0)
        self.assertFalse(os.path.exists(self.progress.path))

    def test_init_with_missing_playbook_returns_error_code(self):
        code = self.run_cli(
            "init",
            "--status-dir", self.status_dir,
            "--playbook", os.path.join(self.temp_dir.name, "missing.yml"),
        )
        self.assertEqual(code, 2)
        self.assertFalse(os.path.exists(self.progress.path))

    def test_init_via_cli_creates_progress_log(self):
        playbook = os.path.join(self.temp_dir.name, "playbook.yml")
        write_file(playbook, "- import_playbook: stage.yml\n")
        write_file(
            os.path.join(self.temp_dir.name, "stage.yml"),
            "- name: 10 - Validate\n  hosts: localhost\n  tasks: []\n",
        )
        code = self.run_cli(
            "init", "--status-dir", self.status_dir, "--playbook", playbook, "--install-id", "cli-run"
        )
        self.assertEqual(code, 0)
        state = self.read_state()
        self.assertEqual(state["header"]["Installation ID"], "cli-run")
        self.assertEqual(state["steps"][0]["name"], STEP_10)


class TestFullRunSimulation(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.status_dir = os.path.join(self.temp_dir.name, "status")
        self.playbook = os.path.join(REPO_ROOT, "playbooks", "playbook-env-apply.yml")

    def run_module(self, *arguments):
        completed = subprocess.run(
            [sys.executable, MODULE_PATH] + list(arguments),
            capture_output=True,
            text=True,
            timeout=60,
        )
        return completed

    def read_raw(self):
        path = os.path.join(self.status_dir, "log", "installation-progress.log")
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()

    def test_successful_run_reports_all_stages_completed(self):
        init = self.run_module("init", "--status-dir", self.status_dir, "--playbook", self.playbook)
        self.assertEqual(init.returncode, 0, init.stderr)
        raw = self.read_raw()
        for name in ALL_STEPS:
            self.assertIn("[PENDING]   " + name, raw)
        for name in ALL_STEPS:
            started = self.run_module("start", "--status-dir", self.status_dir, "--step", name)
            self.assertEqual(started.returncode, 0, started.stderr)
            completed = self.run_module("complete", "--status-dir", self.status_dir, "--step", name)
            self.assertEqual(completed.returncode, 0, completed.stderr)
        finalize = self.run_module(
            "finalize", "--status-dir", self.status_dir, "--result", "success"
        )
        self.assertEqual(finalize.returncode, 0, finalize.stderr)
        raw = self.read_raw()
        for name in ALL_STEPS:
            self.assertIn("[COMPLETED] " + name, raw)
            self.assertIn("  Logs:", raw)
        self.assertIn("Status          : SUCCESS", raw)
        self.assertIn(os.path.join(self.status_dir, "log"), raw)

    def test_failed_run_reports_running_step_failed_and_pending_steps_unchanged(self):
        self.run_module("init", "--status-dir", self.status_dir, "--playbook", self.playbook)
        self.run_module("start", "--status-dir", self.status_dir, "--step", STEP_10)
        self.run_module("complete", "--status-dir", self.status_dir, "--step", STEP_10)
        running = self.run_module("start", "--status-dir", self.status_dir, "--step", STEP_20)
        self.assertEqual(running.returncode, 0, running.stderr)
        raw = self.read_raw()
        self.assertIn("[RUNNING]   20 - Prepare", raw)
        self.assertIn("[COMPLETED] 10 - Validate", raw)
        self.assertIn("[PENDING]   30 - Provision infrastructure", raw)
        failed = self.run_module(
            "finalize", "--status-dir", self.status_dir, "--result", "failed"
        )
        self.assertEqual(failed.returncode, 0, failed.stderr)
        raw = self.read_raw()
        self.assertIn("[FAILED]    20 - Prepare", raw)
        self.assertIn("Status          : FAILED", raw)
        self.assertIn("[PENDING]   30 - Provision infrastructure", raw)
        self.assertIn("Failure", raw)
        self.assertIn(os.path.join(self.status_dir, "log", "cloud-pak-deployer.log"), raw)


class TestIntegrationSafety(unittest.TestCase):
    def read_repo_file(self, *parts):
        path = os.path.join(REPO_ROOT, *parts)
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()

    def test_role_never_fails_the_deployment(self):
        content = self.read_repo_file(
            "automation-roles", "99-generic", "deployer", "installation-progress", "tasks", "main.yml"
        )
        self.assertIn("failed_when: false", content)
        self.assertIn("changed_when: false", content)
        self.assertIn("installation_progress.py", content)

    def test_run_automation_initializes_and_finalizes_progress(self):
        content = self.read_repo_file("docker-scripts", "run_automation.sh")
        self.assertIn("installation_progress.py init", content)
        self.assertIn("installation_progress.py finalize", content)
        self.assertIn("PLAYBOOK_FILE=", content)
        self.assertIn('PLAYBOOK_FILE="playbooks/playbook-env-apply.yml"', content)
        self.assertIn('PLAYBOOK_FILE="playbooks/playbook-env-apply-check-only.yml"', content)
        self.assertIn('PLAYBOOK_FILE="playbooks/playbook-env-apply-skip-cp-install.yml"', content)
        self.assertIn('PLAYBOOK_FILE="playbooks/playbook-env-apply-cp-config-only.yml"', content)
        self.assertIn("playbooks/playbook-env-destroy.yml", content)
        self.assertIn("playbooks/playbook-env-download.yml", content)
        self.assertIn("installation-progress.log", content)

    @unittest.skipUnless(shutil.which("bash"), "bash is not available")
    def test_shell_scripts_parse(self):
        for script in ("docker-scripts/run_automation.sh", "cp-deploy.sh"):
            with open(os.path.join(REPO_ROOT, script), "r", encoding="utf-8") as handle:
                content = handle.read().replace("\r\n", "\n")
            completed = subprocess.run(
                ["bash", "-n"],
                input=content.encode("utf-8"),
                capture_output=True,
                timeout=60,
            )
            stderr = completed.stderr.decode("utf-8", "replace")
            self.assertEqual(completed.returncode, 0, script + ": " + stderr)

    @unittest.skipUnless(yaml is not None, "PyYAML is not available")
    def test_yaml_files_parse(self):
        files = [
            os.path.join("playbooks", "playbook-env-apply-{}.yml".format(number))
            for number in ("10-validate", "20-prepare", "30-provision-infra", "40-configure-infra",
                           "50-install-cloud-pak", "60-configure-cloud-pak", "70-deploy-assets",
                           "80-smoke-tests")
        ]
        files.append(os.path.join("automation-roles", "99-generic", "deployer", "installation-progress", "tasks", "main.yml"))
        for relative in files:
            with open(os.path.join(REPO_ROOT, relative), "r", encoding="utf-8") as handle:
                documents = list(yaml.safe_load_all(handle))
            self.assertTrue(documents, relative)

    @unittest.skipUnless(yaml is not None, "PyYAML is not available")
    def test_stage_playbooks_have_start_and_complete_hooks(self):
        expectations = {
            "10-validate": STEP_10,
            "20-prepare": STEP_20,
            "30-provision-infra": STEP_30,
            "40-configure-infra": STEP_40,
            "50-install-cloud-pak": STEP_50,
            "60-configure-cloud-pak": STEP_60,
            "70-deploy-assets": STEP_70,
            "80-smoke-tests": STEP_80,
        }
        for suffix, step_name in expectations.items():
            path = os.path.join(REPO_ROOT, "playbooks", "playbook-env-apply-{}.yml".format(suffix))
            with open(path, "r", encoding="utf-8") as handle:
                plays = yaml.safe_load(handle)
            starts = []
            completes = []
            for play in plays:
                for task in play.get("pre_tasks", []):
                    self.assertEqual(task.get("include_role", {}).get("name"), "installation-progress")
                    self.assertEqual(task.get("vars", {}).get("_p_progress_step"), step_name)
                    starts.append(task.get("vars", {}).get("_p_progress_action"))
                for task in play.get("post_tasks", []):
                    self.assertEqual(task.get("include_role", {}).get("name"), "installation-progress")
                    self.assertEqual(task.get("vars", {}).get("_p_progress_step"), step_name)
                    completes.append(task.get("vars", {}).get("_p_progress_action"))
            self.assertEqual(starts, ["start"], suffix)
            self.assertEqual(completes, ["complete"], suffix)

    @unittest.skipUnless(shutil.which("ansible-playbook"), "ansible-playbook is not available")
    def test_apply_playbook_syntax_check(self):
        environment = dict(os.environ)
        environment["ANSIBLE_CALLBACKS_ENABLED"] = ""
        environment["ANSIBLE_NOCOLOR"] = "1"
        completed = subprocess.run(
            ["ansible-playbook", "--syntax-check", "-i", "localhost,", "playbooks/playbook-env-apply.yml"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=120,
            env=environment,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)


if __name__ == "__main__":
    unittest.main()
