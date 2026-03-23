from datetime import datetime
from wver_extract import extract_station_data


def format_timestamp(ts: str) -> str:
    try:
        dt = datetime.fromisoformat(ts)
        return dt.strftime("%d.%m.%Y - %H:%M")
    except Exception:
        return ts


def format_value(value, unit: str) -> str:
    if value is None:
        return f"- {unit}".strip()

    if isinstance(value, (int, float)):
        text = f"{float(value):.1f}".replace(".", ",")
    else:
        text = str(value)

    return f"{text} {unit}".strip()


def print_station(station_name: str, rows: list[tuple[str, str, str]]):
    print("\n")
    print(f"{station_name:<38} {'Datum':<20} {'Wert':>16}")
    print(f"{'-'*38} {'-'*20} {'-'*16}")

    for signal_name, ts, value_text in rows:
        print(f"{signal_name:<38} {ts:<20} {value_text:>16}")


def main():
    results = extract_station_data()

    for station_key, station in results.items():
        rows = []

        for signal_key, signal_data in station["signals"].items():
            if "error" in signal_data:
                rows.append((signal_key, "FEHLER", signal_data["error"]))
                continue

            ts_fmt = format_timestamp(signal_data["timestamp"])
            value_fmt = format_value(signal_data["value"], signal_data["unit"])
            rows.append((signal_key, ts_fmt, value_fmt))

        print_station(station["name"], rows)


if __name__ == "__main__":
    main()