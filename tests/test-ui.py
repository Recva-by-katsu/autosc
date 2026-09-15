#!/usr/bin/env python3
"""Check terminal bytes, not just shell syntax or replacement-decoded text."""
import os
from pathlib import Path
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(r"\x1b\[[0-9;]*m")


class TerminalRenderingTest(unittest.TestCase):
    def render(self, commands, locale, ascii_mode=False, no_color=False):
        env = dict(os.environ, LC_ALL=locale,
                   KATSU_ASCII=str(int(ascii_mode)),
                   NO_COLOR="1" if no_color else "")
        result = subprocess.run(
            ["bash", "-c", '. "$1"; ui_init; ' + commands,
             "test-ui", str(ROOT / "data/katsu-ui.sh")],
            env=env, check=True, capture_output=True,
        )
        self.assertEqual(result.stderr, b"")
        text = result.stdout.decode("utf-8", errors="strict")
        self.assertNotIn("\ufffd", text)
        self.assertNotIn(r"\033", text)
        if no_color:
            self.assertNotIn("\x1b", text)
        return ANSI.sub("", text)

    def test_exact_borders(self):
        for locale in ("C", "C.UTF-8"):
            for ascii_mode in (False, True):
                for no_color in (False, True):
                    with self.subTest(locale=locale, ascii=ascii_mode, plain=no_color):
                        text = self.render("ui_top; ui_divider; ui_bottom", locale,
                                           ascii_mode, no_color)
                        if ascii_mode:
                            expected = ["+" + "-" * 57 + "+",
                                        "|" + "-" * 57 + "|",
                                        "+" + "-" * 57 + "+"]
                        else:
                            expected = ["╭" + "─" * 57 + "╮",
                                        "│" + "─" * 57 + "│",
                                        "╰" + "─" * 57 + "╯"]
                        self.assertEqual(text.splitlines(), expected)

    def test_all_dashboard_components(self):
        commands = '''
ui_header "VPS DASHBOARD" "SECURE SERVER AUTOMATION"
ui_card_start
ui_kv DOMAIN demo.example
ui_notice "${UI_GOOD}ONLINE${UI_RESET}"
ui_menu_pair 1 SSH "${UI_GOOD}ONLINE${UI_RESET}" 7 APPEARANCE THEMES
ui_menu_item 0 EXIT LOGOUT
ui_blank
ui_card_end
ui_footer
ui_prompt
'''
        for locale in ("C", "C.UTF-8"):
            text = self.render(commands, locale)
            for label in ("VPS DASHBOARD", "demo.example", "ONLINE", "[01]",
                          "[07]", "[00]", "Select an option"):
                self.assertIn(label, text)


if __name__ == "__main__":
    unittest.main()
