import json
import re
import urllib.request

from wver_stationen import WVER_STATIONS

INTERESTING_SIGNALS = {
    "wasserstand",
    "abfluss",
    "abgabe",
    "zufluss",
    "wasserstand_seit_wwj2001",
    "wasserstand_hauptsee_seit_wwj2001",
    "wasserstand_hauptsee",
    "abgabe_hauptsee",
    "zufluss_obersee",
    "wasserstand_obersee",
}

RANGE_BYTES = 8192
PAIR_PATTERN = re.compile(r'\["([^"]+)",\s*([0-9.+-]+)\]')


def fetch_text_range(url: str, range_bytes: int = RANGE_BYTES) -> str:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0",
            "Range": f"bytes=-{range_bytes}",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return response.read().decode("utf-8", errors="replace")


def fetch_json_full(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.loads(response.read().decode("utf-8", errors="replace"))


def normalize_unit(unit):
    if unit is None:
        return None
    return (
        str(unit)
        .replace("m�/s", "m³/s")
        .replace("m?/s", "m³/s")
    )


def infer_unit(signal_key: str, current_unit):
    if current_unit:
        return current_unit
    if "wasserstand" in signal_key:
        return "cm"
    if any(key in signal_key for key in ("abfluss", "abgabe", "zufluss")):
        return "m³/s"
    return ""


def to_float_or_none(value):
    if value in (None, "", "-"):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def parse_pegel_tail(url: str) -> dict:
    text = fetch_text_range(url)
    matches = PAIR_PATTERN.findall(text)
    if not matches:
        raise ValueError("Kein [timestamp, value]-Paar im Tail gefunden")

    ts, value = matches[-1]
    return {
        "timestamp": ts,
        "value": float(value),
        "absolute_value": None,
        "unit": None,
        "parser": "range_tail",
    }


def parse_talsperre_json(url: str) -> dict:
    obj = fetch_json_full(url)

    columns_raw = obj.get("columns")
    data = obj.get("data", [])
    unit = normalize_unit(obj.get("ts_unitsymbol"))

    if not columns_raw or not data:
        raise ValueError("JSON enthält keine brauchbaren columns/data")

    if isinstance(columns_raw, str):
        columns = [c.strip() for c in columns_raw.split(",")]
    else:
        columns = list(columns_raw)

    ts_idx = columns.index("Timestamp")
    val_idx = columns.index("Value")
    abs_idx = columns.index("Absolute Value") if "Absolute Value" in columns else None

    for row in reversed(data):
        ts = row[ts_idx]
        value = to_float_or_none(row[val_idx])
        abs_value = to_float_or_none(row[abs_idx]) if abs_idx is not None else None

        if value is not None:
            return {
                "timestamp": ts,
                "value": value,
                "absolute_value": abs_value,
                "unit": unit,
                "parser": "full_json_last_valid",
            }

    raise ValueError("Kein gültiger numerischer Wert in data gefunden")


def extract_signal(signal_key: str, url: str) -> dict:
    if any(
        key in signal_key
        for key in (
            "wasserstand_seit_wwj2001",
            "wasserstand_hauptsee_seit_wwj2001",
            "wasserstand_hauptsee",
            "abgabe_hauptsee",
            "zufluss_obersee",
            "wasserstand_obersee",
            "abgabe",
            "zufluss",
        )
    ) or "Tag.Mittel.json" in url or "Tag.Summe.json" in url or "seitWWJ2001" in url:
        return parse_talsperre_json(url)

    return parse_pegel_tail(url)


def extract_station_data() -> dict:
    results = {}

    for station_key, station in WVER_STATIONS.items():
        station_results = {}

        for signal_key, url in station["signals"].items():
            if signal_key not in INTERESTING_SIGNALS:
                continue

            try:
                result = extract_signal(signal_key, url)
                unit = infer_unit(signal_key, result["unit"])

                station_results[signal_key] = {
                    "timestamp": result["timestamp"],
                    "value": result["value"],
                    "absolute_value": result["absolute_value"],
                    "unit": unit,
                    "url": url,
                    "name": station["name"],
                    "parser": result["parser"],
                }
            except Exception as e:
                station_results[signal_key] = {
                    "error": str(e),
                    "url": url,
                    "name": station["name"],
                }

        results[station_key] = {
            "name": station["name"],
            "signals": station_results,
        }

    return results


def save_results(filepath: str = "wver_interesting_latest.json") -> dict:
    results = extract_station_data()
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    return results


def main():
    results = save_results()
    print("Gespeichert als: wver_interesting_latest.json")
    return results


if __name__ == "__main__":
    main()