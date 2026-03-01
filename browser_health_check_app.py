#!/usr/bin/env python3
"""
Macktechs Browser Health Check — GUI
macOS 11+. Lets user select browsers, run scan, view results,
and remove/change extensions, profiles, default search, homepage, login items.
"""
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import threading
from pathlib import Path

try:
    import tkinter as tk
    from tkinter import ttk, messagebox, scrolledtext, simpledialog
except ImportError:
    print("tkinter is required. On macOS use the system Python or install python-tk.")
    sys.exit(1)

# Paths
HOME = Path.home()
DESKTOP = HOME / "Desktop"
CHROME_DIR = HOME / "Library/Application Support/Google/Chrome"
CHROME_EXT_DIR = CHROME_DIR / "Default/Extensions"
FF_DIR = HOME / "Library/Application Support/Firefox"
FF_PROFILES_DIR = FF_DIR / "Profiles"
SAFARI_DIR = HOME / "Library/Safari"
SAFARI_EXT_DIR = SAFARI_DIR / "Extensions"

SUSPICIOUS_PATTERN = re.compile(
    r"mackeeper|mackeepr|advancedmaccleaner|searchmarquis|search baron|"
    r"searchbaron|chilltab|weknow|anysearch|mybrowserhelper",
    re.I,
)


def macos_version_ok():
    """Require macOS 11.0 or later."""
    try:
        ver = platform.mac_ver()[0]
        if not ver:
            return False
        parts = [int(x) for x in ver.split(".")[:2]]
        major = parts[0] if parts else 0
        return major >= 11
    except Exception:
        return False


def run_osascript(script):
    """Run AppleScript and return (success, output)."""
    try:
        out = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=10,
        )
        return out.returncode == 0, (out.stdout or "").strip()
    except Exception as e:
        return False, str(e)


def check_suspicious(text):
    return bool(text and SUSPICIOUS_PATTERN.search(text))


# ---------------------------------------------------------------------------
# Scan logic (mirrors shell script)
# ---------------------------------------------------------------------------
def get_system_hosts():
    p = Path("/etc/hosts")
    if p.exists() and os.access(p, os.R_OK):
        return p.read_text(errors="replace")
    return "(Cannot read /etc/hosts)"


def get_dns_wifi():
    try:
        out = subprocess.run(
            ["networksetup", "-getdnsservers", "Wi-Fi"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return out.stdout.strip() if out.returncode == 0 else "Wi-Fi DNS unavailable."
    except Exception as e:
        return str(e)


def get_proxy_wifi():
    lines = []
    for opt in ["-getwebproxy", "-getsecurewebproxy"]:
        try:
            out = subprocess.run(
                ["networksetup", opt, "Wi-Fi"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            lines.append(out.stdout.strip() if out.returncode == 0 else "(unavailable)")
        except Exception:
            lines.append("(error)")
    return "\n".join(lines)


def get_launch_agents_daemons():
    result = []
    for label, path in [
        ("User LaunchAgents", HOME / "Library/LaunchAgents"),
        ("System LaunchAgents", Path("/Library/LaunchAgents")),
        ("System LaunchDaemons", Path("/Library/LaunchDaemons")),
    ]:
        if path.exists():
            try:
                names = sorted(p.name for p in path.iterdir())
                result.append((label, path, "\n".join(names)))
            except Exception as e:
                result.append((label, path, str(e)))
        else:
            result.append((label, path, "(not found)"))
    return result


def get_login_items():
    ok, out = run_osascript('tell application "System Events" to get the name of every login item')
    if ok:
        return out.replace(", ", "\n").strip()
    return "(Could not read login items; Accessibility permission may be required)"


def get_chrome_profiles():
    if not CHROME_DIR.exists():
        return []
    profiles = []
    for p in CHROME_DIR.iterdir():
        if p.is_dir() and (p.name == "Default" or p.name.startswith("Profile ")):
            profiles.append(p)
    return sorted(profiles, key=lambda x: x.name)


def get_chrome_extensions(profile_path):
    ext_dir = profile_path / "Extensions"
    if not ext_dir.exists():
        return []
    exts = []
    for ext_id_dir in ext_dir.iterdir():
        if not ext_id_dir.is_dir():
            continue
        ext_id = ext_id_dir.name
        name = "(no manifest)"
        for manifest in ext_id_dir.rglob("manifest.json"):
            try:
                data = json.loads(manifest.read_text(errors="replace"))
                name = data.get("name", "(no name)")
                if isinstance(name, dict) and "message" in name:
                    name = name["message"]
                break
            except Exception:
                pass
        exts.append((ext_id, str(name)))
    return exts


def get_chrome_managed_prefs():
    p = Path("/Library/Managed Preferences/com.google.Chrome.plist")
    if not p.exists():
        return None
    try:
        out = subprocess.run(
            ["defaults", "read", "/Library/Managed Preferences/com.google.Chrome"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return out.stdout if out.returncode == 0 else None
    except Exception:
        return None


def get_firefox_profiles():
    if not FF_PROFILES_DIR.exists():
        return []
    return [p for p in FF_PROFILES_DIR.iterdir() if p.is_dir()]


def get_firefox_extensions(profile_path):
    ext_dir = profile_path / "extensions"
    if not ext_dir.exists():
        return []
    # extensions.json has addons; also list .xpi
    result = []
    ext_json = profile_path / "extensions.json"
    if ext_json.exists():
        try:
            data = json.loads(ext_json.read_text(errors="replace"))
            addons = data.get("addons", []) + data.get("theme", [])
            for a in addons:
                aid = a.get("id") or a.get("defaultLocale", {}).get("name", "?")
                aname = a.get("defaultLocale", {}).get("name") or a.get("name") or aid
                result.append((aid, aname, "json"))
        except Exception:
            pass
    for f in ext_dir.iterdir():
        if f.suffix == ".xpi" or f.is_dir():
            result.append((f.name, f.name, "xpi"))
    return result


def get_firefox_policies():
    p = Path("/Library/Application Support/Mozilla/ManagedStorage/firefox/policies.json")
    if not p.exists():
        return None
    try:
        return p.read_text(errors="replace")
    except Exception:
        return None


def get_safari_extensions():
    if not SAFARI_EXT_DIR.exists():
        return []
    exts = []
    for p in SAFARI_EXT_DIR.iterdir():
        exts.append((p.name, p.name, p))
    return exts


def get_safari_managed_prefs():
    p = Path("/Library/Managed Preferences/com.apple.Safari.plist")
    if not p.exists():
        return None
    try:
        out = subprocess.run(
            ["defaults", "read", "/Library/Managed Preferences/com.apple.Safari"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return out.stdout if out.returncode == 0 else None
    except Exception:
        return None


def get_safari_search_and_home():
    try:
        out = subprocess.run(
            ["defaults", "read", "com.apple.Safari", "SearchProviderIdentifier"],
            capture_output=True,
            text=True,
            timeout=3,
        )
        search = out.stdout.strip() if out.returncode == 0 else "(not set)"
    except Exception:
        search = "(not set)"
    try:
        out = subprocess.run(
            ["defaults", "read", "com.apple.Safari", "HomePage"],
            capture_output=True,
            text=True,
            timeout=3,
        )
        home = out.stdout.strip() if out.returncode == 0 else "(not set)"
    except Exception:
        home = "(not set)"
    return search, home


def remove_chrome_extension(profile_path, ext_id):
    ext_dir = profile_path / "Extensions" / ext_id
    if ext_dir.exists():
        shutil.rmtree(ext_dir)
        return True
    return False


def remove_firefox_extension(profile_path, addon_id):
    ext_json = profile_path / "extensions.json"
    if not ext_json.exists():
        return False
    try:
        data = json.loads(ext_json.read_text(errors="replace"))
        addons = data.get("addons", [])
        new_addons = [a for a in addons if a.get("id") != addon_id and a.get("defaultLocale", {}).get("name") != addon_id]
        if len(new_addons) == len(addons):
            # Try removing by path
            ext_dir = profile_path / "extensions"
            for f in ext_dir.iterdir():
                if f.name == addon_id or (f.is_dir() and f.name == addon_id):
                    shutil.rmtree(f) if f.is_dir() else f.unlink()
                    return True
            return False
        data["addons"] = new_addons
        ext_json.write_text(json.dumps(data, indent=2))
        return True
    except Exception:
        return False


def remove_safari_extension(ext_path):
    try:
        if ext_path.is_dir():
            shutil.rmtree(ext_path)
        else:
            ext_path.unlink()
        return True
    except Exception:
        return False


def _escape_applescript_string(s: str) -> str:
    """Escape a string for safe use inside an AppleScript double-quoted string."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def remove_login_item(name):
    safe_name = _escape_applescript_string(name)
    ok, _ = run_osascript(
        f'tell application "System Events" to delete login item "{safe_name}"'
    )
    return ok


def set_safari_homepage(url):
    try:
        subprocess.run(
            ["defaults", "write", "com.apple.Safari", "HomePage", "-string", url],
            check=True,
            capture_output=True,
            timeout=5,
        )
        return True
    except Exception:
        return False


def set_safari_search_provider(provider_id):
    try:
        subprocess.run(
            ["defaults", "write", "com.apple.Safari", "SearchProviderIdentifier", "-string", provider_id],
            check=True,
            capture_output=True,
            timeout=5,
        )
        return True
    except Exception:
        return False


def reveal_in_finder(path):
    path = Path(path)
    if path.exists():
        subprocess.run(["open", "-R", str(path)], check=False, capture_output=True)


# ---------------------------------------------------------------------------
# GUI
# ---------------------------------------------------------------------------
class BrowserHealthCheckApp:
    def __init__(self):
        if not macos_version_ok():
            root = tk.Tk()
            root.withdraw()
            messagebox.showerror(
                "Macktechs Browser Health Check",
                "Your macOS version is not supported. This tool requires macOS 11.0 or later.",
            )
            sys.exit(1)

        self.root = tk.Tk()
        self.root.title("Macktechs Browser Health Check")
        self.root.minsize(700, 500)
        self.root.geometry("900x600")

        self.scan_chrome = tk.BooleanVar(value=True)
        self.scan_firefox = tk.BooleanVar(value=True)
        self.scan_safari = tk.BooleanVar(value=True)

        self.suspicious_matches = []
        self.report_data = {}  # for Save report
        self.content = None
        self._show_welcome()

    def _show_welcome(self):
        if self.content:
            for c in self.content.winfo_children():
                c.destroy()
        else:
            self.content = tk.Frame(self.root, padx=20, pady=20)
            self.content.pack(fill=tk.BOTH, expand=True)
        f = self.content
        tk.Label(f, text="Macktechs Browser Health Check", font=("Helvetica", 18, "bold")).pack(pady=(0, 20))
        tk.Label(f, text="Select which browsers to scan (system checks always run):").pack(anchor=tk.W)
        tk.Checkbutton(f, text="Chrome", variable=self.scan_chrome).pack(anchor=tk.W)
        tk.Checkbutton(f, text="Firefox", variable=self.scan_firefox).pack(anchor=tk.W)
        tk.Checkbutton(f, text="Safari", variable=self.scan_safari).pack(anchor=tk.W)
        tk.Button(f, text="Run Scan", command=self._run_scan, font=("Helvetica", 12)).pack(pady=20)

    def _run_scan(self):
        self.root.config(cursor="watch")
        self.root.update()

        def do_scan():
            try:
                self._perform_scan()
            finally:
                self.root.after(0, lambda: self.root.config(cursor=""))

        t = threading.Thread(target=do_scan, daemon=True)
        t.start()

    def _perform_scan(self):
        self.suspicious_matches = []
        report = []

        def add_suspicious(label, data):
            if data and check_suspicious(data):
                self.suspicious_matches.append(label)

        # System
        hosts = get_system_hosts()
        add_suspicious("hosts file", hosts)
        dns = get_dns_wifi()
        proxy = get_proxy_wifi()
        add_suspicious("Wi-Fi proxy settings", proxy)
        launch = get_launch_agents_daemons()
        for label, path, text in launch:
            add_suspicious(label, text)
        login_items = get_login_items()
        add_suspicious("Login Items", login_items)

        chrome_profiles = []
        chrome_exts = []
        chrome_managed = None
        if self.scan_chrome.get():
            chrome_profiles = get_chrome_profiles()
            for prof in chrome_profiles:
                chrome_exts.append((prof, get_chrome_extensions(prof)))
            chrome_managed = get_chrome_managed_prefs()
            if chrome_managed:
                add_suspicious("Chrome Managed Preferences", chrome_managed)

        ff_profiles = []
        ff_exts = []
        ff_policies = None
        if self.scan_firefox.get():
            ff_profiles = get_firefox_profiles()
            for prof in ff_profiles:
                ff_exts.append((prof, get_firefox_extensions(prof)))
            ff_policies = get_firefox_policies()
            if ff_policies:
                add_suspicious("Firefox global policies", ff_policies)

        safari_exts = get_safari_extensions() if self.scan_safari.get() else []
        add_suspicious("Safari Extensions folder", " ".join(e[0] for e in safari_exts))
        safari_managed = get_safari_managed_prefs() if self.scan_safari.get() else None
        if safari_managed:
            add_suspicious("Safari Managed Preferences", safari_managed)
        safari_search, safari_home = get_safari_search_and_home() if self.scan_safari.get() else ("(not set)", "(not set)")
        add_suspicious("Safari search/homepage", f"Search: {safari_search} Home: {safari_home}")

        self.report_data = {
            "hosts": hosts,
            "dns": dns,
            "proxy": proxy,
            "launch": launch,
            "login_items": login_items,
            "chrome_profiles": chrome_profiles,
            "chrome_exts": chrome_exts,
            "chrome_managed": chrome_managed,
            "ff_profiles": ff_profiles,
            "ff_exts": ff_exts,
            "ff_policies": ff_policies,
            "safari_exts": safari_exts,
            "safari_managed": safari_managed,
            "safari_search": safari_search,
            "safari_home": safari_home,
        }

        self.root.after(0, lambda: self._show_results(
            hosts, dns, proxy, launch, login_items,
            chrome_profiles, chrome_exts, chrome_managed,
            ff_profiles, ff_exts, ff_policies,
            safari_exts, safari_managed, safari_search, safari_home,
        ))

    def _show_results(self, hosts, dns, proxy, launch, login_items,
                      chrome_profiles, chrome_exts, chrome_managed,
                      ff_profiles, ff_exts, ff_policies,
                      safari_exts, safari_managed, safari_search, safari_home):
        for c in self.content.winfo_children():
            c.destroy()
        main = tk.Frame(self.content, padx=10, pady=10)
        main.pack(fill=tk.BOTH, expand=True)

        top = tk.Frame(main)
        top.pack(fill=tk.X)
        tk.Button(top, text="← Back", command=self._show_welcome).pack(side=tk.LEFT, padx=(0, 10))
        tk.Button(top, text="Save report to Desktop", command=self._save_report).pack(side=tk.LEFT)

        nb = ttk.Notebook(main)
        nb.pack(fill=tk.BOTH, expand=True, pady=10)

        # System tab
        sys_f = tk.Frame(nb, padx=10, pady=10)
        nb.add(sys_f, text="System")
        sys_text = scrolledtext.ScrolledText(sys_f, wrap=tk.WORD, height=20)
        sys_text.pack(fill=tk.BOTH, expand=True)
        sys_text.insert(tk.END, "=== /etc/hosts ===\n" + hosts + "\n\n")
        sys_text.insert(tk.END, "=== DNS (Wi-Fi) ===\n" + dns + "\n\n")
        sys_text.insert(tk.END, "=== Proxy (Wi-Fi) ===\n" + proxy + "\n\n")
        sys_text.insert(tk.END, "=== LaunchAgents / LaunchDaemons ===\n")
        for label, path, text in launch:
            sys_text.insert(tk.END, f"{label}: {path}\n{text}\n\n")
        sys_text.insert(tk.END, "=== Login Items ===\n" + login_items + "\n")
        sys_text.config(state=tk.DISABLED)

        sys_btns = tk.Frame(sys_f)
        sys_btns.pack(fill=tk.X, pady=5)
        tk.Button(sys_btns, text="Reveal hosts file in Finder", command=lambda: reveal_in_finder("/etc/hosts")).pack(side=tk.LEFT, padx=5)
        for label, path, _ in launch:
            p = path
            tk.Button(sys_btns, text=f"Reveal {label}", command=lambda pt=p: reveal_in_finder(pt)).pack(side=tk.LEFT, padx=5)
        # Login items: list and Remove
        login_list = [x.strip() for x in login_items.split("\n") if x.strip() and not x.strip().startswith("(")]
        if login_list:
            tk.Label(sys_btns, text="Remove login item:").pack(side=tk.LEFT, padx=(20, 0))
            for name in login_list:
                n = name
                tk.Button(sys_btns, text=f"Remove '{n}'", command=lambda item=n: self._remove_login_item(item)).pack(side=tk.LEFT, padx=2)

        # Chrome tab
        ch_f = tk.Frame(nb, padx=10, pady=10)
        nb.add(ch_f, text="Chrome")
        ch_text = scrolledtext.ScrolledText(ch_f, wrap=tk.WORD, height=8)
        ch_text.pack(fill=tk.X)
        if not chrome_profiles:
            ch_text.insert(tk.END, "Chrome not installed for this user.\n")
        else:
            ch_text.insert(tk.END, "Profiles:\n")
            for p in chrome_profiles:
                ch_text.insert(tk.END, f"  {p}\n")
            ch_text.insert(tk.END, "\nExtensions (per profile):\n")
        ch_text.config(state=tk.DISABLED)
        ch_btns = tk.Frame(ch_f)
        ch_btns.pack(fill=tk.X, pady=5)
        for p in chrome_profiles:
            tk.Button(ch_btns, text=f"Reveal {p.name}", command=lambda pt=p: reveal_in_finder(pt)).pack(side=tk.LEFT, padx=5)
        ch_ext_frame = tk.LabelFrame(ch_f, text="Extensions — Remove (quit Chrome first)")
        ch_ext_frame.pack(fill=tk.BOTH, expand=True, pady=5)
        ch_ext_inner = tk.Frame(ch_ext_frame)
        ch_ext_inner.pack(fill=tk.BOTH, expand=True)
        for profile, exts in chrome_exts:
            for ext_id, ext_name in exts:
                fr = tk.Frame(ch_ext_inner)
                fr.pack(fill=tk.X)
                tk.Label(fr, text=f"{profile.name}: {ext_name} ({ext_id})", anchor=tk.W).pack(side=tk.LEFT, fill=tk.X, expand=True)
                tk.Button(fr, text="Remove", command=lambda pr=profile, eid=ext_id: self._remove_chrome_ext(pr, eid)).pack(side=tk.RIGHT)
        if chrome_managed:
            tk.Label(ch_f, text="Managed preferences (read-only):", font=("Helvetica", 10, "bold")).pack(anchor=tk.W)
            ch_managed_text = scrolledtext.ScrolledText(ch_f, wrap=tk.WORD, height=6)
            ch_managed_text.pack(fill=tk.BOTH, expand=True)
            ch_managed_text.insert(tk.END, chrome_managed)
            ch_managed_text.config(state=tk.DISABLED)

        # Firefox tab
        ff_f = tk.Frame(nb, padx=10, pady=10)
        nb.add(ff_f, text="Firefox")
        ff_text = scrolledtext.ScrolledText(ff_f, wrap=tk.WORD, height=6)
        ff_text.pack(fill=tk.X)
        if not ff_profiles:
            ff_text.insert(tk.END, "Firefox may not be installed.\n")
        else:
            for p in ff_profiles:
                ff_text.insert(tk.END, f"Profile: {p.name}\n")
        ff_text.config(state=tk.DISABLED)
        ff_btns = tk.Frame(ff_f)
        ff_btns.pack(fill=tk.X, pady=5)
        for p in ff_profiles:
            tk.Button(ff_btns, text=f"Reveal {p.name}", command=lambda pt=p: reveal_in_finder(pt)).pack(side=tk.LEFT, padx=5)
        ff_ext_frame = tk.LabelFrame(ff_f, text="Extensions — Remove (quit Firefox first)")
        ff_ext_frame.pack(fill=tk.BOTH, expand=True, pady=5)
        ff_ext_inner = tk.Frame(ff_ext_frame)
        ff_ext_inner.pack(fill=tk.BOTH, expand=True)
        for profile, exts in ff_exts:
            for ext_id, ext_name, kind in exts:
                fr = tk.Frame(ff_ext_inner)
                fr.pack(fill=tk.X)
                tk.Label(fr, text=f"{profile.name}: {ext_name} ({ext_id})", anchor=tk.W).pack(side=tk.LEFT, fill=tk.X, expand=True)
                tk.Button(fr, text="Remove", command=lambda pr=profile, eid=ext_id: self._remove_firefox_ext(pr, eid)).pack(side=tk.RIGHT)
        if ff_policies:
            tk.Label(ff_f, text="Global policies (read-only):", font=("Helvetica", 10, "bold")).pack(anchor=tk.W)
            ff_pol_text = scrolledtext.ScrolledText(ff_f, wrap=tk.WORD, height=4)
            ff_pol_text.pack(fill=tk.BOTH, expand=True)
            ff_pol_text.insert(tk.END, ff_policies)
            ff_pol_text.config(state=tk.DISABLED)

        # Safari tab
        saf_f = tk.Frame(nb, padx=10, pady=10)
        nb.add(saf_f, text="Safari")
        saf_text = scrolledtext.ScrolledText(saf_f, wrap=tk.WORD, height=4)
        saf_text.pack(fill=tk.X)
        saf_text.insert(tk.END, f"Default search provider: {safari_search}\n")
        saf_text.insert(tk.END, f"Home page: {safari_home}\n")
        saf_text.config(state=tk.DISABLED)
        saf_btns = tk.Frame(saf_f)
        saf_btns.pack(fill=tk.X, pady=5)
        tk.Button(saf_btns, text="Change home page…", command=lambda: self._change_safari_home(safari_home)).pack(side=tk.LEFT, padx=5)
        tk.Button(saf_btns, text="Change search provider…", command=lambda: self._change_safari_search(safari_search)).pack(side=tk.LEFT, padx=5)
        saf_ext_frame = tk.LabelFrame(saf_f, text="Extensions — Remove (quit Safari first)")
        saf_ext_frame.pack(fill=tk.BOTH, expand=True, pady=5)
        for ext_name, _, ext_path in safari_exts:
            fr = tk.Frame(saf_ext_frame)
            fr.pack(fill=tk.X)
            tk.Label(fr, text=ext_name, anchor=tk.W).pack(side=tk.LEFT, fill=tk.X, expand=True)
            tk.Button(fr, text="Remove", command=lambda ep=ext_path: self._remove_safari_ext(ep)).pack(side=tk.RIGHT)
        if safari_managed:
            tk.Label(saf_f, text="Managed preferences (read-only):", font=("Helvetica", 10, "bold")).pack(anchor=tk.W)
            saf_managed_text = scrolledtext.ScrolledText(saf_f, wrap=tk.WORD, height=4)
            saf_managed_text.pack(fill=tk.BOTH, expand=True)
            saf_managed_text.insert(tk.END, safari_managed)
            saf_managed_text.config(state=tk.DISABLED)

        # Summary tab
        sum_f = tk.Frame(nb, padx=10, pady=10)
        nb.add(sum_f, text="Summary")
        sum_text = scrolledtext.ScrolledText(sum_f, wrap=tk.WORD)
        sum_text.pack(fill=tk.BOTH, expand=True)
        sum_text.insert(tk.END, "Summary: Suspicious Flags\n")
        sum_text.insert(tk.END, "===============================\n")
        if not self.suspicious_matches:
            sum_text.insert(tk.END, "No known bad patterns matched. Manual review still recommended.\n")
        else:
            sum_text.insert(tk.END, "Potential issues detected in:\n")
            for m in self.suspicious_matches:
                sum_text.insert(tk.END, f"  - {m}\n")
        sum_text.insert(tk.END, "\n----------------------------------------\n")
        sum_text.insert(tk.END, "Macktechs Browser Health Check\n")
        sum_text.insert(tk.END, "https://fix.macktechs.com\n")
        sum_text.insert(tk.END, "If you're not sure how to read this report,\n")
        sum_text.insert(tk.END, "please email this file to support@macktechs.com\n")
        sum_text.config(state=tk.DISABLED)

    def _remove_login_item(self, name):
        if not messagebox.askyesno("Remove login item", f"Remove login item \"{name}\"?"):
            return
        if remove_login_item(name):
            messagebox.showinfo("Done", f"Login item \"{name}\" removed. Re-scan to refresh the list.")
        else:
            messagebox.showerror("Error", "Could not remove login item. Check Accessibility permission for this app.")

    def _remove_chrome_ext(self, profile_path, ext_id):
        if not messagebox.askyesno("Remove extension", "Quit Chrome first, then remove this extension. Continue?"):
            return
        if remove_chrome_extension(profile_path, ext_id):
            messagebox.showinfo("Done", "Extension removed. Re-scan to refresh.")
        else:
            messagebox.showerror("Error", "Could not remove extension.")

    def _remove_firefox_ext(self, profile_path, addon_id):
        if not messagebox.askyesno("Remove extension", "Quit Firefox first, then remove this extension. Continue?"):
            return
        if remove_firefox_extension(profile_path, addon_id):
            messagebox.showinfo("Done", "Extension removed. Re-scan to refresh.")
        else:
            messagebox.showerror("Error", "Could not remove extension.")

    def _remove_safari_ext(self, ext_path):
        if not messagebox.askyesno("Remove extension", "Quit Safari first, then remove this extension. Continue?"):
            return
        if remove_safari_extension(ext_path):
            messagebox.showinfo("Done", "Extension removed. Re-scan to refresh.")
        else:
            messagebox.showerror("Error", "Could not remove extension.")

    def _change_safari_home(self, current):
        url = simpledialog.askstring("Safari home page", "Enter home page URL:", initialvalue=current or "https://www.google.com")
        if url is None:
            return
        if set_safari_homepage(url):
            messagebox.showinfo("Done", "Home page updated. Re-scan to refresh.")
        else:
            messagebox.showerror("Error", "Could not set home page.")

    def _change_safari_search(self, current):
        url = simpledialog.askstring(
            "Safari search provider",
            "Enter search provider ID (e.g. com.google, com.duckduckgo):",
            initialvalue=current or "com.google",
        )
        if url is None:
            return
        if set_safari_search_provider(url):
            messagebox.showinfo("Done", "Search provider updated. Re-scan to refresh.")
        else:
            messagebox.showerror("Error", "Could not set search provider.")

    def _save_report(self):
        from datetime import datetime
        path = DESKTOP / f"browser_health_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        arch = subprocess.run(["uname", "-m"], capture_output=True, text=True).stdout.strip()
        ver = platform.mac_ver()[0]
        lines = [
            "Macktechs Browser Health Check Report",
            f"Generated: {datetime.now()}",
            f"Architecture: {arch}",
            f"macOS Version: {ver}",
            "",
            "===============================",
            "System: /etc/hosts",
            "===============================",
            self.report_data.get("hosts", ""),
            "",
            "===============================",
            "System: DNS Servers for Wi-Fi",
            "===============================",
            self.report_data.get("dns", ""),
            "",
            "===============================",
            "System: Proxy Settings for Wi-Fi",
            "===============================",
            self.report_data.get("proxy", ""),
            "",
            "===============================",
            "Summary: Suspicious Flags",
            "===============================",
        ]
        if not self.suspicious_matches:
            lines.append("No known bad patterns matched. Manual review still recommended.")
        else:
            lines.append("Potential issues detected in:")
            for m in self.suspicious_matches:
                lines.append(f"  - {m}")
        lines.extend([
            "",
            "----------------------------------------",
            "Macktechs Browser Health Check",
            "https://fix.macktechs.com",
            "If you're not sure how to read this report,",
            "please email this file to support@macktechs.com",
        ])
        path.write_text("\n".join(lines), encoding="utf-8")
        messagebox.showinfo("Report saved", f"Report saved to:\n{path}")

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    app = BrowserHealthCheckApp()
    app.run()
