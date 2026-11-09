"""Physical count/custody examples, including late reports and quarantined returns."""

from copy import deepcopy
from pathlib import Path
import sys
import unittest


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src" / "python"))
from allfedo.inventory import project_stock


class InventoryProjectionTests(unittest.TestCase):
    def setUp(self):
        self.declaration = {"quantity": "40", "unit": "meal_box", "source_id": "1", "occurred_at": "2026-11-09T17:00:00Z"}

    def fact(self, kind, quantity, minute, source):
        return {"kind": kind, "quantity": str(quantity), "occurred_at": f"2026-11-09T17:{minute:02}:00Z", "source_id": str(source)}

    def count(self, quantity, minute, source):
        return {"on_hand_quantity": str(quantity), "occurred_at": f"2026-11-09T17:{minute:02}:00Z", "source_id": str(source)}

    def assert_review(self, result, code):
        self.assertTrue(result["review_required"], result)
        self.assertEqual(result["usable_on_hand_quantity"], "0")
        self.assertIsNone(result["current_total_quantity"])
        self.assertIn(code, {issue["code"] for issue in result["issues"]})

    def test_handoffs_reduce_original_stock_and_returns_never_restock_it(self):
        entries = [self.fact("handoff", 20, 10, 2), self.fact("returned", 5, 20, 3), self.fact("quarantine_disposed", 3, 25, 4)]
        result = project_stock(self.declaration, None, entries)
        self.assertFalse(result["review_required"])
        self.assertEqual(result["current_total_quantity"], "40")
        self.assertEqual(result["collected_quantity"], "20")
        self.assertEqual(result["quarantined_quantity"], "2")
        self.assertEqual(result["usable_on_hand_quantity"], "20")

    def test_count_includes_returned_boxes_but_they_stay_out_of_bookable_stock(self):
        entries = [self.fact("handoff", 20, 10, 2), self.fact("returned", 5, 20, 3)]
        observed = self.count(25, 30, 4)
        result = project_stock(self.declaration, observed, entries)
        self.assertEqual(result["current_total_quantity"], "40")
        self.assertEqual(result["usable_on_hand_quantity"], "20")
        entries += [self.fact("returned", 3, 35, 5), self.fact("quarantine_disposed", 2, 40, 6)]
        later = project_stock(self.declaration, observed, entries)
        self.assertEqual(later["current_total_quantity"], "40")
        self.assertEqual(later["usable_on_hand_quantity"], "20")
        self.assertEqual(later["quarantined_quantity"], "6")

    def test_late_handoff_before_count_is_not_subtracted_twice(self):
        observed = self.count(15, 30, 10)
        entries = [self.fact("handoff", 10, 20, 11), self.fact("handoff", 5, 40, 12)]
        result = project_stock(self.declaration, observed, entries)
        self.assertEqual(result["current_total_quantity"], "25")
        self.assertEqual(result["collected_quantity"], "15")
        self.assertEqual(result["usable_on_hand_quantity"], "10")

    def test_equal_time_handoffs_require_recount_regardless_of_recording_order(self):
        observed = self.count(30, 30, 10)
        for source in (9, 11):
            with self.subTest(source=source):
                result = project_stock(self.declaration, observed, [self.fact("handoff", 10, 30, source)])
                self.assert_review(result, "AMBIGUOUS_COUNT_TIME")
                self.assertEqual(result["collected_quantity"], "10")
        entries = [self.fact("handoff", 10, 30, 9), self.fact("handoff", 5, 30, 11)]
        self.assert_review(project_stock(self.declaration, self.count(25, 30, 12), entries), "AMBIGUOUS_COUNT_TIME")
        fresh = project_stock(self.declaration, self.count(25, 31, 12), entries)
        self.assertFalse(fresh["review_required"])
        self.assertEqual(fresh["usable_on_hand_quantity"], "25")

    def test_equal_time_returns_and_disposals_require_recount_in_both_recording_orders(self):
        for kind in ("returned", "quarantine_disposed"):
            for source in (9, 11):
                with self.subTest(kind=kind, source=source):
                    entries = [self.fact("handoff", 20, 10, 2), self.fact("returned", 5, 20, 3), self.fact(kind, 2, 30, source)]
                    result = project_stock(self.declaration, self.count(25, 30, 10), entries)
                    self.assert_review(result, "AMBIGUOUS_COUNT_TIME")

    def test_fractional_physical_times_decide_inclusion_even_when_source_ids_disagree(self):
        observed = dict(self.count(30, 30, 10), occurred_at="2026-11-09T17:30:10.500Z")
        entries = [dict(self.fact("handoff", 10, 30, 11), occurred_at="2026-11-09T17:30:10.499Z"),
                   dict(self.fact("handoff", 5, 30, 9), occurred_at="2026-11-09T17:30:10.501Z")]
        result = project_stock(self.declaration, observed, entries)
        self.assertFalse(result["review_required"])
        self.assertEqual(result["current_total_quantity"], "40")
        self.assertEqual(result["usable_on_hand_quantity"], "25")

    def test_equal_time_custody_balances_ignore_recording_order(self):
        for handoff_source, return_source, disposal_source in ((4, 3, 2), (2, 3, 4)):
            with self.subTest(handoff_source=handoff_source):
                entries = [self.fact("quarantine_disposed", 3, 30, disposal_source),
                           self.fact("returned", 5, 30, return_source),
                           self.fact("handoff", 10, 30, handoff_source)]
                result = project_stock(self.declaration, self.count(32, 31, 5), entries)
                self.assertFalse(result["review_required"], result)
                self.assertEqual(result["current_total_quantity"], "40")
                self.assertEqual(result["collected_quantity"], "10")
                self.assertEqual(result["quarantined_quantity"], "2")
                self.assertEqual(result["usable_on_hand_quantity"], "30")
                self.assertEqual(result, project_stock(self.declaration, self.count(32, 31, 5), list(reversed(entries))))
                self.assert_review(project_stock(self.declaration, self.count(32, 30, 5), entries), "AMBIGUOUS_COUNT_TIME")

    def test_impossible_equal_time_custody_totals_remain_in_review_after_a_later_count(self):
        for returned, disposed, code in ((11, 3, "RETURN_EXCEEDS_HANDOFF"), (5, 6, "DISPOSAL_EXCEEDS_QUARANTINE")):
            with self.subTest(code=code):
                entries = [self.fact("quarantine_disposed", disposed, 30, 2),
                           self.fact("returned", returned, 30, 3), self.fact("handoff", 10, 30, 4)]
                result = project_stock(self.declaration, self.count(32, 31, 5), entries)
                self.assert_review(result, code)
                self.assertIsNone(result["quarantined_quantity"])

    def test_old_aggregate_keeps_its_quantity_without_fabricating_handoff_times(self):
        self.declaration.update(legacy_collected_quantity="20", legacy_recorded_until="2026-11-09T17:20:00Z")
        result = project_stock(self.declaration, self.count(15, 30, 3), [self.fact("handoff", 5, 40, 4)])
        self.assertEqual(result["current_total_quantity"], "35")
        self.assertEqual(result["collected_quantity"], "25")
        self.assertEqual(result["usable_on_hand_quantity"], "10")
        too_old = project_stock(self.declaration, self.count(15, 10, 3), [])
        self.assert_review(too_old, "COUNT_PRECEDES_LEGACY_BOUND")
        self.assertEqual(too_old["collected_quantity"], "20")

    def test_contradictory_quarantine_and_shortages_pause_instead_of_making_stock(self):
        over_return = project_stock(self.declaration, None, [self.fact("handoff", 5, 10, 2), self.fact("returned", 6, 20, 3)])
        self.assert_review(over_return, "RETURN_EXCEEDS_HANDOFF")
        self.assertIsNone(over_return["quarantined_quantity"])
        over_disposal = project_stock(self.declaration, None, [self.fact("quarantine_disposed", 2, 10, 2), self.fact("returned", 2, 20, 3)])
        self.assert_review(over_disposal, "DISPOSAL_EXCEEDS_QUARANTINE")
        self.assertIsNone(over_disposal["quarantined_quantity"])
        missing = project_stock(self.declaration, self.count(5, 30, 3), [self.fact("handoff", 6, 40, 4)])
        self.assert_review(missing, "HANDOFF_EXCEEDS_STOCK")
        count_below_returns = project_stock(self.declaration, self.count(3, 30, 4), [self.fact("handoff", 10, 10, 2), self.fact("returned", 5, 20, 3)])
        self.assert_review(count_below_returns, "COUNT_BELOW_QUARANTINE")

    def test_input_order_offsets_and_input_objects_do_not_change_the_result(self):
        entries = [self.fact("returned", 5, 20, 3), self.fact("handoff", 10, 10, 2)]
        saved = deepcopy(entries)
        observed = self.count(35, 30, 4)
        result = project_stock(self.declaration, observed, entries)
        self.assertEqual(entries, saved)
        self.assertEqual(result, project_stock(self.declaration, observed, list(reversed(entries))))
        observed["occurred_at"] = "2026-11-10T00:00:00+06:30"
        self.assertEqual(result, project_stock(self.declaration, observed, entries))

    def test_bad_units_types_duplicate_sources_and_unknown_times_fail_explicitly(self):
        for changes in ({"unit": "kg"}, {"quantity": "1.5"}, {"quantity": True}, {"occurred_at": "17:00"}, {"occurred_at": "2026-11-09T17:00:00"}, {"source_id": "external-source"}, {"legacy_collected_quantity": "5"}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                project_stock(dict(self.declaration, **changes), None, [])
        with self.assertRaises(ValueError):
            project_stock(self.declaration, self.count(20, 30, 1), [])
        with self.assertRaises(ValueError):
            project_stock(self.declaration, None, [dict(self.fact("returned", 1, 10, 2), unit="tray")])


if __name__ == "__main__":
    unittest.main()
