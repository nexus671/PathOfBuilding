import unittest

from compare_crafting_export import compare


class CompareCraftingExportTest(unittest.TestCase):
    def test_reports_missing_additional_and_changed_records(self):
        previous = {"patch": "old", "mods": {
            "same": {"groups": ["A"], "stats": [1]},
            "changed": {"groups": ["B"], "stats": [1]},
            "removed": {"groups": []},
        }}
        exported = {
            "same": {"groups": ["A"], "stats": [1]},
            "changed": {"groups": ["C"], "stats": [2]},
            "new": {"domain": "item"},
        }
        result = compare(previous, exported)
        self.assertEqual(result["missing_ids"], ["removed"])
        self.assertEqual(result["additional_count_by_domain"], {"item": 1})
        self.assertEqual(result["changed_ids_by_field"]["groups"], ["changed"])
        self.assertEqual(result["changed_ids_by_field"]["stats"], ["changed"])
        self.assertEqual(result["shared_count"], 2)


if __name__ == "__main__":
    unittest.main()
