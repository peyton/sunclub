import unittest

from eval.metrics import calibration_bins, confusion_counts, threshold_sweep


class BenchmarkMetricsTests(unittest.TestCase):
    def test_confusion_counts(self) -> None:
        metrics = confusion_counts([1, 1, 0, 0], [1, 0, 1, 0])
        self.assertEqual(metrics.true_positives, 1)
        self.assertEqual(metrics.true_negatives, 1)
        self.assertEqual(metrics.false_positives, 1)
        self.assertEqual(metrics.false_negatives, 1)
        self.assertAlmostEqual(metrics.accuracy, 0.5)

    def test_calibration_bins_count_examples(self) -> None:
        rows = calibration_bins([1, 0, 1, 0], [0.1, 0.2, 0.8, 0.9], bins=2)
        self.assertEqual(sum(row["count"] for row in rows), 4)

    def test_threshold_sweep_descends(self) -> None:
        rows = threshold_sweep([1, 0, 1], [0.9, 0.1, 0.8])
        self.assertGreaterEqual(rows[0]["threshold"], rows[-1]["threshold"])


if __name__ == "__main__":
    unittest.main()
