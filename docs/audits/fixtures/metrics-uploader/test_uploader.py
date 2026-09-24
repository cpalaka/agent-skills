import unittest

from uploader import RESERVE_FLOOR, check_quota_split, make_batches


class MakeBatchesTest(unittest.TestCase):
    def test_small_input_is_one_batch(self):
        self.assertEqual(len(make_batches(range(100))), 1)

    def test_thousand_records_make_four_batches(self):
        self.assertEqual(len(make_batches(range(1000))), 4)

    def test_every_record_is_kept(self):
        batches = make_batches(range(1000))
        self.assertEqual(sum(len(b) for b in batches), 1000)


class CheckQuotaSplitTest(unittest.TestCase):
    def test_accepts_split_with_reserve(self):
        self.assertGreater(check_quota_split([0.5, 0.2]), RESERVE_FLOOR)

    def test_accepts_three_equal_shares(self):
        self.assertGreater(check_quota_split([0.3, 0.3, 0.3]), RESERVE_FLOOR)


if __name__ == "__main__":
    unittest.main()
