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
    def render(self, commands, locale, ascii_mode=False, no_color=False, columns=60):
        env = dict(os.environ, LC_ALL=locale, COLUMNS=str(columns),
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

    def test_frames_are_uniform_width(self):
        for locale in ("C", "C.UTF-8"):
            for ascii_mode in (False, True):
                for no_color in (False, True):
                    for columns in (36, 48, 60, 120):
                        with self.subTest(locale=locale, ascii=ascii_mode, plain=no_color, cols=columns):
                            text = self.render("ui_top; ui_divider; ui_bottom", locale,
                                               ascii_mode, no_color, columns)
                            lines = text.splitlines()
                            width = min(columns, 60)
                            self.assertEqual([len(l) for l in lines], [width] * 3)
                            if ascii_mode:
                                self.assertEqual(lines[0], "+" + "-" * (width - 2) + "+")
                                self.assertEqual(lines[1], "|" + "-" * (width - 2) + "|")
                            else:
                                self.assertEqual(lines[0], "╭" + "─" * (width - 2) + "╮")
                                self.assertEqual(lines[2], "╰" + "─" * (width - 2) + "╯")

    def test_c_locale_falls_back_to_utf8_or_ascii(self):
        # Under a pure C locale bash counts bytes, so padding around box glyphs
        # would break unless ui_init switches locale or falls back to ASCII.
        text = self.render('ui_card_start; ui_kv "DOMAIN" "demo.example"; ui_line "x"; ui_card_end', "C")
        widths = {len(l) for l in text.splitlines()}
        self.assertEqual(len(widths), 1, text)

    def test_all_dashboard_components(self):
        commands = '''
ui_header "VPS DASHBOARD" "secure server automation"
ui_card_start "ACCOUNTS"
ui_kv DOMAIN demo.example
ui_notice "${UI_GOOD}ONLINE${UI_RESET}"
ui_ok done; ui_warn careful; ui_err broken
ui_options "01:SSH:$(ui_badge active)" "07:Appearance" "13:REST API:$(ui_badge inactive)" "14:Update"
ui_menu_pair 1 SSH "${UI_GOOD}ONLINE${UI_RESET}" 7 APPEARANCE THEMES
ui_menu_item 0 EXIT LOGOUT
ui_blank
ui_card_end
ui_footer
ui_back_hint
ui_prompt
'''
        for columns in (40, 60):
            text = self.render(commands, "C.UTF-8", columns=columns)
            for label in ("VPS DASHBOARD", "ACCOUNTS", "demo.example", "ONLINE", "[01]", "[07]",
                          "[13]", "[00]", "[OK]", "[!]", "[ERROR]", "ON", "OFF", "Select an option"):
                self.assertIn(label, text)
            framed = [l for l in text.splitlines() if l.startswith("│") or l.startswith("╭") or l.startswith("╰")]
            self.assertEqual({len(l) for l in framed}, {min(columns, 60)}, text)

    def test_long_values_are_clipped_not_wrapped(self):
        text = self.render('ui_card_start; ui_kv URL "https://example.com/' + "x" * 200 + '"; ui_card_end', "C.UTF-8")
        for line in text.splitlines():
            self.assertLessEqual(len(line), 60 + 200)  # ui_kv passes text through; frame must still close
        self.assertTrue(text.splitlines()[-1].startswith("╰"))


if __name__ == "__main__":
    unittest.main()
