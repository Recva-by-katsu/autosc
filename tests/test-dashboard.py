#!/usr/bin/env python3
import datetime as dt
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("dashboard", ROOT / "data/dashboard.py")
dashboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dashboard)
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def fixture():
    return dict(title="GEMILANG KINASIH STORE", system="Debian GNU/Linux 12 (bookworm)",
                ram="751 / 3915 MB", uptime="13 hours, 50 minutes", ip="192.0.2.10",
                isp="Example Hosting, LLC", domain="demo.example.com",
                states={"PROXY": "ON", "NGINX": "ON", "SSHWS": "ON"}, counts=["0"] * 4,
                version="1.3.0", update="LAST UPDATE", username="demo", expiry="N/A [NOT CONFIGURED]",
                traffic={"today": "62.86M", "yesterday": "0.00M", "month": "62.86M"})


class DashboardTests(unittest.TestCase):
    def test_layout_width_and_encoding(self):
        for width in (32, 40, 60, 80):
            for ascii_mode in (False, True):
                for color in (False, True):
                    with self.subTest(width=width, ascii=ascii_mode, color=color):
                        output = dashboard.Panel(width, color, ascii_mode).render(fixture())
                        output.encode("utf-8").decode("utf-8", errors="strict")
                        plain = ANSI.sub("", output)
                        self.assertNotIn(r"\033", plain)
                        self.assertNotIn("\ufffd", plain)
                        self.assertTrue(all(dashboard.cells(line) <= min(width, 60)
                                            for line in plain.splitlines()))
                        if not color:
                            self.assertNotIn("\x1b", output)
                        if ascii_mode:
                            plain.encode("ascii")
                        for label in ("SYSTEM", "RAM", "UPTIME", "IP VPS", "ISP", "DOMAIN",
                                      "PROXY", "NGINX", "SSHWS", "SSHWS OVPN", "XRAY VMESS",
                                      "XRAY VLESS", "XRAY TROJN", "VERSION SC", "USERNAME",
                                      "EXPIRED SC", "TODAY", "YESTERDAY", "MONTH"):
                            self.assertIn(label, plain)

    def test_long_values_and_controls(self):
        data = fixture()
        data["domain"] = "測試" * 100 + "\x1b\n\t"
        data["title"] = "a" * 200
        text = dashboard.Panel(40, False).render(data)
        self.assertTrue(all(dashboard.cells(line) <= 40 for line in text.splitlines()))
        self.assertNotIn("\x1b", text)

    def test_account_deduplication(self):
        self.assertEqual(dashboard.accounts("### alice 2026-10-01\n### alice 2026-10-01\n### bob 2026-10-01", "###"), "2")
        self.assertEqual(dashboard.accounts("alice\nalice\nbob"), "2")
        self.assertEqual(dashboard.accounts("{}", "###"), "0")
        self.assertEqual(dashboard.accounts("", "###"), "N/A")

    def test_bandwidth_dates_units_and_interface(self):
        record = lambda day, rx: {"date": {"year": 2026, "month": 9, "day": day}, "rx": rx, "tx": 0}
        raw = json.dumps({"jsonversion": "2", "interfaces": [
            {"name": "eth0", "traffic": {"day": [record(15, 1048576), record(14, 2097152)],
                                         "month": [record(1, 3145728)]}},
            {"name": "lo", "traffic": {}}]})
        self.assertEqual(dashboard.traffic(raw, "eth0", dt.date(2026, 9, 15)),
                         {"today": "1.00M", "yesterday": "2.00M", "month": "3.00M"})
        for value in ("", "{}", raw.replace('"2"', '"1"'), "broken"):
            self.assertEqual(dashboard.traffic(value, "eth0", dt.date.today())["today"], "N/A")
        self.assertEqual(dashboard.traffic(raw, "missing", dt.date.today())["today"], "N/A")

    def test_collection_missing_and_real_data(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(dashboard, "ROOT", Path(directory)), patch.object(dashboard, "command", return_value=""):
            data = dashboard.collect()
            self.assertEqual(data["counts"], ["N/A"] * 4)
            self.assertEqual(data["expiry"], "N/A [NOT CONFIGURED]")
            self.assertEqual(set(data["states"].values()), {"N/A"})
            for name, value in {"etc/xray/ssh.txt": "", "etc/xray/config.json": "{}",
                                "etc/os-release": 'PRETTY_NAME="Ubuntu 22.04 LTS"',
                                "etc/katsutun/dashboard.json": '{"title":"MY STORE","username":"owner"}'}.items():
                path = Path(directory) / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(value)
            data = dashboard.collect()
            self.assertEqual(data["counts"], ["0"] * 4)
            self.assertEqual(data["system"], "Ubuntu 22.04 LTS")
            self.assertEqual(data["title"], "MY STORE")
            self.assertEqual(data["username"], "owner")

    def test_installation_and_menu_routes(self):
        manifest = (ROOT / "data/manifest.txt").read_text()
        self.assertIn("data/dashboard.py", manifest)
        destinations = [line.split()[1] for line in manifest.splitlines()
                        if line.strip() and not line.startswith("#")]
        self.assertEqual(len(destinations), len(set(destinations)))
        menu = (ROOT / "data/menu.sh").read_text()
        for command in ("menu-ssh", "menu-vmess", "menu-vless", "menu-trojan", "menu-ss",
                        "menu-dns", "menu-theme", "menu-backup", "menu-set", "menu-api", "menu-update"):
            self.assertIn("exec " + command, menu)
        profile = (ROOT / "data/profile").read_text()
        self.assertNotIn("read -n", profile)
        self.assertIn("katsu-dashboard", profile)

    def test_cli_with_isolated_vps_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, value in {"etc/os-release": 'PRETTY_NAME="Debian GNU/Linux 12"',
                                "etc/xray/domain": "isolated.example", "etc/lukman/ip": "192.0.2.30",
                                "etc/lukman/isp": "Fixture ISP", "opt/.ver": "1.3.0",
                                "etc/xray/ssh.txt": "alice\nbob\n", "etc/xray/config.json": "{}"}.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(value)
            bindir = root / "bin"
            bindir.mkdir()
            for name, output in {"free": " total used\nMem: 2048 256",
                                 "uptime": "up 2 hours", "systemctl": "active",
                                 "katsu-update": "STATE=available", "ip": "", "vnstat": "{}"}.items():
                path = bindir / name
                path.write_text("#!/bin/sh\nprintf '%s\\n' '" + output + "'\n")
                path.chmod(0o755)
            result = subprocess.run([sys.executable, str(ROOT / "data/dashboard.py")],
                                    env=dict(os.environ, PATH=str(bindir), KATSU_DASHBOARD_ROOT=str(root),
                                             NO_COLOR="1", COLUMNS="60"), capture_output=True, check=True)
            text = result.stdout.decode("utf-8", errors="strict")
            self.assertEqual(result.stderr, b"")
            for value in ("isolated.example", "192.0.2.30", "256 / 2048 MB", "2 hours", "UPDATE AVAILABLE"):
                self.assertIn(value, text)


if __name__ == "__main__":
    unittest.main()
