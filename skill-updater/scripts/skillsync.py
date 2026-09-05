#!/usr/bin/env python3
"""skillsync.py — detect and apply updates for installed skills.

Two update channels (a third ecosystem, Codex plugins under ~/.codex/plugins, has no update
command; the skill body enumerates it and this engine does not touch it):
  - Claude Code plugins (claude plugin CLI; ~/.claude/plugins/installed_plugins.json)
  - npx-skills agent-skills (~/.agents/.skill-lock.json, ~/.agents/skills/)

Subcommands:
  detect [--refresh] [--config PATH]   -> JSON report on stdout
  apply-plugin <plugin_id>             -> claude plugin update <id> --scope user
  apply-skills <name> [<name> ...]     -> npx skills@latest update <names> -g -y
  diff-skill <name> [--config PATH]    -> unified diff of local vs upstream skill folder
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HOME = Path.home()
PLUGINS_INSTALLED = HOME / ".claude/plugins/installed_plugins.json"
MARKETPLACES_DIR = HOME / ".claude/plugins/marketplaces"
SKILL_LOCK = HOME / ".agents/.skill-lock.json"
AGENT_SKILLS_DIR = HOME / ".agents/skills"
DEFAULT_CONFIG = Path(__file__).resolve().parent.parent / "trusted-sources.json"

# Locally-spawned files that are not part of any skill. Excluded from BOTH
# instruments (the tree hash and diff_dirs) so a stray Finder artefact can't
# read as a local edit or as a phantom upstream update.
JUNK_NAMES = {".DS_Store"}


# ---------- trusted-source classification ----------
def load_trusted_config(config_path):
    data = json.loads(Path(config_path).read_text())
    return data.get("marketplaces", []), data.get("repos", [])


def is_trusted_marketplace(marketplace, trusted_marketplaces):
    return marketplace in set(trusted_marketplaces)


def is_trusted_repo(repo, trusted_repos):
    return any(fnmatch.fnmatch(repo, pat) for pat in trusted_repos)


# ---------- plugin update decision ----------
def decide_plugin_update(installed_version, installed_sha, manifest_version, manifest_source):
    """Return (update_available: bool, available_label: str|None).

    If the manifest carries a version, compare versions. Otherwise the plugin is
    SHA-pinned — compare the manifest source sha to the installed gitCommitSha.
    """
    if manifest_version is not None:
        if manifest_version != installed_version:
            return True, manifest_version
        return False, None
    msha = manifest_source.get("sha") if isinstance(manifest_source, dict) else None
    if msha and installed_sha and msha != installed_sha:
        return True, msha[:12]
    return False, None


def read_marketplace_manifest(marketplace):
    p = MARKETPLACES_DIR / marketplace / ".claude-plugin" / "marketplace.json"
    if not p.exists():
        return None
    return json.loads(p.read_text())


def find_manifest_entry(manifest, plugin_name):
    if not manifest:
        return None
    for entry in manifest.get("plugins", []):
        if entry.get("name") == plugin_name:
            return entry
    return None


# ---------- agent-skill helpers ----------
def skill_folder_from_path(skill_path):
    """'skills/productivity/caveman/SKILL.md' -> 'skills/productivity/caveman'."""
    return os.path.dirname(skill_path)


def plugin_update_cmd(plugin_id):
    return ["claude", "plugin", "update", plugin_id, "--scope", "user"]


def skills_update_cmd(names):
    return ["npx", "skills@latest", "update", *names, "-g", "-y"]


def repo_from_url(source_url):
    """'https://github.com/mattpocock/skills.git' -> 'mattpocock/skills'."""
    s = source_url.rstrip("/")
    if s.endswith(".git"):
        s = s[:-4]
    parts = s.split("/")
    return "/".join(parts[-2:]) if len(parts) >= 2 else s


def group_skills_by_repo(lock_skills):
    """lock_skills: dict name->entry. Returns {sourceUrl: [(name, folder, ref)]}.

    Entries without skillPath/sourceUrl (legacy) are skipped here; detect_skills
    surfaces them separately as 'manual update only'.
    """
    groups = {}
    for name, entry in lock_skills.items():
        skill_path = entry.get("skillPath")
        source_url = entry.get("sourceUrl")
        if not skill_path or not source_url:
            continue
        folder = skill_folder_from_path(skill_path)
        groups.setdefault(source_url, []).append((name, folder, entry.get("ref")))
    return groups


# ---------- local-edit detection ----------
def is_sha40(value):
    """True for a 40-char lowercase-hex git object id."""
    return (isinstance(value, str) and len(value) == 40
            and all(c in "0123456789abcdef" for c in value))


def junk_pathspecs():
    """git pathspecs excluding JUNK_NAMES at any depth."""
    specs = []
    for name in sorted(JUNK_NAMES):
        specs.append(f":(exclude){name}")
        specs.append(f":(exclude,glob)**/{name}")
    return specs


def junk_diff_excludes():
    """`diff` flags excluding JUNK_NAMES (matched by basename, at any depth)."""
    return [f"--exclude={name}" for name in sorted(JUNK_NAMES)]


def local_tree_hash(skill_dir):
    """Git tree hash of skill_dir's current contents, or None on any failure.

    Reproduces the `skillFolderHash` recorded in ~/.agents/.skill-lock.json for a
    pristine skill folder, so a difference means the local copy was hand-edited.
    Uses a throwaway GIT_DIR — nothing is created inside skill_dir — and a fresh
    index per call, so no state leaks between skills. Never raises.
    """
    skill_dir = Path(skill_dir)
    if not skill_dir.is_dir():
        return None
    had_git = (skill_dir / ".git").exists()
    tmp = None
    try:
        tmp = tempfile.mkdtemp(prefix="skillsync-hash-")
        if not tmp or not os.path.isdir(tmp):
            return None
        git_dir = os.path.join(tmp, ".git")
        subprocess.run(["git", "init", "-q", "--", tmp],
                       check=True, capture_output=True, text=True)
        base = ["git", f"--git-dir={git_dir}", f"--work-tree={skill_dir}"]
        subprocess.run(base + ["add", "-A", "-f", "--", ".", *junk_pathspecs()],
                       cwd=str(skill_dir), check=True, capture_output=True, text=True)
        r = subprocess.run(base + ["write-tree"], cwd=str(skill_dir),
                           check=True, capture_output=True, text=True)
        if not had_git and (skill_dir / ".git").exists():
            return None  # bug guard: this call must create nothing in skill_dir
        tree = r.stdout.strip()
        return tree if is_sha40(tree) else None
    except Exception:
        return None
    finally:
        if tmp and os.path.isdir(tmp):
            shutil.rmtree(tmp, ignore_errors=True)


def local_edit_status(name, entry):
    """Return (localTreeHash, localEdited, note) for one lock entry.

    localEdited is True only when the recorded hash is usable AND differs from
    the local one: an update over a hand-edited skill is data loss, not an
    update, so the caller must refuse to auto-apply it. None means "can't tell".
    """
    local_hash = local_tree_hash(AGENT_SKILLS_DIR / name)
    recorded = entry.get("skillFolderHash")
    if not is_sha40(recorded):
        return local_hash, None, None  # legacy / well-known entry: no baseline
    if skill_folder_from_path(entry.get("skillPath") or "") == "":
        # The skill IS the repo root, so the recorded hash covers upstream files
        # the installer's copy-exclusion drops and can never match locally.
        return local_hash, False, "root-repo skill — local-edit check not applicable"
    if local_hash is None:
        return None, None, None  # couldn't hash the local folder: no verdict
    return local_hash, local_hash != recorded, None


def merge_note(existing, extra):
    """Append `extra` to an existing note without losing it."""
    if not extra:
        return existing
    return f"{existing}; {extra}" if existing else extra


# ---------- diffing ----------
def diff_dirs(upstream_dir, local_dir):
    """Return (changed: bool, diffstat: str, full_diff: str).

    `diff` exit codes: 0 = same, 1 = differences, 2 = trouble (e.g. missing dir).
    Raises RuntimeError on exit code 2.
    """
    excludes = ["--exclude=.git", *junk_diff_excludes()]
    brief = subprocess.run(
        ["diff", "-rq", *excludes, str(local_dir), str(upstream_dir)],
        capture_output=True, text=True)
    if brief.returncode == 2:
        raise RuntimeError(brief.stderr.strip() or "diff failed")
    changed = brief.returncode == 1
    changed_files = len([ln for ln in brief.stdout.splitlines() if ln.strip()])
    full = subprocess.run(
        ["diff", "-ruN", *excludes, str(local_dir), str(upstream_dir)],
        capture_output=True, text=True)
    added = sum(1 for ln in full.stdout.splitlines()
                if ln.startswith("+") and not ln.startswith("+++"))
    removed = sum(1 for ln in full.stdout.splitlines()
                  if ln.startswith("-") and not ln.startswith("---"))
    diffstat = f"{changed_files} file(s), +{added}/-{removed} lines"
    return changed, diffstat, (full.stdout if changed else "")


# ---------- cloning ----------
def clone_no_checkout(source_url, ref, dest):
    """Shallow, blob-filtered, no-checkout clone. Tree metadata is available
    (git ls-tree) without fetching file contents.

    source_url/ref come from the untrusted ~/.agents/.skill-lock.json, so reject
    any value git could read as an option (argv flag smuggling — e.g. a sourceUrl
    of "--upload-pack=<cmd>" is RCE) and separate positionals with "--".
    """
    for val, label in [(source_url, "sourceUrl"), (ref or "", "ref")]:
        if val.startswith("-"):
            raise ValueError(f"unsafe {label}: {val!r}")
    cmd = ["git", "clone", "--depth", "1", "--filter=blob:none", "--no-checkout"]
    if ref:
        cmd += ["--branch", ref]
    cmd += ["--", source_url, str(dest)]
    subprocess.run(cmd, check=True, capture_output=True, text=True)


def upstream_skill_folders(dest):
    """All folders in the cloned repo's HEAD tree containing a SKILL.md.

    Works on a --no-checkout clone: ls-tree reads tree objects, which a
    blob-filtered clone still has.
    """
    r = subprocess.run(["git", "-C", str(dest), "ls-tree", "-r", "--name-only", "HEAD"],
                       check=True, capture_output=True, text=True)
    return {os.path.dirname(p) for p in r.stdout.splitlines()
            if os.path.basename(p) == "SKILL.md"}


def validate_folders(folders):
    """Reject any folder git could read as an option (same argv-smuggling risk as sourceUrl)."""
    for folder in folders:
        if folder.startswith("-"):
            raise ValueError(f"unsafe folder: {folder!r}")


def checkout_folders(dest, folders):
    """Sparse-checkout `folders` in an existing no-checkout clone."""
    validate_folders(folders)
    # An empty folder ("") means the skill IS the whole repo (skillPath == "SKILL.md").
    # Sparse-checkout can't express "repo root" in cone mode, so fall back to a full
    # checkout whenever any folder is the root; otherwise sparse-checkout just the subfolders.
    sparse_folders = [f for f in folders if f]
    if len(sparse_folders) == len(folders):
        subprocess.run(["git", "-C", str(dest), "sparse-checkout", "init", "--cone"],
                       check=True, capture_output=True, text=True)
        subprocess.run(["git", "-C", str(dest), "sparse-checkout", "set", "--", *sparse_folders],
                       check=True, capture_output=True, text=True)
    subprocess.run(["git", "-C", str(dest), "checkout"],
                   check=True, capture_output=True, text=True)


def clone_skill_folders(source_url, folders, ref, dest):
    """Shallow, blob-filtered, sparse clone of `folders` from source_url into dest."""
    # Every untrusted value is checked BEFORE the network call. Validating folders only
    # inside checkout_folders left a bad one to be caught after the clone had already run.
    validate_folders(folders)
    clone_no_checkout(source_url, ref, dest)
    checkout_folders(dest, folders)


# ---------- detect orchestration ----------
def detect(refresh=False, config_path=DEFAULT_CONFIG):
    trusted_marketplaces, trusted_repos = load_trusted_config(config_path)
    report = {"plugins": [], "skills": [], "newSkills": [], "errors": []}
    if refresh:
        r = subprocess.run(["claude", "plugin", "marketplace", "update"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            report["errors"].append("marketplace update failed: " + (r.stderr or "").strip()[:200])
    detect_plugins(report, trusted_marketplaces)
    detect_skills(report, trusted_repos)
    return report


def detect_plugins(report, trusted_marketplaces):
    if not PLUGINS_INSTALLED.exists():
        return
    data = json.loads(PLUGINS_INSTALLED.read_text())
    for plugin_key, installs in data.get("plugins", {}).items():
        name, _, marketplace = plugin_key.partition("@")
        manifest = read_marketplace_manifest(marketplace)
        entry = find_manifest_entry(manifest, name)
        if entry is None:
            report["errors"].append(f"no manifest entry for {plugin_key}")
            continue
        for inst in installs:
            upd, label = decide_plugin_update(
                inst.get("version"), inst.get("gitCommitSha"),
                entry.get("version"), entry.get("source"))
            report["plugins"].append({
                "id": plugin_key,
                "name": name,
                "marketplace": marketplace,
                "installedVersion": inst.get("version"),
                "availableLabel": label,
                "trusted": is_trusted_marketplace(marketplace, trusted_marketplaces),
                "updateAvailable": upd,
            })


def detect_skills(report, trusted_repos):
    if not SKILL_LOCK.exists():
        return
    lock = json.loads(SKILL_LOCK.read_text())
    skills = lock.get("skills", {})
    # Surface legacy entries (no skillPath/sourceUrl) as manual-only.
    for name, entry in skills.items():
        if not entry.get("skillPath") or not entry.get("sourceUrl"):
            lhash, ledited, lnote = local_edit_status(name, entry)
            report["skills"].append({
                "name": name, "source": entry.get("source"),
                "skillPath": None, "trusted": False, "updateAvailable": False,
                "diffstat": None,
                "note": merge_note("legacy entry (no skillPath) — update manually", lnote),
                "localTreeHash": lhash, "localEdited": ledited,
            })
    for source_url, items in group_skills_by_repo(skills).items():
        repo = repo_from_url(source_url)
        trusted = is_trusted_repo(repo, trusted_repos)
        ref = items[0][2]
        tmp = Path(tempfile.mkdtemp(prefix="skillsync-"))
        try:
            # These folders come from the lock file, same as sourceUrl and ref. Check them
            # here rather than leaving it to checkout_folders below, which runs only after
            # the network call — the reason ValueError is caught alongside
            # CalledProcessError: one bad repo is an entry in `errors`, not the end of the
            # run for every other repo.
            validate_folders([f for (_, f, _) in items])
            clone_no_checkout(source_url, ref, tmp)
            upstream = upstream_skill_folders(tmp)
            # Classify each installed skill: still at its folder, moved (same
            # basename elsewhere upstream), or removed upstream entirely.
            present, moved, removed = [], [], []
            for (name, folder, _ref) in items:
                if folder in upstream:
                    present.append((name, folder))
                    continue
                match = next((u for u in upstream
                              if u and os.path.basename(u) == os.path.basename(folder)), None)
                if match:
                    moved.append((name, folder, match))
                else:
                    removed.append((name, folder))
            checkout_folders(tmp, [f for (_, f) in present] + [m for (_, _, m) in moved])
            for (name, folder) in present:
                try:
                    changed, diffstat, _full = diff_dirs(tmp / folder, AGENT_SKILLS_DIR / name)
                except Exception as e:  # missing local folder, etc.
                    report["errors"].append(f"diff {name}: {e}")
                    continue
                lhash, ledited, lnote = local_edit_status(name, skills.get(name, {}))
                report["skills"].append({
                    "name": name, "source": repo, "skillPath": folder,
                    "trusted": trusted, "updateAvailable": changed,
                    "diffstat": diffstat if changed else None,
                    "note": merge_note(None, lnote),
                    "localTreeHash": lhash, "localEdited": ledited,
                })
            for (name, old_folder, new_folder) in moved:
                try:
                    changed, diffstat, _full = diff_dirs(tmp / new_folder, AGENT_SKILLS_DIR / name)
                except Exception as e:
                    changed, diffstat = True, None
                    report["errors"].append(f"diff {name}: {e}")
                lhash, ledited, lnote = local_edit_status(name, skills.get(name, {}))
                report["skills"].append({
                    "name": name, "source": repo, "skillPath": new_folder,
                    "trusted": trusted, "updateAvailable": changed,
                    "diffstat": diffstat if changed else None,
                    "note": merge_note(
                        f"moved upstream: {old_folder} -> {new_folder}; "
                        f"reinstall to fix the lock path: "
                        f"npx skills@latest add {repo} -g -y --skill {name}", lnote),
                    "localTreeHash": lhash, "localEdited": ledited,
                })
            for (name, folder) in removed:
                lhash, ledited, lnote = local_edit_status(name, skills.get(name, {}))
                report["skills"].append({
                    "name": name, "source": repo, "skillPath": folder,
                    "trusted": trusted, "updateAvailable": False,
                    "diffstat": None,
                    "note": merge_note(
                        "removed upstream (possibly renamed — check newSkills); "
                        "local copy kept as-is", lnote),
                    "localTreeHash": lhash, "localEdited": ledited,
                })
            # Upstream skills with no lock entry at all: new (or renamed) skills.
            # Only for repos the user tracks wholesale (installed >= half of
            # upstream) — cherry-picked catalog repos would flood the report.
            installed_folders = {f for (_, f, _) in items}
            installed_names = {n for (n, _, _) in items}
            if len(installed_folders) * 2 >= len(upstream):
                for folder in sorted(upstream - installed_folders):
                    base = os.path.basename(folder)
                    if not base or base in installed_names:
                        continue  # root-repo skill, or already reported as moved
                    report["newSkills"].append({
                        "name": base, "source": repo, "skillPath": folder,
                        "trusted": trusted,
                        "installCmd": f"npx skills@latest add {repo} -g -y --skill {base}",
                    })
        except (subprocess.CalledProcessError, ValueError) as e:
            detail = (getattr(e, "stderr", None) or str(e))[:200]
            report["errors"].append(f"{repo} failed: {detail}")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


# ---------- apply + diff ----------
def apply_plugin(plugin_id):
    return subprocess.run(plugin_update_cmd(plugin_id)).returncode


def apply_skills(names):
    if not names:
        return 0
    return subprocess.run(skills_update_cmd(names)).returncode


def diff_skill(name, config_path=DEFAULT_CONFIG):
    lock = json.loads(SKILL_LOCK.read_text())
    entry = lock.get("skills", {}).get(name)
    if not entry or not entry.get("skillPath") or not entry.get("sourceUrl"):
        print(f"No updatable lock entry for skill: {name}", file=sys.stderr)
        return 1
    folder = skill_folder_from_path(entry["skillPath"])
    tmp = Path(tempfile.mkdtemp(prefix="skillsync-diff-"))
    try:
        clone_skill_folders(entry["sourceUrl"], [folder], entry.get("ref"), tmp)
        _changed, _stat, full = diff_dirs(tmp / folder, AGENT_SKILLS_DIR / name)
        print(full if full.strip() else "(no differences)")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 0


# ---------- CLI ----------
def main(argv=None):
    parser = argparse.ArgumentParser(prog="skillsync.py")
    sub = parser.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("detect", help="emit JSON update report")
    d.add_argument("--refresh", action="store_true", help="refresh marketplaces first")
    d.add_argument("--config", default=str(DEFAULT_CONFIG))

    ap = sub.add_parser("apply-plugin", help="update one plugin")
    ap.add_argument("plugin_id")

    ask = sub.add_parser("apply-skills", help="update named agent-skills")
    ask.add_argument("names", nargs="+")

    ds = sub.add_parser("diff-skill", help="print unified diff for one skill")
    ds.add_argument("name")
    ds.add_argument("--config", default=str(DEFAULT_CONFIG))

    args = parser.parse_args(argv)
    if args.cmd == "detect":
        print(json.dumps(detect(args.refresh, args.config), indent=2))
        return 0
    if args.cmd == "apply-plugin":
        return apply_plugin(args.plugin_id)
    if args.cmd == "apply-skills":
        return apply_skills(args.names)
    if args.cmd == "diff-skill":
        return diff_skill(args.name, args.config)
    return 1


if __name__ == "__main__":
    sys.exit(main())
