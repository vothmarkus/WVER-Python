import urllib.request
import urllib.error
import json

from wver_stationen import WVER_STATIONS


def test_url(url: str, is_json: bool = False):
    headers = {"User-Agent": "Mozilla/5.0"}
    if is_json:
        headers["Range"] = "bytes=-256"

    req = urllib.request.Request(url, headers=headers)

    with urllib.request.urlopen(req, timeout=30) as response:
        status = response.status
        content_type = response.headers.get("Content-Type", "")
        content_length = response.headers.get("Content-Length")
        accept_ranges = response.headers.get("Accept-Ranges")
        content_range = response.headers.get("Content-Range")

        body = response.read()
        snippet = body[:120].decode("utf-8", errors="replace")

        return {
            "status": status,
            "content_type": content_type,
            "content_length": content_length,
            "accept_ranges": accept_ranges,
            "content_range": content_range,
            "snippet": snippet,
        }


def main():
    ok_count = 0
    fail_count = 0

    for station_key, station in WVER_STATIONS.items():
        print(f"\n=== {station_key} | {station['name']} ===")

        # page_url testen
        try:
            result = test_url(station["page_url"], is_json=False)
            print(
                f"[OK]   page_url"
                f" | status={result['status']}"
                f" | type={result['content_type']}"
            )
            ok_count += 1
        except urllib.error.HTTPError as e:
            print(f"[FAIL] page_url | HTTP {e.code} | {station['page_url']}")
            fail_count += 1
        except Exception as e:
            print(f"[FAIL] page_url | {e} | {station['page_url']}")
            fail_count += 1

        # signals testen
        for signal_key, signal_url in station["signals"].items():
            try:
                result = test_url(signal_url, is_json=True)
                plausible = (
                    result["status"] in (200, 206)
                    and "json" in result["content_type"].lower()
                )

                marker = "OK" if plausible else "WARN"
                print(
                    f"[{marker}] {signal_key}"
                    f" | status={result['status']}"
                    f" | type={result['content_type']}"
                    f" | ranges={result['accept_ranges']}"
                    f" | c-range={result['content_range']}"
                )

                if plausible:
                    ok_count += 1
                else:
                    fail_count += 1

            except urllib.error.HTTPError as e:
                print(f"[FAIL] {signal_key} | HTTP {e.code} | {signal_url}")
                fail_count += 1
            except Exception as e:
                print(f"[FAIL] {signal_key} | {e} | {signal_url}")
                fail_count += 1

    print("\n=== Zusammenfassung ===")
    print(f"OK:   {ok_count}")
    print(f"FAIL: {fail_count}")


if __name__ == "__main__":
    main()