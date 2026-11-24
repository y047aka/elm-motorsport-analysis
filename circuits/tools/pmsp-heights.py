"""São Paulo's heights, read off the city's 2017 LiDAR point cloud.

    nix run .#geometry -- elevation sao_paulo --places places.json
    nix run .#geometry-pmsp-heights -- places.json circuits/sao_paulo/elevation.json

The cloud is published as LAZ tiles on AWS (`laz-m3dc-pmsp`, SIRGAS 2000 / UTM 23S) and as
no service a place can be asked of. A place's height is the median of the ground returns
(class 2) within 1 m of it, or within 1.5 m where none stands that near: under a bridge the
ground holds no return. `resolution_m` records which radius it was read within.

The tiles are read into a temporary directory and thrown away; only the heights are kept.
The kept file is written as `Elevation.written` writes it, each place spelled as the places
file spelled it, since the survey finds a height by the degrees it was asked at.
"""

import concurrent.futures
import json
import re
import struct
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import laspy
import numpy as np
import pyproj
from scipy.spatial import cKDTree

BUCKET = "https://laz-m3dc-pmsp.s3.sa-east-1.amazonaws.com"
RADII = (1.0, 1.5)
GROUND = 2


def fetched(url, headers=None, tries=4):
    """A 4xx is an answer and is raised at once; a 5xx or a dropped connection is asked again, 2, 4 and 8 s later."""
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers or {}), timeout=120) as answer:
                return answer.read()
        except urllib.error.HTTPError as refusal:
            if refusal.code < 500 or attempt == tries - 1:
                raise
        except OSError:
            if attempt == tries - 1:
                raise
        time.sleep(2 ** (attempt + 1))


def tile_names():
    names, token = [], None
    while True:
        url = f"{BUCKET}/?list-type=2" + (f"&continuation-token={urllib.parse.quote(token)}" if token else "")
        text = fetched(url).decode()
        names += re.findall(r"<Key>([^<]*\.laz)</Key>", text)
        more = re.search(r"<NextContinuationToken>([^<]*)<", text)
        if not more:
            return names
        token = more.group(1)


def bounds(name):
    """A LAS header's extent, read off its first 227 bytes: max x, min x, max y, min y."""
    head = fetched(f"{BUCKET}/{name}", {"Range": "bytes=0-226"})
    max_x, min_x, max_y, min_y = struct.unpack("<4d", head[179:211])
    return name, (min_x, max_x, min_y, max_y)


def main(places_path, kept_path):
    text = Path(places_path).read_text()
    listed = json.loads(text)
    spelled = re.findall(r"^\[([^,\]]+),([^\]]+)\]", text.split('"places": [', 1)[1], re.MULTILINE)
    if len(spelled) != len(listed["places"]):
        sys.exit(f"{places_path}: {len(spelled)} places spelled against {len(listed['places'])} read")

    to_utm = pyproj.Transformer.from_crs(4326, 31983, always_xy=True)
    xy = np.array([to_utm.transform(lon, lat) for lon, lat in listed["places"]])
    reach = max(RADII)

    with concurrent.futures.ThreadPoolExecutor(32) as pool:
        extents = dict(pool.map(bounds, tile_names()))
    wanted = sorted(
        name for name, (x0, x1, y0, y1) in extents.items()
        if np.any((xy[:, 0] >= x0 - reach) & (xy[:, 0] <= x1 + reach) & (xy[:, 1] >= y0 - reach) & (xy[:, 1] <= y1 + reach))
    )
    print(f"{len(listed['places'])} places stand on {len(wanted)} tiles", file=sys.stderr)

    xs, ys, zs = [], [], []
    with tempfile.TemporaryDirectory() as scratch:
        for name in wanted:
            path = Path(scratch) / name
            path.write_bytes(fetched(f"{BUCKET}/{name}"))
            cloud = laspy.read(path)
            ground = np.asarray(cloud.classification) == GROUND
            xs.append(np.asarray(cloud.x)[ground])
            ys.append(np.asarray(cloud.y)[ground])
            zs.append(np.asarray(cloud.z)[ground])
            path.unlink()
    heights = np.concatenate(zs)
    tree = cKDTree(np.c_[np.concatenate(xs), np.concatenate(ys)])

    samples = []
    for (lon, lat), at in zip(spelled, xy):
        for radius in RADII:
            near = tree.query_ball_point(at, radius)
            if near:
                samples.append(f'{{"lon":{lon},"lat":{lat},"metres":{round(float(np.median(heights[near])), 3)},"resolution_m":{radius}}}')
                break
        else:
            sys.exit(f"no ground return within {reach} m of [{lon},{lat}]")

    head = ", ".join(f'"{key}": {json.dumps(listed[key], ensure_ascii=False)}' for key in ("source", "license", "datum", "service"))
    Path(kept_path).write_text("{" + head + ', "samples": [\n' + ",\n".join(samples) + "\n]}\n")
    print(f"kept {len(samples)} heights at {kept_path}", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: nix run .#geometry-pmsp-heights -- <places.json> <elevation.json>")
    main(sys.argv[1], sys.argv[2])
