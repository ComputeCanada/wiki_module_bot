import unittest

from Module import Module, stack_for


class StackForTest(unittest.TestCase):
    def test_stdenv_core(self):
        self.assertEqual(
            stack_for({"parentAA": [["StdEnv/2023"]]}),
            "StdEnv/2023",
        )

    def test_stdenv_toolchain(self):
        self.assertEqual(
            stack_for({"parentAA": [["StdEnv/2023", "gcc/12.3"]]}),
            "StdEnv/2023",
        )

    def test_gentoo_fallback(self):
        self.assertEqual(
            stack_for({"parentAA": [["gentoo/2020", "gcc/9.3.0"]]}),
            "StdEnv/2020",
        )

    def test_unknown(self):
        self.assertEqual(stack_for({}), "-")

    def test_nixpkgs_is_ambiguous(self):
        self.assertEqual(stack_for({"parentAA": [["nixpkgs/16.09"]]}), "-")

    def test_module_defaults_to_unknown(self):
        self.assertEqual(Module("gcc/12.3", "help", _prereq_list=[]).stack, "-")

    def test_module_keeps_stack(self):
        module = Module("gcc/12.3", "help", _prereq_list=[], _stack="StdEnv/2023")
        self.assertEqual(module.stack, "StdEnv/2023")


if __name__ == "__main__":
    unittest.main()
