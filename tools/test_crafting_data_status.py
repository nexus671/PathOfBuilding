import unittest

from crafting_data_status import FILES, assess, require_changed_export, require_exported, require_supported_granted_effects, version


class CraftingDataStatusTest(unittest.TestCase):
    def test_new_client_does_not_mean_export_is_ready(self):
        self.assertEqual("export_pending", assess("3.29.3.6", "3.30.0.1", "3.29.3.6", {})["status"])
        with self.assertRaisesRegex(ValueError, "wait for the export"):
            require_exported("3.30.0.1", "3.29.3.6")

    def test_new_version_with_identical_data_needs_review(self):
        old = {name: "old" for name in FILES}
        self.assertEqual("version_only", assess("3.29.3.6", "3.30.0.1", "3.30.0.1", old, old)["status"])
        with self.assertRaisesRegex(ValueError, "previous patch"):
            require_changed_export("3.30.0.1", "3.29.3.6", old, old)
        require_changed_export("3.30.0.1", "3.29.3.6", old, old, allow_identical=True)
        self.assertEqual("unchanged", assess("3.29.3.6", "3.29.3.6", "3.29.3.6", old, old)["status"])
        new = dict(old, **{"mods.json": "new"})
        require_changed_export("3.30.0.1", "3.29.3.6", old, new)
        result = assess("3.29.3.6", "3.30.0.1", "3.30.0.1", old, new)
        self.assertEqual("review_required", result["status"])
        self.assertEqual(["mods.json"], result["changedFiles"])
        with self.assertRaisesRegex(ValueError, "hashes"):
            assess("3.29.3.6", "3.30.0.1", "3.30.0.1", old, {})

    def test_versions_are_checked_before_importing(self):
        self.assertEqual("3.29.3.6", version(b"\xef\xbb\xbf3.29.3.6\n"))
        require_exported("3.29.3.6", "3.29.3.6")
        with self.assertRaises(ValueError):
            version(b"3.30.example")

    def test_rejects_zeroed_support_levels_with_granted_effects(self):
        stat = {"id": "local_display_socketed_gems_get_remote_mine_level", "min": 18, "max": 18}
        previous = {"mine": {"stats": [stat]}}
        candidate = {"mine": {"stats": [dict(stat, min=0, max=0)],
                              "grants_effects": [{"level": 18}]}}
        with self.assertRaisesRegex(ValueError, "zeroed display values"):
            require_supported_granted_effects(previous, candidate)
        candidate["mine"]["stats"][0] = stat
        require_supported_granted_effects(previous, candidate)
        candidate["mine"]["stats"][0] = dict(stat, min=0, max=0)
        candidate["mine"]["grants_effects"] = []
        require_supported_granted_effects(previous, candidate)


if __name__ == "__main__":
    unittest.main()
