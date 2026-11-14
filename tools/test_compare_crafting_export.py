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

    def test_reports_effect_levels_without_guessing_the_display_value(self):
        old_stat = {"id": "local_display_grants_skill_level", "min": 10, "max": 10}
        new_stat = dict(old_stat, min=0, max=0)
        effects = [{"granted_effect_id": "Skill", "level": 15},
                   {"granted_effect_id": "TriggeredSkill", "level": 15}]
        result = compare({"patch": "old", "mods": {"mod": {"stats": [old_stat]}}},
                         {"mod": {"stats": [new_stat], "grants_effects": effects}})
        self.assertEqual(result["zeroed_display_stats_with_granted_effects"], [{
            "modifier": "mod", "stat": old_stat["id"], "previous_min": 10,
            "previous_max": 10, "granted_effects": effects}])


if __name__ == "__main__":
    unittest.main()
