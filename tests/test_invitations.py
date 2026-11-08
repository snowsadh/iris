"""Invitation eligibility checks, not simulations of database reservations."""

from copy import deepcopy
import json
from pathlib import Path
import sys
import unittest


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src" / "python"))
from allfedo.invitations import validate_invitation_plan


class InvitationPlanTests(unittest.TestCase):
    def setUp(self):
        self.snapshot = {
            "network_id": "local-network",
            "now": "2026-11-09T17:55:00Z",
            "offer": {
                "id": "kitchen-lot-14", "revision": 3, "network_id": "local-network",
                "available_quantity": "80", "unit": "meal_box", "state": "open",
                "ready_at": "2026-11-09T17:40:00Z", "collect_by": "2026-11-09T18:20:00Z",
                "source_ids": ["kitchen-confirmation-3"], "holding": "chilled",
                "present_allergens": ["milk"], "assessed_allergens": ["milk", "peanut"],
            },
            "needs": [
                {
                    "id": "riverside-dinner", "organization_id": "riverside",
                    "network_id": "local-network", "revision": 2,
                    "remaining_quantity": "35", "unit": "meal_box",
                    "receiving_until": "2026-11-09T19:00:00Z",
                    "confirmed_until": "2026-11-09T18:30:00Z",
                    "source_ids": ["riverside-confirmation-2"],
                    "excluded_allergens": ["peanut"], "accepted_holding": ["chilled"],
                },
                {
                    "id": "bridge-dinner", "organization_id": "bridge-centre",
                    "network_id": "local-network", "revision": 4,
                    "remaining_quantity": "45", "unit": "meal_box",
                    "receiving_until": "2026-11-09T18:45:00Z",
                    "confirmed_until": "2026-11-09T18:30:00Z",
                    "source_ids": ["bridge-confirmation-4"],
                    "excluded_allergens": [], "accepted_holding": ["chilled"],
                },
            ],
        }
        self.proposal = {
            "offer_id": "kitchen-lot-14", "offer_revision": 3,
            "requests": [
                {"need_id": "riverside-dinner", "need_revision": 2, "quantity": "35",
                 "unit": "meal_box", "evidence_ids": ["kitchen-confirmation-3", "riverside-confirmation-2"]},
                {"need_id": "bridge-dinner", "need_revision": 4, "quantity": "45",
                 "unit": "meal_box", "evidence_ids": ["kitchen-confirmation-3", "bridge-confirmation-4"]},
            ],
            "reason": "Both partners confirmed current needs and can receive chilled meal boxes.",
        }

    def validate(self):
        return validate_invitation_plan(self.snapshot, self.proposal)

    def assert_rejected(self, code, *, need_id=None):
        result = self.validate()
        self.assertFalse(result["ok"], result)
        self.assertEqual(result["error"]["code"], code, result)
        if need_id is not None:
            self.assertEqual(result["error"]["need_id"], need_id)
        self.assertTrue(result["error"]["message"])
        self.assertNotIn("plan", result)
        json.dumps(result)

    def test_current_plan_is_an_invitation_and_keeps_confirmations_unresolved(self):
        self.proposal["requests"][0]["quantity"] = "035.000"
        original_snapshot, original_proposal = deepcopy(self.snapshot), deepcopy(self.proposal)
        result = self.validate()
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["plan"]["requests"][0]["quantity"], "35")
        for row in result["plan"]["requests"]:
            self.assertEqual(set(row["confirmation_requirements"]), {
                "recipient_acceptance", "named_collector", "pickup_time",
                "transport_capacity", "food_handling_acceptance",
            })
            self.assertNotIn("collector", row)
            self.assertNotIn("status", row)
        self.assertEqual(self.snapshot, original_snapshot)
        self.assertEqual(self.proposal, original_proposal)
        json.dumps(result)

    def test_another_kitchen_consumes_shared_need_before_this_plan_is_applied(self):
        self.snapshot["needs"][0].update(revision=3, remaining_quantity="15")
        self.assert_rejected("STALE_NEED", need_id="riverside-dinner")
        self.proposal["requests"][0]["need_revision"] = 3
        self.assert_rejected("NEED_CAPACITY_CHANGED", need_id="riverside-dinner")
        self.proposal["requests"][0]["quantity"] = "15"
        self.assertTrue(self.validate()["ok"])

    def test_requests_cannot_duplicate_a_need_or_exceed_combined_lot_stock(self):
        self.snapshot["offer"]["available_quantity"] = "79"
        self.assert_rejected("INSUFFICIENT_STOCK")
        self.snapshot["offer"]["available_quantity"] = "80"
        self.proposal["requests"][1] = deepcopy(self.proposal["requests"][0])
        self.assert_rejected("DUPLICATE_NEED", need_id="riverside-dinner")

    def test_changed_offer_needs_review_and_closed_offers_cannot_send(self):
        self.snapshot["offer"]["revision"] = 4
        self.assert_rejected("STALE_OFFER")
        self.proposal["offer_revision"] = 4
        self.snapshot["offer"]["state"] = "paused"
        self.assert_rejected("OFFER_NOT_OPEN")
        self.snapshot["offer"]["state"] = "open"
        self.snapshot["now"] = self.snapshot["offer"]["collect_by"]
        self.assert_rejected("OFFER_EXPIRED")

    def test_needs_require_live_confirmation_and_a_possible_receiving_window(self):
        self.snapshot["needs"][0]["confirmed_until"] = self.snapshot["now"]
        self.assert_rejected("NEED_CONFIRMATION_EXPIRED", need_id="riverside-dinner")
        self.snapshot["needs"][0]["confirmed_until"] = "2026-11-09T18:30:00Z"
        self.snapshot["needs"][0]["receiving_until"] = self.snapshot["now"]
        self.assert_rejected("RECEIVING_WINDOW_ENDED", need_id="riverside-dinner")
        self.snapshot["needs"][0]["receiving_until"] = "2026-11-09T18:05:00Z"
        self.snapshot["offer"]["ready_at"] = "2026-11-09T18:05:00Z"
        self.assert_rejected("RECEIVING_WINDOW_ENDED", need_id="riverside-dinner")

    def test_offsets_and_calendar_midnight_are_compared_as_instants(self):
        self.snapshot["now"] = "2026-11-10T00:25:00+06:30"
        self.assertTrue(self.validate()["ok"])
        # These repeated local clock readings have different UTC offsets.
        self.snapshot["now"] = "2026-11-09T18:55:00+01:00"
        self.assertTrue(self.validate()["ok"])
        self.snapshot["now"] = "2026-11-09T18:55:00+00:00"
        self.assert_rejected("OFFER_EXPIRED")

    def test_unknown_food_constraints_are_not_treated_as_compatible(self):
        self.snapshot["needs"][0]["excluded_allergens"] = ["MILK"]
        self.assert_rejected("FOOD_INCOMPATIBLE", need_id="riverside-dinner")
        self.snapshot["needs"][0]["excluded_allergens"] = ["sesame"]
        self.assert_rejected("FOOD_INFORMATION_MISSING", need_id="riverside-dinner")
        self.snapshot["needs"][0]["excluded_allergens"] = []
        self.snapshot["offer"]["holding"] = None
        self.assert_rejected("FOOD_INFORMATION_MISSING")

    def test_handling_capability_must_be_known_and_match_food_holding(self):
        self.snapshot["needs"][0]["accepted_holding"] = []
        self.assert_rejected("HANDLING_CAPABILITY_UNKNOWN", need_id="riverside-dinner")
        self.snapshot["needs"][0]["accepted_holding"] = ["hot"]
        self.assert_rejected("HANDLING_INCOMPATIBLE", need_id="riverside-dinner")

    def test_sources_must_belong_to_the_selected_offer_and_need(self):
        row = self.proposal["requests"][0]
        row["evidence_ids"] = ["kitchen-confirmation-3", "bridge-confirmation-4"]
        self.assert_rejected("UNKNOWN_EVIDENCE", need_id="riverside-dinner")
        for evidence in (["kitchen-confirmation-3"], ["riverside-confirmation-2"], []):
            with self.subTest(evidence=evidence):
                row["evidence_ids"] = evidence
                self.assert_rejected("EVIDENCE_MISSING", need_id="riverside-dinner")
        row["need_id"] = "outside-network-need"
        self.assert_rejected("UNKNOWN_NEED", need_id="outside-network-need")

    def test_meal_boxes_cannot_be_negative_fractional_or_float_inputs(self):
        for quantity in ("0", "-1", "1.5", "NaN", "1e1", "1.0001", 35, 35.0, True, None):
            with self.subTest(quantity=quantity):
                self.proposal["requests"][0]["quantity"] = quantity
                self.assert_rejected("INVALID_QUANTITY")

    def test_units_require_explicit_policy_and_never_convert_silently(self):
        self.proposal["requests"][0]["unit"] = "kg"
        self.assert_rejected("UNIT_MISMATCH", need_id="riverside-dinner")
        self.snapshot["offer"]["unit"] = "kg"
        self.assert_rejected("UNIT_REQUIRES_REVIEW")
        self.snapshot["automatic_units"] = ["kg"]
        self.snapshot["offer"]["available_quantity"] = "8.5"
        for need, request in zip(self.snapshot["needs"], self.proposal["requests"]):
            need.update(unit="kg", remaining_quantity="4.25")
            request.update(unit="kg", quantity="4.250")
        result = self.validate()
        self.assertTrue(result["ok"], result)
        self.assertEqual([row["quantity"] for row in result["plan"]["requests"]], ["4.25", "4.25"])

    def test_model_cannot_invent_confirmations_or_extend_the_proposal_shape(self):
        self.proposal["requests"][0]["collector_confirmed"] = True
        self.assert_rejected("INVALID_PROPOSAL")
        del self.proposal["requests"][0]["collector_confirmed"]
        self.proposal["status"] = "pickup_confirmed"
        self.assert_rejected("INVALID_PROPOSAL")

    def test_malformed_trusted_records_and_unzoned_times_fail_explicitly(self):
        original = deepcopy(self.snapshot)
        for field, value in (
            ("now", "2026-11-09T17:55:00"), ("now", "17:55"),
            ("now", "0001-01-01T00:00:00+01:00"),
            ("now", "9999-12-31T23:59:59-01:00"), ("needs", None),
        ):
            with self.subTest(field=field, value=value):
                self.snapshot = deepcopy(original)
                self.snapshot[field] = value
                self.assert_rejected("INVALID_SNAPSHOT")
        self.snapshot = deepcopy(original)
        del self.snapshot["offer"]["state"]
        self.assert_rejected("INVALID_SNAPSHOT")
        self.snapshot = deepcopy(original)
        self.snapshot["needs"][0]["network_id"] = "another-network"
        self.assert_rejected("INVALID_SNAPSHOT")
        self.snapshot = deepcopy(original)
        self.snapshot["offer"]["present_allergens"] = ["unassessed-ingredient"]
        self.assert_rejected("INVALID_SNAPSHOT")

    def test_revisions_cannot_be_booleans_and_empty_plans_are_not_actionable(self):
        self.proposal["offer_revision"] = True
        self.assert_rejected("INVALID_PROPOSAL")
        self.proposal["offer_revision"] = 3
        self.proposal["requests"] = []
        self.assert_rejected("INVALID_PROPOSAL")


if __name__ == "__main__":
    unittest.main()
