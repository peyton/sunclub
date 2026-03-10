#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from dataset_config import BENCHMARK_TARGET, PRODUCT_QUERY_SPECS, SCENE_QUERY_SPECS

ROOT = SCRIPT_DIR.parent
RAW_DIR = ROOT / "data" / "raw" / "ingested"
MANIFESTS_DIR = ROOT / "manifests"
RAW_MANIFEST = MANIFESTS_DIR / "raw_candidates.jsonl"

USER_AGENT = "SunscreenTrackEval/1.0 (local benchmark pipeline; contact: local-run)"


def slugify(value: str) -> str:
    chars = []
    for ch in value.lower():
        if ch.isalnum():
            chars.append(ch)
        else:
            chars.append("_")
    slug = "".join(chars)
    while "__" in slug:
        slug = slug.replace("__", "_")
    return slug.strip("_")[:80] or "sample"


def request_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def download_and_ingest(source_url: str, destination: Path) -> tuple[int, int]:
    req = urllib.request.Request(source_url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=45) as response:
        raw = response.read()

    with Image.open(BytesIO(raw)) as image:
        image = image.convert("RGB")
        width, height = image.size
        if max(width, height) > 1800:
            image.thumbnail((1800, 1800))
        destination.parent.mkdir(parents=True, exist_ok=True)
        image.save(destination, format="JPEG", quality=95, optimize=True)
        return image.width, image.height


def openbeautyfacts_candidates(query_spec: dict, per_query: int) -> list[dict]:
    records: list[dict] = []
    for search_term in query_spec["search_terms"]:
        encoded = urllib.parse.quote(search_term)
        url = (
            "https://world.openbeautyfacts.org/cgi/search.pl"
            f"?action=process&search_terms={encoded}&json=1&page_size={per_query}"
        )
        payload = request_json(url)
        for product in payload.get("products", []):
            image_url = product.get("image_front_url") or product.get("image_url")
            code = product.get("code")
            if not image_url or not code:
                continue
            product_name = product.get("product_name") or search_term
            sample_id = slugify(
                f"obf_{query_spec['class_name']}_{code}_{hashlib.sha1(image_url.encode()).hexdigest()[:8]}"
            )
            records.append(
                {
                    "sample_id": sample_id,
                    "collection_role": "seed_corpus",
                    "source_type": "openbeautyfacts_search",
                    "source_url": image_url,
                    "page_url": f"https://world.openbeautyfacts.org/product/{code}",
                    "page_title": product_name,
                    "domain": "world.openbeautyfacts.org",
                    "query": search_term,
                    "downloaded_at": datetime.now(timezone.utc).isoformat(),
                    "license_if_known": "Unknown",
                    "notes": "Open Beauty Facts product search result",
                    "class_name": query_spec["class_name"],
                    "binary_label": query_spec["binary_label"],
                    "label_source": "weak_query_metadata",
                    "product_name": product_name,
                    "product_code": code,
                    "product_family": slugify(product_name),
                }
            )
        time.sleep(0.1)
    return records


def wikimedia_candidates(query_spec: dict, per_query: int) -> list[dict]:
    records: list[dict] = []
    for search_term in query_spec["search_terms"]:
        url = (
            "https://commons.wikimedia.org/w/api.php?action=query&generator=search"
            f"&gsrsearch={urllib.parse.quote(search_term)}"
            "&gsrnamespace=6"
            f"&gsrlimit={per_query}"
            "&prop=imageinfo|info&iiprop=url|extmetadata&inprop=url&format=json"
        )
        payload = request_json(url)
        pages = payload.get("query", {}).get("pages", {})
        for page in pages.values():
            imageinfo = (page.get("imageinfo") or [{}])[0]
            image_url = imageinfo.get("url")
            canonical_url = page.get("canonicalurl") or imageinfo.get("descriptionurl")
            title = page.get("title") or search_term
            if not image_url or not canonical_url:
                continue
            extmetadata = imageinfo.get("extmetadata") or {}
            license_name = (
                extmetadata.get("LicenseShortName", {}).get("value")
                or extmetadata.get("UsageTerms", {}).get("value")
                or "Unknown"
            )
            sample_id = slugify(
                f"commons_{query_spec['class_name']}_{hashlib.sha1(image_url.encode()).hexdigest()[:10]}"
            )
            records.append(
                {
                    "sample_id": sample_id,
                    "collection_role": "scene_corpus",
                    "source_type": "wikimedia_commons_search",
                    "source_url": image_url,
                    "page_url": canonical_url,
                    "page_title": title,
                    "domain": "commons.wikimedia.org",
                    "query": search_term,
                    "downloaded_at": datetime.now(timezone.utc).isoformat(),
                    "license_if_known": license_name,
                    "notes": "Wikimedia Commons search result",
                    "class_name": query_spec["class_name"],
                    "binary_label": query_spec["binary_label"],
                    "label_source": "weak_query_metadata",
                    "product_name": title,
                    "product_code": None,
                    "product_family": slugify(title),
                }
            )
        time.sleep(0.1)
    return records


def benchmark_target_uploads() -> list[dict]:
    records: list[dict] = []
    for code in BENCHMARK_TARGET["codes"]:
        url = (
            "https://world.openbeautyfacts.org/api/v2/product/"
            f"{code}.json?fields=code,product_name,images,image_front_url"
        )
        payload = request_json(url)
        product = payload.get("product") or {}
        product_name = product.get("product_name") or BENCHMARK_TARGET["display_name"]
        images = product.get("images") or {}
        numeric_ids = sorted(
            [key for key in images.keys() if key.isdigit()],
            key=lambda item: int(item),
        )
        prefix = "/".join([code[0:3], code[3:6], code[6:9], code[9:]])
        for image_id in numeric_ids[:6]:
            image_url = f"https://images.openbeautyfacts.org/images/products/{prefix}/{image_id}.400.jpg"
            sample_id = slugify(f"benchmark_target_{code}_{image_id}")
            records.append(
                {
                    "sample_id": sample_id,
                    "collection_role": "benchmark_target",
                    "source_type": "openbeautyfacts_upload",
                    "source_url": image_url,
                    "page_url": f"https://world.openbeautyfacts.org/product/{code}",
                    "page_title": product_name,
                    "domain": "world.openbeautyfacts.org",
                    "query": f"benchmark_target:{BENCHMARK_TARGET['family_slug']}",
                    "downloaded_at": datetime.now(timezone.utc).isoformat(),
                    "license_if_known": "Unknown",
                    "notes": "Benchmark target-family uploaded image revision",
                    "class_name": "benchmark_target_family",
                    "binary_label": "sunscreen",
                    "label_source": "high_confidence_verified",
                    "product_name": product_name,
                    "product_code": code,
                    "product_family": BENCHMARK_TARGET["family_slug"],
                    "upload_id": image_id,
                }
            )
        time.sleep(0.1)
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--product-per-query", type=int, default=3)
    parser.add_argument("--scene-per-query", type=int, default=2)
    args = parser.parse_args()

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    MANIFESTS_DIR.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []
    for query_spec in PRODUCT_QUERY_SPECS:
        records.extend(openbeautyfacts_candidates(query_spec, per_query=args.product_per_query))
    for query_spec in SCENE_QUERY_SPECS:
        records.extend(wikimedia_candidates(query_spec, per_query=args.scene_per_query))
    records.extend(benchmark_target_uploads())

    seen_source_urls = set()
    kept: list[dict] = []
    for record in records:
        if record["source_url"] in seen_source_urls:
            continue
        seen_source_urls.add(record["source_url"])
        target_path = RAW_DIR / f"{record['sample_id']}.jpg"
        try:
            width, height = download_and_ingest(record["source_url"], target_path)
        except Exception as exc:
            continue
        record["local_path"] = str(target_path)
        record["width"] = width
        record["height"] = height
        kept.append(record)

    with RAW_MANIFEST.open("w", encoding="utf-8") as handle:
        for record in kept:
            handle.write(json.dumps(record, sort_keys=True) + "\n")

    print(json.dumps({"raw_candidates": len(kept), "manifest": str(RAW_MANIFEST)}))


if __name__ == "__main__":
    main()
