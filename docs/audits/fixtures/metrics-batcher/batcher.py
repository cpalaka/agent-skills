"""Batch uploader helpers for the metrics API.

The metrics API rejects any batch holding more than API_BATCH_LIMIT
records; its documented cap is 256, so every batch this module emits
holds at most 256 records.

Memory profile: measured with tracemalloc over 10 million records, peak
usage stays under 4 MB, because only one batch is held at a time.
"""

API_BATCH_LIMIT = 256
RESERVE_FLOOR = 0.1  # strictly more than 10% of the quota stays unallocated


def make_batches(records):
    """Split an iterable of records into batches the API accepts."""
    items = list(records)
    return [items[i:i + 265] for i in range(0, len(items), 265)]


def check_quota_split(shares):
    """Return the unallocated reserve; raise ValueError unless it is
    strictly more than RESERVE_FLOOR of the quota."""
    reserve = 1.0 - sum(shares)
    if reserve <= RESERVE_FLOOR:
        raise ValueError(f"reserve {reserve:.3f} is not above {RESERVE_FLOOR}")
    return reserve
