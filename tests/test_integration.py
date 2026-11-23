import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class IntegrationTest(unittest.TestCase):
    def setUp(self):
        for module in ("pexpect", "packaging"):
            try:
                __import__(module)
            except ImportError:
                self.skipTest("%s is not installed" % module)
        if not shutil.which("xsltproc"):
            self.skipTest("xsltproc is not installed")

    def test_stdenv_column(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            config = tmp / "test.cfg"
            config.write_text(
                "[Configuration]\n"
                "style = lmod\n"
                "command = %s -o spider-json\n"
                "paths = /fake\n"
                % (ROOT / "tests" / "fake-spider")
            )
            xml = tmp / "modules.xml"
            subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "modules.py"),
                    "-c",
                    str(config),
                    "-w",
                    str(ROOT / "module_wiki_page.json"),
                    "-o",
                    str(xml),
                ],
                check=True,
                cwd=str(ROOT),
            )
            output = subprocess.run(
                ["xsltproc", str(ROOT / "modules-to-mediawiki.xsl"), str(xml)],
                check=True,
                capture_output=True,
                text=True,
            ).stdout

        self.assertIn("| StdEnv", output)
        self.assertIn("StdEnv/2020", output)
        self.assertIn("StdEnv/2023", output)
        self.assertEqual(
            output.count("[https://gcc.gnu.org/ gcc]"),
            1,
            "gcc should have one merged Module cell",
        )
        self.assertIn(
            'rowspan="2" | [https://gcc.gnu.org/ gcc]',
            output,
            "the gcc cell should span both StdEnv rows",
        )
        self.assertEqual(
            output.count('rowspan="2"'),
            3,
            "gcc, openmpi, and python should each span two rows",
        )
        self.assertNotIn('rowspan="1"', output)
        self.assertNotIn("hiddenpkg", output)


if __name__ == "__main__":
    unittest.main()
