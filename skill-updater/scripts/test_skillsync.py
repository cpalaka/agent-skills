import json
import os
from pathlib import Path
import pytest
import skillsync


def test_load_trusted_config(tmp_path):
    cfg = tmp_path / "trusted-sources.json"
    cfg.write_text(json.dumps({"marketplaces": ["claude-plugins-official"],
                               "repos": ["anthropics/*", "vercel-labs/*"]}))
    marketplaces, repos = skillsync.load_trusted_config(cfg)
    assert marketplaces == ["claude-plugins-official"]
    assert repos == ["anthropics/*", "vercel-labs/*"]


def test_is_trusted_marketplace():
    assert skillsync.is_trusted_marketplace("claude-plugins-official", ["claude-plugins-official"])
    assert not skillsync.is_trusted_marketplace("karpathy-skills", ["claude-plugins-official"])


def test_is_trusted_repo_glob():
    repos = ["anthropics/*", "vercel-labs/*"]
    assert skillsync.is_trusted_repo("anthropics/skills", repos)
    assert skillsync.is_trusted_repo("vercel-labs/agent-skills", repos)
    assert not skillsync.is_trusted_repo("mattpocock/skills", repos)


def test_decide_plugin_update_version_bumped():
    upd, label = skillsync.decide_plugin_update("1.0.0", "abc", "1.1.0", "./")
    assert upd is True
    assert label == "1.1.0"


def test_decide_plugin_update_version_same():
    upd, label = skillsync.decide_plugin_update("2.0.0", None, "2.0.0", "./plugins/x")
    assert upd is False
    assert label is None


def test_decide_plugin_update_sha_pinned_changed():
    # superpowers case: manifest has no version, pins a sha
    src = {"source": "url", "url": "https://github.com/obra/superpowers.git",
           "sha": "f2cbfbefebbfef77321e4c9abc9e949826bea9d7"}
    upd, label = skillsync.decide_plugin_update(
        "5.1.0", "917e5f53b16b115b70a3a355ed5f4993b9f8b73d", None, src)
    assert upd is True
    assert label == "f2cbfbefebbf"  # first 12 chars of the new sha


def test_decide_plugin_update_sha_pinned_same():
    src = {"source": "url", "url": "https://x.git", "sha": "deadbeef" * 5}
    upd, label = skillsync.decide_plugin_update("0", "deadbeef" * 5, None, src)
    assert upd is False
    assert label is None


def test_find_manifest_entry():
    manifest = {"plugins": [{"name": "a", "version": "1"}, {"name": "b", "version": "2"}]}
    assert skillsync.find_manifest_entry(manifest, "b") == {"name": "b", "version": "2"}
    assert skillsync.find_manifest_entry(manifest, "z") is None
    assert skillsync.find_manifest_entry(None, "a") is None


def test_skill_folder_from_path():
    assert skillsync.skill_folder_from_path("skills/productivity/caveman/SKILL.md") == "skills/productivity/caveman"
    assert skillsync.skill_folder_from_path("SKILL.md") == ""


def test_plugin_update_cmd():
    assert skillsync.plugin_update_cmd("superpowers@claude-plugins-official") == [
        "claude", "plugin", "update", "superpowers@claude-plugins-official", "--scope", "user"]


def test_skills_update_cmd():
    assert skillsync.skills_update_cmd(["caveman", "tdd"]) == [
        "npx", "skills@latest", "update", "caveman", "tdd", "-g", "-y"]


def test_repo_from_url():
    assert skillsync.repo_from_url("https://github.com/mattpocock/skills.git") == "mattpocock/skills"
    assert skillsync.repo_from_url("https://github.com/vercel-labs/agent-skills") == "vercel-labs/agent-skills"


def test_group_skills_by_repo_skips_legacy():
    lock_skills = {
        "caveman": {"sourceUrl": "https://github.com/mattpocock/skills.git",
                    "skillPath": "skills/productivity/caveman/SKILL.md"},
        "tdd": {"sourceUrl": "https://github.com/mattpocock/skills.git",
                "skillPath": "skills/engineering/tdd/SKILL.md"},
        "legacy": {"source": "x/y"},  # no skillPath/sourceUrl -> skipped
    }
    groups = skillsync.group_skills_by_repo(lock_skills)
    assert set(groups.keys()) == {"https://github.com/mattpocock/skills.git"}
    items = sorted(groups["https://github.com/mattpocock/skills.git"])
    assert ("caveman", "skills/productivity/caveman", None) in items
    assert ("tdd", "skills/engineering/tdd", None) in items


def test_diff_dirs_identical(tmp_path):
    a = tmp_path / "a"; b = tmp_path / "b"
    a.mkdir(); b.mkdir()
    (a / "SKILL.md").write_text("hello\n")
    (b / "SKILL.md").write_text("hello\n")
    changed, diffstat, full = skillsync.diff_dirs(a, b)
    assert changed is False
    assert full == ""


def test_diff_dirs_changed(tmp_path):
    local = tmp_path / "local"; up = tmp_path / "up"
    local.mkdir(); up.mkdir()
    (local / "SKILL.md").write_text("old line\n")
    (up / "SKILL.md").write_text("old line\nnew line\n")
    changed, diffstat, full = skillsync.diff_dirs(up, local)
    assert changed is True
    assert "1 file" in diffstat
    assert "+1" in diffstat
    assert "new line" in full


import subprocess as _sp


def _make_local_repo(root):
    """Create a git repo at root with two skill folders; return its path."""
    root.mkdir(parents=True, exist_ok=True)
    (root / "skills/eng/tdd").mkdir(parents=True)
    (root / "skills/prod/caveman").mkdir(parents=True)
    (root / "skills/eng/tdd/SKILL.md").write_text("tdd v2\n")
    (root / "skills/prod/caveman/SKILL.md").write_text("caveman v2\n")
    env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t", "PATH": os.environ["PATH"]}
    _sp.run(["git", "init", "-q"], cwd=root, check=True, env=env)
    _sp.run(["git", "add", "-A"], cwd=root, check=True, env=env)
    _sp.run(["git", "commit", "-qm", "init"], cwd=root, check=True, env=env)
    return root


def test_clone_skill_folders(tmp_path):
    remote = _make_local_repo(tmp_path / "remote")
    dest = tmp_path / "dest"
    skillsync.clone_skill_folders(str(remote), ["skills/eng/tdd", "skills/prod/caveman"], None, dest)
    assert (dest / "skills/eng/tdd/SKILL.md").read_text() == "tdd v2\n"
    assert (dest / "skills/prod/caveman/SKILL.md").read_text() == "caveman v2\n"


def test_clone_skill_folders_rejects_flag_smuggling(tmp_path):
    # Untrusted lock-file values starting with "-" must be refused before git runs.
    dest = tmp_path / "dest"
    with pytest.raises(ValueError):
        skillsync.clone_skill_folders("--upload-pack=touch /tmp/pwned", ["skills/eng/tdd"], None, dest)
    with pytest.raises(ValueError):
        skillsync.clone_skill_folders("https://github.com/x/y.git", ["--evil"], None, dest)
    with pytest.raises(ValueError):
        skillsync.clone_skill_folders("https://github.com/x/y.git", ["skills/eng/tdd"], "-bad", dest)
    assert not dest.exists()  # nothing was cloned


def test_detect_skills_refuses_flagged_folder_before_any_network_call(monkeypatch, tmp_path):
    # detect runs on every invocation and reaches git by its own two-step route, so the
    # guard in clone_skill_folders does not cover it. An option-shaped folder from the
    # untrusted lock file must be refused before the fetch, and reported rather than
    # aborting the run for every other repo.
    reached_network = []
    monkeypatch.setattr(skillsync, "clone_no_checkout",
                        lambda *a, **k: reached_network.append(a))
    monkeypatch.setattr(skillsync, "local_edit_status", lambda name, entry: (None, None, None))
    lock = tmp_path / "lock.json"
    lock.write_text(json.dumps({"skills": {
        "evil": {"sourceUrl": "https://github.com/x/y.git",
                 "skillPath": "--upload-pack=touch /tmp/pwned/SKILL.md"},
    }}))
    monkeypatch.setattr(skillsync, "SKILL_LOCK", lock)
    report = {"plugins": [], "skills": [], "newSkills": [], "errors": []}
    skillsync.detect_skills(report, [])
    assert reached_network == []
    assert len(report["errors"]) == 1
    assert "unsafe folder" in report["errors"][0]


def _make_root_skill_repo(root):
    """Create a git repo whose skill IS the whole repo (SKILL.md at root + a subdir)."""
    root.mkdir(parents=True, exist_ok=True)
    (root / "SKILL.md").write_text("root skill v1\n")
    (root / "references").mkdir()
    (root / "references/guide.md").write_text("guide body\n")
    env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t", "PATH": os.environ["PATH"]}
    _sp.run(["git", "init", "-q"], cwd=root, check=True, env=env)
    _sp.run(["git", "add", "-A"], cwd=root, check=True, env=env)
    _sp.run(["git", "commit", "-qm", "init"], cwd=root, check=True, env=env)
    return root


def test_diff_dirs_ignores_git_metadata(tmp_path):
    # A fresh clone carries a .git/ dir the local install lacks; it must not count as a diff.
    up = tmp_path / "up"; local = tmp_path / "local"
    up.mkdir(); local.mkdir()
    (up / "SKILL.md").write_text("same\n")
    (local / "SKILL.md").write_text("same\n")
    (up / ".git").mkdir()
    (up / ".git/HEAD").write_text("ref: refs/heads/main\n")
    changed, _stat, full = skillsync.diff_dirs(up, local)
    assert changed is False
    assert full == ""


def test_clone_root_skill_materializes_subtree(tmp_path):
    # skillPath "SKILL.md" -> folder "" (whole repo is the skill): the full subtree must check out.
    remote = _make_root_skill_repo(tmp_path / "remote")
    dest = tmp_path / "dest"
    skillsync.clone_skill_folders(str(remote), [""], None, dest)
    assert (dest / "SKILL.md").read_text() == "root skill v1\n"
    assert (dest / "references/guide.md").read_text() == "guide body\n"


def test_root_skill_no_false_positive(tmp_path):
    # End-to-end regression for the design-doc-mermaid bug: an up-to-date root skill
    # (local byte-identical to upstream HEAD) must report no change.
    remote = _make_root_skill_repo(tmp_path / "remote")
    dest = tmp_path / "dest"
    skillsync.clone_skill_folders(str(remote), [""], None, dest)
    local = tmp_path / "local"
    local.mkdir()
    (local / "SKILL.md").write_text("root skill v1\n")
    (local / "references").mkdir()
    (local / "references/guide.md").write_text("guide body\n")
    changed, _stat, full = skillsync.diff_dirs(dest, local)
    assert changed is False, full


def test_detect_plugins_version_and_sha(tmp_path, monkeypatch):
    # Fixture installed_plugins.json
    installed = {"version": 2, "plugins": {
        "superpowers@claude-plugins-official": [
            {"version": "5.1.0", "gitCommitSha": "917e5f53b16b115b70a3a355ed5f4993b9f8b73d"}],
        "obsidian@obsidian-skills": [{"version": "1.0.1", "gitCommitSha": "ac93"}],
    }}
    inst_path = tmp_path / "installed_plugins.json"
    inst_path.write_text(json.dumps(installed))

    # Fixture marketplaces dir with two manifests
    mk = tmp_path / "marketplaces"
    (mk / "claude-plugins-official/.claude-plugin").mkdir(parents=True)
    (mk / "claude-plugins-official/.claude-plugin/marketplace.json").write_text(json.dumps(
        {"plugins": [{"name": "superpowers", "version": None,
                      "source": {"source": "url", "url": "https://github.com/obra/superpowers.git",
                                 "sha": "f2cbfbefebbfef77321e4c9abc9e949826bea9d7"}}]}))
    (mk / "obsidian-skills/.claude-plugin").mkdir(parents=True)
    (mk / "obsidian-skills/.claude-plugin/marketplace.json").write_text(json.dumps(
        {"plugins": [{"name": "obsidian", "version": "1.0.1", "source": "./"}]}))

    monkeypatch.setattr(skillsync, "PLUGINS_INSTALLED", inst_path)
    monkeypatch.setattr(skillsync, "MARKETPLACES_DIR", mk)

    report = {"plugins": [], "skills": [], "errors": []}
    skillsync.detect_plugins(report, ["claude-plugins-official"])

    by_id = {p["id"]: p for p in report["plugins"]}
    sp = by_id["superpowers@claude-plugins-official"]
    assert sp["updateAvailable"] is True
    assert sp["availableLabel"] == "f2cbfbefebbf"
    assert sp["trusted"] is True
    ob = by_id["obsidian@obsidian-skills"]
    assert ob["updateAvailable"] is False
    assert ob["trusted"] is False


def test_main_apply_plugin_invokes_cmd(monkeypatch):
    calls = []
    monkeypatch.setattr(skillsync.subprocess, "run", lambda cmd, **k: calls.append(cmd) or type("R", (), {"returncode": 0})())
    rc = skillsync.main(["apply-plugin", "superpowers@claude-plugins-official"])
    assert rc == 0
    assert calls[-1] == ["claude", "plugin", "update", "superpowers@claude-plugins-official", "--scope", "user"]


def test_main_detect_prints_json(monkeypatch, capsys, tmp_path):
    cfg = tmp_path / "trusted-sources.json"
    cfg.write_text(json.dumps({"marketplaces": [], "repos": []}))
    monkeypatch.setattr(skillsync, "PLUGINS_INSTALLED", tmp_path / "none.json")
    monkeypatch.setattr(skillsync, "SKILL_LOCK", tmp_path / "none-lock.json")
    monkeypatch.setattr(skillsync, "CLAUDE_SKILLS_DIR", tmp_path / "no-claude")
    monkeypatch.setattr(skillsync, "AGENT_SKILLS_DIR", tmp_path / "no-agents")
    rc = skillsync.main(["detect", "--config", str(cfg)])
    assert rc == 0
    out = json.loads(capsys.readouterr().out)
    assert out["plugins"] == [] and out["skills"] == [] and out["errors"] == []
    assert set(out) == {"plugins", "skills", "newSkills", "previouslyRemoved",
                        "personalRepos", "brokenLinks", "errors"}


# local_edit_status: one test per return arm. Step 2 of SKILL.md auto-applies only the
# "clean" arm (False with no note); None and False-with-note are held back as unverified.
def test_local_edit_status_no_baseline_is_none(monkeypatch):
    monkeypatch.setattr(skillsync, "local_tree_hash", lambda d: "a" * 40)
    entry = {"skillPath": "skills/x/SKILL.md"}  # legacy row: no skillFolderHash
    assert skillsync.local_edit_status("x", entry) == ("a" * 40, None, None)


def test_local_edit_status_root_repo_is_false_with_note(monkeypatch):
    monkeypatch.setattr(skillsync, "local_tree_hash", lambda d: "a" * 40)
    entry = {"skillPath": "SKILL.md", "skillFolderHash": "b" * 40}
    lhash, edited, note = skillsync.local_edit_status("x", entry)
    assert (lhash, edited) == ("a" * 40, False)
    assert "not applicable" in note


def test_local_edit_status_unhashable_local_is_none(monkeypatch):
    monkeypatch.setattr(skillsync, "local_tree_hash", lambda d: None)
    entry = {"skillPath": "skills/x/SKILL.md", "skillFolderHash": "b" * 40}
    assert skillsync.local_edit_status("x", entry) == (None, None, None)


def test_local_edit_status_clean_is_false_without_note(monkeypatch):
    monkeypatch.setattr(skillsync, "local_tree_hash", lambda d: "b" * 40)
    entry = {"skillPath": "skills/x/SKILL.md", "skillFolderHash": "b" * 40}
    assert skillsync.local_edit_status("x", entry) == ("b" * 40, False, None)


def test_local_edit_status_edited_is_true(monkeypatch):
    monkeypatch.setattr(skillsync, "local_tree_hash", lambda d: "a" * 40)
    entry = {"skillPath": "skills/x/SKILL.md", "skillFolderHash": "b" * 40}
    assert skillsync.local_edit_status("x", entry) == ("a" * 40, True, None)


# ---------- plugins the old engine misread ----------
def test_decide_plugin_update_unknowable_is_none_not_false():
    # No version anywhere and no pinned sha: "no update" would be a guess.
    assert skillsync.decide_plugin_update("1.0.0", None, None, "./plugins/x") == (None, None)


def _plugin_fixture(tmp_path, monkeypatch, installed, manifest_plugins, marketplace="mkt"):
    inst = tmp_path / "installed_plugins.json"
    inst.write_text(json.dumps({"version": 2, "plugins": installed}))
    mk = tmp_path / "marketplaces"
    (mk / marketplace / ".claude-plugin").mkdir(parents=True)
    (mk / marketplace / ".claude-plugin/marketplace.json").write_text(
        json.dumps({"plugins": manifest_plugins}))
    monkeypatch.setattr(skillsync, "PLUGINS_INSTALLED", inst)
    monkeypatch.setattr(skillsync, "MARKETPLACES_DIR", mk)
    return mk / marketplace


def test_detect_plugins_directory_managed_is_listed_not_an_error(tmp_path, monkeypatch):
    # Installed from the plugin directory: no local marketplace clone exists to read.
    _plugin_fixture(tmp_path, monkeypatch, {"hookify@plugin-directory": [
        {"version": "0.1.1-abc", "lastUpdated": "2026-11-06T04:50:00.640Z",
         "directoryRepositoryKey": "github.com/x/y#plugins/hookify"}]}, [])
    report = {"plugins": [], "errors": []}
    skillsync.detect_plugins(report, [])
    assert report["errors"] == []
    p = report["plugins"][0]
    assert p["updateAvailable"] is None and p["action"] == "none"
    assert "directory-managed" in p["note"] and "2026-11-06" in p["note"]


def test_detect_plugins_reads_version_from_relative_source(tmp_path, monkeypatch):
    # The marketplace row carries no version; the plugin's own plugin.json does.
    root = _plugin_fixture(tmp_path, monkeypatch, {"a@mkt": [{"version": "1.0.0"}]},
                           [{"name": "a", "source": "./plugins/a"}])
    (root / "plugins/a/.claude-plugin").mkdir(parents=True)
    (root / "plugins/a/.claude-plugin/plugin.json").write_text(json.dumps({"version": "1.2.0"}))
    report = {"plugins": [], "errors": []}
    skillsync.detect_plugins(report, ["mkt"])
    p = report["plugins"][0]
    assert p["updateAvailable"] is True and p["availableLabel"] == "1.2.0" and p["action"] == "auto"


def test_detect_plugins_unknown_community_needs_a_person(tmp_path, monkeypatch):
    _plugin_fixture(tmp_path, monkeypatch, {"a@mkt": [{"version": "1.0.0"}]},
                    [{"name": "a", "source": "./plugins/a"}])
    report = {"plugins": [], "errors": []}
    skillsync.detect_plugins(report, [])
    p = report["plugins"][0]
    assert p["updateAvailable"] is None and p["action"] == "confirm"


# ---------- action: the one place the apply policy lives ----------
@pytest.mark.parametrize("kw,expected", [
    (dict(update=False, upstream="present", trusted=True, edited=False, note=None), "none"),
    (dict(update=True, upstream="present", trusted=True, edited=False, note=None), "auto"),
    (dict(update=True, upstream="present", trusted=False, edited=False, note=None), "confirm"),
    # Trust says the upstream is safe, not that the local edit is expendable.
    (dict(update=True, upstream="present", trusted=True, edited=True, note=None), "hold-edited"),
    (dict(update=True, upstream="present", trusted=True, edited=None, note=None), "hold-unverified"),
    (dict(update=True, upstream="present", trusted=True, edited=False,
          note="root-repo skill — local-edit check not applicable"), "hold-unverified"),
    (dict(update=False, upstream="moved", trusted=True, edited=False, note=None), "confirm"),
    # A reinstall to follow a move destroys an edit exactly as an update does.
    (dict(update=True, upstream="moved", trusted=True, edited=True, note=None), "hold-edited"),
    (dict(update=False, upstream="removed", trusted=True, edited=True, note=None), "confirm"),
])
def test_skill_action(kw, expected):
    assert skillsync.skill_action(**kw) == expected


# ---------- stale folder vs hand edit ----------
def _git(root, *args):
    env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
           "GIT_COMMITTER_EMAIL": "t@t", "PATH": os.environ["PATH"]}
    return _sp.run(["git", *args], cwd=root, check=True, env=env,
                   capture_output=True, text=True).stdout.strip()


def _repo_with_two_versions(root):
    """A skill at skills/s with v1 then v2. Returns (v1 tree hash, v2 tree hash)."""
    (root / "skills/s").mkdir(parents=True)
    (root / "skills/s/SKILL.md").write_text("v1\n")
    _git(root, "init", "-q")
    _git(root, "add", "-A"); _git(root, "commit", "-qm", "v1")
    v1 = _git(root, "rev-parse", "HEAD:skills/s")
    (root / "skills/s/SKILL.md").write_text("v2\n")
    _git(root, "add", "-A"); _git(root, "commit", "-qm", "v2")
    return v1, _git(root, "rev-parse", "HEAD:skills/s")


def test_upstream_version_matching_finds_an_old_tree(tmp_path):
    remote = tmp_path / "remote"
    v1, v2 = _repo_with_two_versions(remote)
    assert skillsync.upstream_version_matching(f"file://{remote}", None, "skills/s", v1)
    assert skillsync.upstream_version_matching(f"file://{remote}", None, "skills/s", "f" * 40) is None


def test_upstream_version_matching_rejects_flag_smuggling():
    with pytest.raises(ValueError):
        skillsync.upstream_version_matching("--upload-pack=x", None, "skills/s", "a" * 40)


def test_settled_status_reclassifies_a_stale_folder(tmp_path, monkeypatch):
    # The installer advanced the lock and left the folder on the previous upstream version.
    remote = tmp_path / "remote"
    v1, v2 = _repo_with_two_versions(remote)
    agents = tmp_path / "agents"
    (agents / "s").mkdir(parents=True)
    (agents / "s/SKILL.md").write_text("v1\n")
    monkeypatch.setattr(skillsync, "AGENT_SKILLS_DIR", agents)
    entry = {"skillPath": "skills/s/SKILL.md", "skillFolderHash": v2,
             "sourceUrl": f"file://{remote}"}
    lhash, edited, note = skillsync.settled_edit_status("s", entry)
    assert lhash == v1 and edited is False
    assert "stale" in note


def test_settled_status_keeps_a_real_edit(tmp_path, monkeypatch):
    remote = tmp_path / "remote"
    _v1, v2 = _repo_with_two_versions(remote)
    agents = tmp_path / "agents"
    (agents / "s").mkdir(parents=True)
    (agents / "s/SKILL.md").write_text("v2 plus a personal rule\n")
    monkeypatch.setattr(skillsync, "AGENT_SKILLS_DIR", agents)
    entry = {"skillPath": "skills/s/SKILL.md", "skillFolderHash": v2,
             "sourceUrl": f"file://{remote}"}
    _h, edited, _n = skillsync.settled_edit_status("s", entry)
    assert edited is True


def test_settled_status_fails_safe_when_history_is_unreachable(tmp_path, monkeypatch):
    agents = tmp_path / "agents"
    (agents / "s").mkdir(parents=True)
    (agents / "s/SKILL.md").write_text("x\n")
    monkeypatch.setattr(skillsync, "AGENT_SKILLS_DIR", agents)
    entry = {"skillPath": "skills/s/SKILL.md", "skillFolderHash": "b" * 40,
             "sourceUrl": f"file://{tmp_path}/does-not-exist"}
    _h, edited, note = skillsync.settled_edit_status("s", entry)
    assert edited is True and "history" in note


# ---------- apply-skills: guard, read-back, links ----------
class _Apply:
    """A home with a lock and skill folders, and a fake installer standing in for npx."""

    def __init__(self, tmp_path, monkeypatch, names):
        self.home = tmp_path / "home"
        self.agents = self.home / ".agents/skills"
        self.claude = self.home / ".claude/skills"
        self.agents.mkdir(parents=True); self.claude.mkdir(parents=True)
        self.lock = self.home / ".agents/.skill-lock.json"
        rows = {}
        for n in names:
            (self.agents / n).mkdir()
            (self.agents / n / "SKILL.md").write_text("old\n")
            rows[n] = {"skillPath": f"skills/{n}/SKILL.md", "sourceUrl": "file:///nope",
                       "skillFolderHash": skillsync.local_tree_hash(self.agents / n)}
        self.lock.write_text(json.dumps({"skills": rows}))
        monkeypatch.setattr(skillsync, "HOME", self.home)
        monkeypatch.setattr(skillsync, "AGENT_SKILLS_DIR", self.agents)
        monkeypatch.setattr(skillsync, "SKILL_LOCK", self.lock)
        self.calls = []
        self.install = lambda names: None
        real_run = skillsync.subprocess.run

        def fake_run(cmd, **k):
            if cmd[0] == "npx":
                self.calls.append(cmd)
                self.install(cmd[3:-2])
                return type("R", (), {"returncode": 0})()
            return real_run(cmd, **k)
        monkeypatch.setattr(skillsync.subprocess, "run", fake_run)

    def land(self, name, text="new\n"):
        (self.agents / name / "SKILL.md").write_text(text)
        data = json.loads(self.lock.read_text())
        data["skills"][name]["skillFolderHash"] = skillsync.local_tree_hash(self.agents / name)
        self.lock.write_text(json.dumps(data))


def test_apply_skills_updates_and_reports(tmp_path, monkeypatch, capsys):
    a = _Apply(tmp_path, monkeypatch, ["tdd", "grilling"])
    a.install = lambda names: [a.land(n) for n in names]
    rc = skillsync.main(["apply-skills", "tdd", "grilling"])
    out = json.loads(capsys.readouterr().out)
    assert rc == 0
    assert sorted(out["applied"]) == ["grilling", "tdd"]
    assert a.calls == [["npx", "skills@latest", "update", "tdd", "grilling", "-g", "-y"]]


def test_apply_skills_refuses_a_hand_edit_and_still_applies_the_rest(tmp_path, monkeypatch, capsys):
    a = _Apply(tmp_path, monkeypatch, ["edited", "clean"])
    (a.agents / "edited/SKILL.md").write_text("old\nmy personal rule\n")
    a.install = lambda names: [a.land(n) for n in names]
    rc = skillsync.main(["apply-skills", "edited", "clean"])
    out = json.loads(capsys.readouterr().out)
    assert rc == 1
    assert [r["name"] for r in out["refused"]] == ["edited"]
    assert out["applied"] == ["clean"]
    assert a.calls[0][3:-2] == ["clean"]
    assert "my personal rule" in (a.agents / "edited/SKILL.md").read_text()


def test_apply_skills_force_overrides_the_guard(tmp_path, monkeypatch, capsys):
    a = _Apply(tmp_path, monkeypatch, ["edited"])
    (a.agents / "edited/SKILL.md").write_text("old\nmy personal rule\n")
    a.install = lambda names: [a.land(n) for n in names]
    rc = skillsync.main(["apply-skills", "--force", "edited"])
    assert rc == 0
    assert json.loads(capsys.readouterr().out)["applied"] == ["edited"]


def test_apply_skills_refuses_a_name_outside_the_lock(tmp_path, monkeypatch, capsys):
    a = _Apply(tmp_path, monkeypatch, ["tdd"])
    rc = skillsync.main(["apply-skills", "my-personal-skill"])
    out = json.loads(capsys.readouterr().out)
    assert rc == 1 and a.calls == []
    assert out["refused"][0]["name"] == "my-personal-skill"


def test_apply_skills_catches_lock_advanced_folder_stale(tmp_path, monkeypatch, capsys):
    # The installer says it worked and moves the lock; the folder keeps the old bytes.
    a = _Apply(tmp_path, monkeypatch, ["tdd"])

    def half_install(names):
        data = json.loads(a.lock.read_text())
        data["skills"]["tdd"]["skillFolderHash"] = "c" * 40
        a.lock.write_text(json.dumps(data))
    a.install = half_install
    rc = skillsync.main(["apply-skills", "tdd"])
    out = json.loads(capsys.readouterr().out)
    assert rc == 1
    assert [f["name"] for f in out["failed"]] == ["tdd"]


def test_apply_skills_reports_an_update_that_changed_nothing(tmp_path, monkeypatch, capsys):
    a = _Apply(tmp_path, monkeypatch, ["tdd"])
    rc = skillsync.main(["apply-skills", "tdd"])
    out = json.loads(capsys.readouterr().out)
    assert rc == 1 and out["unchanged"] == ["tdd"] and out["applied"] == []


def test_apply_skills_removes_a_link_the_installer_added(tmp_path, monkeypatch, capsys):
    # A skill left unlinked stays unlinked: the new link would shadow a built-in of that name.
    a = _Apply(tmp_path, monkeypatch, ["code-review"])

    def install(names):
        a.land("code-review")
        (a.claude / "code-review").symlink_to("../../.agents/skills/code-review")
    a.install = install
    rc = skillsync.main(["apply-skills", "code-review"])
    out = json.loads(capsys.readouterr().out)
    assert rc == 0
    assert not (a.claude / "code-review").is_symlink()
    assert out["unlinked"] == [str(a.claude / "code-review")]


def test_apply_skills_keeps_a_link_that_was_already_there(tmp_path, monkeypatch, capsys):
    a = _Apply(tmp_path, monkeypatch, ["tdd"])
    (a.claude / "tdd").symlink_to("../../.agents/skills/tdd")
    a.install = lambda names: a.land("tdd")
    assert skillsync.main(["apply-skills", "tdd"]) == 0
    assert (a.claude / "tdd").is_symlink()
    assert json.loads(capsys.readouterr().out)["unlinked"] == []


def test_apply_skills_leaves_a_new_link_to_somewhere_else(tmp_path, monkeypatch, capsys):
    # Only a link into the installer's own folder is the installer's doing.
    a = _Apply(tmp_path, monkeypatch, ["tdd"])
    other = tmp_path / "other"; other.mkdir()

    def install(names):
        a.land("tdd")
        (a.claude / "tdd").symlink_to(other)
    a.install = install
    assert skillsync.main(["apply-skills", "tdd"]) == 0
    assert (a.claude / "tdd").is_symlink()


# ---------- newSkills and deliberately removed skills ----------
def test_removed_skill_names_reads_every_parked_folder(tmp_path, monkeypatch):
    agents = tmp_path / ".agents"
    (agents / "skills-removed-2026-10-22/retro").mkdir(parents=True)
    (agents / "skills-removed-2026-11-03/teach").mkdir(parents=True)
    monkeypatch.setattr(skillsync, "SKILL_LOCK", agents / ".skill-lock.json")
    assert skillsync.removed_skill_names() == {"retro", "teach"}


def test_new_skill_parked_by_the_owner_is_not_offered_again(tmp_path, monkeypatch):
    remote = _make_local_repo(tmp_path / "remote")  # skills/eng/tdd, skills/prod/caveman
    head_tree = _git(remote, "rev-parse", "HEAD:skills/eng/tdd")
    agents = tmp_path / ".agents"
    (agents / "skills/tdd").mkdir(parents=True)
    (agents / "skills/tdd/SKILL.md").write_text("tdd v2\n")
    (agents / "skills-removed-2026-10-22/caveman").mkdir(parents=True)
    lock = agents / ".skill-lock.json"
    lock.write_text(json.dumps({"skills": {"tdd": {
        "skillPath": "skills/eng/tdd/SKILL.md", "sourceUrl": f"file://{remote}",
        "skillFolderHash": head_tree}}}))
    monkeypatch.setattr(skillsync, "SKILL_LOCK", lock)
    monkeypatch.setattr(skillsync, "AGENT_SKILLS_DIR", agents / "skills")
    report = {"plugins": [], "skills": [], "newSkills": [], "previouslyRemoved": [], "errors": []}
    skillsync.detect_skills(report, [])
    assert report["errors"] == []
    assert report["newSkills"] == []
    assert report["previouslyRemoved"] == ["caveman"]


# ---------- personal checkouts: reported, never changed ----------
def _personal_setup(tmp_path, monkeypatch):
    origin = tmp_path / "origin.git"
    _sp.run(["git", "init", "-q", "--bare", "-b", "main", str(origin)], check=True)
    repo = tmp_path / "checkout"
    (repo / "mine").mkdir(parents=True)
    (repo / "mine/SKILL.md").write_text("mine\n")
    _git(repo, "init", "-q", "-b", "main")
    _git(repo, "add", "-A"); _git(repo, "commit", "-qm", "one")
    _git(repo, "remote", "add", "origin", str(origin))
    _git(repo, "push", "-q", "-u", "origin", "main")
    claude = tmp_path / ".claude/skills"; claude.mkdir(parents=True)
    agents = tmp_path / ".agents/skills"; agents.mkdir(parents=True)
    (claude / "mine").symlink_to(repo / "mine")
    (claude / "gone").symlink_to(tmp_path / "missing")
    (agents / "lock-managed").mkdir()
    (claude / "lock-managed").symlink_to(agents / "lock-managed")
    monkeypatch.setattr(skillsync, "CLAUDE_SKILLS_DIR", claude)
    monkeypatch.setattr(skillsync, "AGENT_SKILLS_DIR", agents)
    return repo, origin


def test_personal_repos_reports_state_and_broken_links(tmp_path, monkeypatch):
    repo, _origin = _personal_setup(tmp_path, monkeypatch)
    (repo / "mine/SKILL.md").write_text("mine, edited\n")
    report = {"personalRepos": [], "brokenLinks": [], "errors": []}
    skillsync.detect_personal(report)
    assert len(report["personalRepos"]) == 1
    r = report["personalRepos"][0]
    assert r["skills"] == ["mine"] and r["branch"] == "main"
    assert r["dirty"] == 1 and r["ahead"] == 0 and r["behind"] == 0
    assert r["remoteMoved"] is False
    assert [Path(b).name for b in report["brokenLinks"]] == ["gone"]


def test_personal_repos_sees_a_remote_that_moved_without_fetching(tmp_path, monkeypatch):
    repo, origin = _personal_setup(tmp_path, monkeypatch)
    other = tmp_path / "other"
    _sp.run(["git", "clone", "-q", str(origin), str(other)], check=True)
    (other / "mine/SKILL.md").write_text("from the other machine\n")
    _git(other, "add", "-A"); _git(other, "commit", "-qm", "two"); _git(other, "push", "-q")
    before = _git(repo, "rev-parse", "origin/main")
    report = {"personalRepos": [], "brokenLinks": [], "errors": []}
    skillsync.detect_personal(report)
    assert report["personalRepos"][0]["remoteMoved"] is True
    assert _git(repo, "rev-parse", "origin/main") == before  # read-only: no fetch happened


# ---------- trust needs the host, not just the last two path segments ----------
@pytest.mark.parametrize("url,expected", [
    ("https://github.com/anthropics/skills.git", "anthropics/skills"),
    ("https://github.com/anthropics/skills", "anthropics/skills"),
    ("https://GitHub.com/anthropics/skills/", "anthropics/skills"),
    ("https://evil.example/anthropics/skills.git", None),
    ("https://github.com.evil.example/anthropics/skills.git", None),
    ("https://github.com@evil.example/anthropics/skills.git", None),
    ("https://evil.example/github.com/anthropics/skills.git", None),
    ("https://github.com/evil/anthropics/skills.git", None),
    ("http://github.com/anthropics/skills.git", None),
    ("git@github.com:anthropics/skills.git", None),
    ("file:///tmp/anthropics/skills", None),
    ("", None),
])
def test_github_repo_pins_scheme_host_and_shape(url, expected):
    assert skillsync.github_repo(url) == expected


def test_is_trusted_repo_treats_no_repo_as_untrusted():
    assert not skillsync.is_trusted_repo(None, ["*"])


def test_lookalike_host_is_not_trusted_end_to_end(tmp_path, monkeypatch):
    # Same owner/repo tail as a trusted source, on another host: it must ask, never auto-apply.
    monkeypatch.setattr(skillsync, "clone_no_checkout", lambda *a, **k: None)
    monkeypatch.setattr(skillsync, "upstream_skill_folders", lambda dest: {"skills/s"})
    monkeypatch.setattr(skillsync, "checkout_folders", lambda *a, **k: None)
    monkeypatch.setattr(skillsync, "diff_dirs", lambda *a: (True, "1 file(s), +1/-0 lines", ""))
    monkeypatch.setattr(skillsync, "local_edit_status", lambda n, e: ("a" * 40, False, None))
    lock = tmp_path / "lock.json"
    lock.write_text(json.dumps({"skills": {"s": {
        "sourceUrl": "https://evil.example/anthropics/skills.git",
        "skillPath": "skills/s/SKILL.md"}}}))
    monkeypatch.setattr(skillsync, "SKILL_LOCK", lock)
    report = {"plugins": [], "skills": [], "newSkills": [], "previouslyRemoved": [], "errors": []}
    skillsync.detect_skills(report, ["anthropics/*"])
    assert report["skills"][0]["trusted"] is False
    assert report["skills"][0]["action"] == "confirm"


# ---------- diff never follows a link out of the folder ----------
def _dirs_with_secret(tmp_path):
    secret = tmp_path / "secret.txt"
    secret.write_text("TOP-SECRET-BYTES\n")
    up = tmp_path / "up"; local = tmp_path / "local"
    up.mkdir(); local.mkdir()
    (up / "SKILL.md").write_text("same\n")
    (local / "SKILL.md").write_text("same\n")
    return secret, up, local


def test_diff_dirs_refuses_a_link_out_of_upstream(tmp_path):
    secret, up, local = _dirs_with_secret(tmp_path)
    (up / "notes.md").symlink_to(secret)
    with pytest.raises(RuntimeError) as e:
        skillsync.diff_dirs(up, local)
    assert "notes.md" in str(e.value) and "TOP-SECRET-BYTES" not in str(e.value)


def test_diff_dirs_refuses_a_link_out_of_the_local_folder(tmp_path):
    secret, up, local = _dirs_with_secret(tmp_path)
    (local / "notes.md").symlink_to(secret)
    with pytest.raises(RuntimeError):
        skillsync.diff_dirs(up, local)


def test_diff_dirs_refuses_a_directory_link_and_a_nested_one(tmp_path):
    _secret, up, local = _dirs_with_secret(tmp_path)
    (up / "refs").mkdir()
    (up / "refs/home").symlink_to(tmp_path)
    with pytest.raises(RuntimeError):
        skillsync.diff_dirs(up, local)


def test_diff_dirs_allows_a_link_that_stays_inside(tmp_path):
    _secret, up, local = _dirs_with_secret(tmp_path)
    (up / "alias.md").symlink_to("SKILL.md")
    changed, _stat, _full = skillsync.diff_dirs(up, local)
    assert changed is True


def test_detect_reports_an_escaping_link_as_an_error_and_applies_nothing(tmp_path, monkeypatch):
    remote = tmp_path / "remote"
    (remote / "skills/s").mkdir(parents=True)
    (remote / "skills/s/SKILL.md").write_text("v1\n")
    (remote / "skills/s/notes.md").symlink_to("/etc/hosts")
    _git(remote, "init", "-q"); _git(remote, "add", "-A"); _git(remote, "commit", "-qm", "v1")
    agents = tmp_path / "agents"
    (agents / "s").mkdir(parents=True)
    (agents / "s/SKILL.md").write_text("v1\n")
    lock = tmp_path / "lock.json"
    lock.write_text(json.dumps({"skills": {"s": {
        "sourceUrl": f"file://{remote}", "skillPath": "skills/s/SKILL.md",
        "skillFolderHash": "a" * 40}}}))
    monkeypatch.setattr(skillsync, "SKILL_LOCK", lock)
    monkeypatch.setattr(skillsync, "AGENT_SKILLS_DIR", agents)
    report = {"plugins": [], "skills": [], "newSkills": [], "previouslyRemoved": [], "errors": []}
    skillsync.detect_skills(report, ["*"])
    assert report["skills"] == []
    assert len(report["errors"]) == 1 and "notes.md" in report["errors"][0]


def test_diff_skill_prints_no_linked_content(tmp_path, monkeypatch, capsys):
    secret, up, local = _dirs_with_secret(tmp_path)
    (up / "notes.md").symlink_to(secret)
    monkeypatch.setattr(skillsync, "clone_skill_folders", lambda *a, **k: None)
    monkeypatch.setattr(skillsync, "diff_dirs", skillsync.diff_dirs)
    lock = tmp_path / "lock.json"
    lock.write_text(json.dumps({"skills": {"local": {
        "sourceUrl": "https://github.com/x/y.git", "skillPath": "skills/s/SKILL.md"}}}))
    monkeypatch.setattr(skillsync, "SKILL_LOCK", lock)
    monkeypatch.setattr(skillsync, "AGENT_SKILLS_DIR", tmp_path)
    real = skillsync.diff_dirs
    monkeypatch.setattr(skillsync, "diff_dirs", lambda u, l: real(up, local))
    assert skillsync.main(["diff-skill", "local"]) == 1
    captured = capsys.readouterr()
    assert "TOP-SECRET-BYTES" not in captured.out + captured.err
    assert "notes.md" in captured.err
