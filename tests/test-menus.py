#!/usr/bin/env python3
"""Render every menu front screen against a stub VPS and check the frame.

Each script is run with EOF on stdin so it draws its screen and exits at the
prompt. Paths and commands are redirected to a temporary root; nothing on the
host is read or modified.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(r"\x1b\[[0-9;]*m")
MENUS = ["menu", "menu-ssh", "menu-vmess", "menu-vless", "menu-trojan", "menu-ss", "menu-dns",
         "menu-backup", "menu-set", "menu-api", "menu-update", "menu-bot", "menu-ip", "menu-tcp",
         "autoboot"]
STUBS = {
    "systemctl": 'case "$*" in *autosc-api*) echo inactive; exit 3;; *is-active*|*ActiveState*) echo active;; esac',
    "free": "printf 'x\\nMem: 3915 751 3164\\n'",
    "uptime": 'echo "up 2 hours"',
    "vnstat": 'echo "{}"',
    "ip": 'echo "default via 192.0.2.1 dev eth0"',
    "katsu-update": "printf 'STATE=uptodate\\nLATEST=abc1234\\nAUTO_UPDATE=on\\nVERSION=1.3.0\\nCOMMIT=abc1234\\nINTERVAL=5\\nRESTART_SERVICES=on\\nREPO=demo/autosc\\nBRANCH=main\\nLASTCHECK=never\\n'",
    "clear": "exit 0", "wget": "exit 0", "curl": "exit 0", "hostname": "echo vps", "tput": "echo 60",
    "ps": "exit 0", "netstat": "exit 0", "python3": "exit 0",
}


class MenuScreens(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name)
        for name, body in STUBS.items():
            path = root / "bin" / name
            path.parent.mkdir(exist_ok=True)
            path.write_text("#!/bin/sh\n" + body + "\n")
            path.chmod(0o755)
        files = {
            "etc/katsutun/repo.conf": 'BRAND=KatsuTun; RAW=http://127.0.0.1/none; REPO_URL=x\n',
            "etc/yudhynetwork/theme/color.conf": "blue\n",
            "etc/xray/domain": "demo.example\n", "etc/xray/ssh.txt": "alice\n",
            "etc/xray/config.json": "{}", "etc/lukman/ip": "192.0.2.10\n", "etc/lukman/isp": "ISP\n",
            "opt/.ver": "1.3.0\n", "root/log-install.txt": "",
        }
        for name, value in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value)
        (root / "usr/local/lib/katsutun").mkdir(parents=True)
        cls.root = root

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def redirected(self, path):
        text = path.read_text()
        for absolute in ("/etc/katsutun/", "/usr/local/lib/katsutun/", "/etc/xray/", "/etc/lukman/",
                         "/opt/.ver", "/etc/yudhynetwork/", "/usr/bin/katsu-dashboard", "/root/"):
            text = text.replace(absolute, str(self.root) + absolute)
        return text

    def render(self, name, columns):
        (self.root / "usr/local/lib/katsutun/ui.sh").write_text(self.redirected(ROOT / "data/katsu-ui.sh"))
        dashboard = self.root / "bin/katsu-dashboard"
        dashboard.write_text((ROOT / "data/dashboard.py").read_text())
        dashboard.chmod(0o755)
        script = self.root / "run.sh"
        script.write_text(self.redirected(ROOT / f"data/{name}.sh"))
        env = dict(PATH=f"{self.root}/bin:/usr/bin:/bin", COLUMNS=str(columns), LC_ALL="C.UTF-8",
                   HOME=str(self.root / "root"), KATSU_DASHBOARD_ROOT=str(self.root), TERM="xterm")
        result = subprocess.run(["bash", str(script)], env=env, stdin=subprocess.DEVNULL,
                                capture_output=True, timeout=20)
        return result.stdout.decode("utf-8", errors="strict")

    def test_every_front_screen(self):
        for name in MENUS:
            for columns in (40, 60):
                with self.subTest(menu=name, cols=columns):
                    out = self.render(name, columns)
                    self.assertNotIn(r"\033", out)
                    self.assertNotIn("\ufffd", out)
                    self.assertNotIn("command not found", out)
                    self.assertNotIn("invalid octal", out)
                    plain = ANSI.sub("", out)
                    framed = [l for l in plain.splitlines() if l and l[0] in "╭│╰"]
                    self.assertTrue(framed, plain)
                    self.assertEqual({len(l) for l in framed}, {min(columns, 60)}, plain)
                    if "belum terpasang" not in plain:  # menu-api: legitimate not-installed screen
                        self.assertIn("[00] Back", plain)
                        self.assertIn("Select an option", plain)
                    self.assertNotIn("Select menu", plain)


if __name__ == "__main__":
    unittest.main()
