#!/usr/bin/env python3
"""
build_dataset_manifest.py
Builds a curated manifest of 50 House, 50 Techno, and 50 Drum & Bass tracks
from the GiantSteps EDM dataset annotations.
"""

import json
import os
import random

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
METADATA_DIR = os.path.join(BASE_DIR, "dataset", "metadata")
os.makedirs(METADATA_DIR, exist_ok=True)

# Sources of GiantSteps trees fetched during analysis
KEY_TREE_PATH = "/Users/macairm1/.gemini/antigravity/brain/fa14326e-1c60-480f-a3be-913fac3a8bd5/.system_generated/steps/100/content.md"
TEMPO_TREE_PATH = "/Users/macairm1/.gemini/antigravity/brain/fa14326e-1c60-480f-a3be-913fac3a8bd5/.system_generated/steps/94/content.md"

# SHA to genre mapping verified from GitHub repository blobs
SHA_TO_GENRE = {
    # Drum & Bass
    "1b37f7d533cb963d717d1f87acaf3e7f8f921259": "dnb",
    # Techno
    "885a60d5edf6f7fab829646739da37cfbcfee0f8": "techno",
    # House subgenres
    "33eef55d828d613a4f9b8876d3983327e7145dd1": "house_pure",
    "acf523b8f72edd5fc60352d929679c6ccd63d8d7": "deep_house",
    "e322150096a4e9ecdaf7c7b993f2f53dd8b88063": "tech_house",
    "2efcc1bfd535cf8bb0a69e7a76aec8e7032ac488": "progressive_house",
    "ebcd1a20326f6658177bc6717153f4eb1f2b39f7": "electro_house",
}

def load_tree(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    json_start = text.find("{")
    return json.loads(text[json_start:])

def collect_tracks():
    key_data = load_tree(KEY_TREE_PATH)
    tempo_data = load_tree(TEMPO_TREE_PATH)

    tracks_by_category = {
        "dnb": set(),
        "techno": set(),
        "house": set(),
    }

    track_details = {}

    for dataset_name, data in [("key", key_data), ("tempo", tempo_data)]:
        for item in data.get("tree", []):
            path = item.get("path", "")
            if path.startswith("annotations/genre/") and path.endswith(".genre"):
                track_id = path.split("/")[-1].replace(".LOFI.genre", "")
                sha = item.get("sha")
                genre_tag = SHA_TO_GENRE.get(sha)

                if genre_tag == "dnb":
                    tracks_by_category["dnb"].add(track_id)
                    track_details[track_id] = {"subgenre": "drum-and-bass", "source_dataset": dataset_name}
                elif genre_tag == "techno":
                    tracks_by_category["techno"].add(track_id)
                    track_details[track_id] = {"subgenre": "techno", "source_dataset": dataset_name}
                elif genre_tag in ("house_pure", "deep_house", "tech_house", "progressive_house", "electro_house"):
                    tracks_by_category["house"].add(track_id)
                    track_details[track_id] = {"subgenre": genre_tag, "source_dataset": dataset_name}

    return tracks_by_category, track_details

def build_manifest():
    random.seed(42)  # Deterministic selection for reproducibility
    tracks_by_category, track_details = collect_tracks()

    manifest = {
        "description": "50 representative tracks per genre for speech enhancement filter design",
        "genres": {}
    }

    target_count = 50

    for genre in ["house", "techno", "dnb"]:
        available = sorted(list(tracks_by_category[genre]))
        if len(available) < target_count:
            raise ValueError(f"Not enough tracks for genre {genre}: {len(available)} available, {target_count} required")

        # Select 50 tracks reproducibly
        selected_ids = random.sample(available, target_count)
        selected_ids.sort()

        manifest["genres"][genre] = []
        for tid in selected_ids:
            manifest["genres"][genre].append({
                "track_id": tid,
                "subgenre": track_details[tid]["subgenre"],
                "source_dataset": track_details[tid]["source_dataset"],
                "filename_mp3": f"{tid}.LOFI.mp3",
                "filename_wav": f"{genre}_{tid}.wav",
                "urls": [
                    f"https://www.cp.jku.at/datasets/giantsteps/backup/{tid}.LOFI.mp3",
                    f"http://geo-samples.beatport.com/lofi/{tid}.LOFI.mp3"
                ]
            })

    output_file = os.path.join(METADATA_DIR, "selected_tracks.json")
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    print(f"Manifest successfully generated at: {output_file}")
    for g, items in manifest["genres"].items():
        print(f"  {g.upper()}: {len(items)} tracks selected")

if __name__ == "__main__":
    build_manifest()
