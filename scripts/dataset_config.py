from __future__ import annotations

BENCHMARK_TARGET = {
    "family_slug": "avene_intense_protect_50_plus",
    "display_name": "Avene Intense Protect 50+",
    "codes": [
        "3282770141214",
        "0282450541214",
    ],
}

PRODUCT_QUERY_SPECS = [
    {
        "class_name": "sunscreen_tube",
        "binary_label": "sunscreen",
        "search_terms": [
            "sunscreen tube spf 50",
            "sunblock tube",
            "mineral sunscreen tube",
        ],
    },
    {
        "class_name": "sunscreen_bottle",
        "binary_label": "sunscreen",
        "search_terms": [
            "sunscreen bottle spf 50",
            "sun lotion bottle",
            "sunscreen milk bottle",
        ],
    },
    {
        "class_name": "sunscreen_spray",
        "binary_label": "sunscreen",
        "search_terms": [
            "sunscreen spray",
            "sun spray spf 50",
            "spray sunscreen",
        ],
    },
    {
        "class_name": "sunscreen_stick",
        "binary_label": "sunscreen",
        "search_terms": [
            "sunscreen stick",
            "sunblock stick",
            "spf stick sunscreen",
        ],
    },
    {
        "class_name": "sunscreen_pump",
        "binary_label": "sunscreen",
        "search_terms": [
            "sunscreen pump bottle",
            "sun lotion pump",
            "pump sunscreen",
        ],
    },
    {
        "class_name": "sunscreen_packet",
        "binary_label": "sunscreen",
        "search_terms": [
            "sunscreen sachet",
            "sunscreen packet",
            "spf sample packet",
        ],
    },
    {
        "class_name": "moisturizer",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "moisturizer bottle",
            "daily moisturizing cream",
            "face moisturizer tube",
        ],
    },
    {
        "class_name": "lotion",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "body lotion bottle",
            "repair lotion",
            "skin lotion tube",
        ],
    },
    {
        "class_name": "cleanser",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "face cleanser tube",
            "cleansing gel bottle",
            "foam cleanser",
        ],
    },
    {
        "class_name": "deodorant",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "deodorant stick",
            "body spray deodorant",
            "roll on deodorant",
        ],
    },
    {
        "class_name": "shampoo_conditioner",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "shampoo bottle",
            "conditioner bottle",
            "hair care bottle",
        ],
    },
    {
        "class_name": "makeup_foundation",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "liquid foundation bottle",
            "makeup foundation tube",
            "bb cream bottle",
        ],
    },
    {
        "class_name": "insect_repellent",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "insect repellent spray",
            "bug spray bottle",
            "mosquito repellent lotion",
        ],
    },
    {
        "class_name": "hand_sanitizer",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "hand sanitizer bottle",
            "sanitizer gel pump",
            "alcohol gel bottle",
        ],
    },
    {
        "class_name": "lip_balm",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "lip balm tube",
            "chapstick tube",
            "lip care stick",
        ],
    },
    {
        "class_name": "medicine_bottle",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "medicine bottle",
            "pill bottle",
            "pharmacy bottle",
        ],
    },
]

SCENE_QUERY_SPECS = [
    {
        "class_name": "sunscreen_scene",
        "binary_label": "sunscreen",
        "search_terms": [
            "sunscreen beach bag",
            "sunscreen on beach towel",
            "sunscreen bottle outdoors",
        ],
    },
    {
        "class_name": "generic_toiletry_clutter",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "bathroom counter toiletries",
            "toiletry bag open",
            "hotel vanity toiletries",
        ],
    },
    {
        "class_name": "empty_frame_no_sunscreen",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "bathroom counter",
            "beach towel and bag",
            "car console interior",
        ],
    },
    {
        "class_name": "bright_sunlight_scene",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "sunny beach towel",
            "bright beach bag",
            "sunlit outdoor towel",
        ],
    },
    {
        "class_name": "low_light_scene",
        "binary_label": "not_sunscreen",
        "search_terms": [
            "dim bathroom sink",
            "night hotel vanity",
            "dark toiletry bag",
        ],
    },
]

BENCHMARK_SLICE_NAMES = [
    "clean_products",
    "in_the_wild",
    "hard_negatives",
    "cluttered_scenes",
    "partial_occlusion",
    "low_light",
    "bright_sunlight",
    "motion_blur",
    "tiny_objects",
    "multi_object_scenes",
    "upside_down_or_rotated",
    "non_english_packaging",
    "empty_frame_no_sunscreen",
    "near_ood_personal_care_items",
]

