#!/bin/sh

OUT="/www/wver/data.json"
TMP="/tmp/wver.$$"

mkdir -p /www/wver

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

normalize_unit() {
  unit="$1"
  case "$unit" in
    *m*/*s*|*m³/s*|*m3/s*|*m�/s*)
      printf 'm³/s'
      ;;
    *)
      printf '%s' "$unit"
      ;;
  esac
}

infer_unit() {
  signal_key="$1"
  current_unit="$2"

  case "$signal_key" in
    *abfluss*|*abgabe*|*zufluss*)
      printf 'm³/s'
      return
      ;;
  esac

  if [ -n "$current_unit" ]; then
    case "$current_unit" in
      *m*/*s*|*m³/s*|*m3/s*|*m�/s*)
        printf 'm³/s'
        ;;
      *)
        printf '%s' "$current_unit"
        ;;
    esac
    return
  fi

  case "$signal_key" in
    *wasserstand*)
      printf 'cm'
      ;;
    *)
      printf ''
      ;;
  esac
}

convert_fetch_url() {
  printf '%s' "$1" | sed 's#^https://#http://#'
}

parse_pegel_tail() {
  fetch_url="$1"

  PARSED_TS=""
  PARSED_VALUE=""
  PARSED_ABS="null"
  PARSED_UNIT=""
  PARSED_PARSER="range_tail"
  PARSED_ERROR=""

  wget -q -O "$TMP" "$fetch_url" || {
    PARSED_ERROR="Download fehlgeschlagen"
    return 1
  }

  LINE=$(grep '\["' "$TMP" | tail -n 1)

  if [ -z "$LINE" ]; then
    PARSED_ERROR="Kein [timestamp, value]-Paar gefunden"
    return 1
  fi

  PARSED_TS=$(echo "$LINE" | sed -n 's/.*"\([^"]*\)".*/\1/p')
  PARSED_VALUE=$(echo "$LINE" | sed -n 's/.*,[[:space:]]*\([0-9.+-][0-9.+-]*\).*/\1/p')

  if [ -z "$PARSED_TS" ] || [ -z "$PARSED_VALUE" ]; then
    PARSED_ERROR="Timestamp oder Wert konnte nicht extrahiert werden"
    return 1
  fi

  return 0
}

parse_talsperre_json() {
  fetch_url="$1"

  PARSED_TS=""
  PARSED_VALUE=""
  PARSED_ABS="null"
  PARSED_UNIT=""
  PARSED_PARSER="full_json_last_valid"
  PARSED_ERROR=""

  wget -q -O "$TMP" "$fetch_url" || {
    PARSED_ERROR="Download fehlgeschlagen"
    return 1
  }

  PARSED_UNIT=$(sed -n 's/.*"ts_unitsymbol"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TMP" | head -n 1)
  PARSED_UNIT=$(normalize_unit "$PARSED_UNIT")

  LAST_ROW=$(
    awk '
      BEGIN {
        last_ts = ""
        last_val = ""
        last_abs = ""
      }
      {
        line = $0
        while (match(line, /\["[^"]+"[[:space:]]*,[[:space:]]*[^][]+\]/)) {
          row = substr(line, RSTART, RLENGTH)

          tmp = row
          gsub(/^\[/, "", tmp)
          gsub(/\]$/, "", tmp)

          n = split(tmp, a, ",")

          ts = a[1]
          gsub(/^"/, "", ts)
          gsub(/"$/, "", ts)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", ts)

          val = (n >= 2 ? a[2] : "")
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)

          abs = (n >= 3 ? a[3] : "")
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", abs)

          if (val != "" && val != "-" && val != "null") {
            last_ts = ts
            last_val = val
            last_abs = abs
          }

          line = substr(line, RSTART + RLENGTH)
        }
      }
      END {
        print last_ts ";" last_val ";" last_abs
      }
    ' "$TMP"
  )

  PARSED_TS=$(echo "$LAST_ROW" | cut -d';' -f1)
  PARSED_VALUE=$(echo "$LAST_ROW" | cut -d';' -f2)
  PARSED_ABS=$(echo "$LAST_ROW" | cut -d';' -f3)

  if [ -z "$PARSED_TS" ] || [ -z "$PARSED_VALUE" ]; then
    PARSED_ERROR="Kein gültiger Wert in data gefunden"
    return 1
  fi

  case "$PARSED_ABS" in
    ""|"-"|null)
      PARSED_ABS="null"
      ;;
  esac

  return 0
}

extract_signal() {
  signal_key="$1"
  source_url="$2"
  fetch_url=$(convert_fetch_url "$source_url")

  case "$signal_key" in
    abgabe|abgabe_hauptsee|zufluss|zufluss_obersee|wasserstand_hauptsee|wasserstand_hauptsee_seit_wwj2001|wasserstand_obersee|wasserstand_seit_wwj2001)
      parse_talsperre_json "$fetch_url"
      return $?
      ;;
  esac

  case "$source_url" in
    *Tag.Mittel.json*|*Tag.Summe.json*|*seitWWJ2001*)
      parse_talsperre_json "$fetch_url"
      return $?
      ;;
  esac

  parse_pegel_tail "$fetch_url"
  return $?
}

write_signal_json() {
  station_name="$1"
  signal_key="$2"
  source_url="$3"

  if extract_signal "$signal_key" "$source_url"; then
    unit=$(infer_unit "$signal_key" "$PARSED_UNIT")

    printf '      "%s": {\n' "$(json_escape "$signal_key")"
    printf '        "timestamp": "%s",\n' "$(json_escape "$PARSED_TS")"
    printf '        "value": %s,\n' "$PARSED_VALUE"
    printf '        "absolute_value": %s,\n' "$PARSED_ABS"

    if [ -n "$unit" ]; then
      printf '        "unit": "%s",\n' "$(json_escape "$unit")"
    else
      printf '        "unit": "",\n'
    fi

    printf '        "url": "%s",\n' "$(json_escape "$source_url")"
    printf '        "name": "%s",\n' "$(json_escape "$station_name")"
    printf '        "parser": "%s"\n' "$(json_escape "$PARSED_PARSER")"
    printf '      }'
  else
    printf '      "%s": {\n' "$(json_escape "$signal_key")"
    printf '        "error": "%s",\n' "$(json_escape "$PARSED_ERROR")"
    printf '        "url": "%s",\n' "$(json_escape "$source_url")"
    printf '        "name": "%s"\n' "$(json_escape "$station_name")"
    printf '      }'
  fi
}

{
  printf '{\n'

  current_station=""
  current_name=""
  first_station=1
  first_signal=1

  while IFS='|' read -r station_key station_name signal_key source_url; do
    [ -z "$station_key" ] && continue

    if [ "$station_key" != "$current_station" ]; then
      if [ -n "$current_station" ]; then
        printf '\n    }\n  }'
      fi

      if [ "$first_station" -eq 0 ]; then
        printf ',\n'
      fi

      printf '  "%s": {\n' "$(json_escape "$station_key")"
      printf '    "name": "%s",\n' "$(json_escape "$station_name")"
      printf '    "signals": {\n'

      current_station="$station_key"
      current_name="$station_name"
      first_station=0
      first_signal=1
    fi

    if [ "$first_signal" -eq 0 ]; then
      printf ',\n'
    fi

    write_signal_json "$station_name" "$signal_key" "$source_url"
    first_signal=0

  done <<'STATIONS'
stb_heimbach_uw|Stb. Heimbach UW|wasserstand|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Stb.%20Heimbach%20UWWasserstandBasis.P.json
stb_heimbach_uw|Stb. Heimbach UW|abfluss|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Stb.%20Heimbach%20UWAbflussBasis.P.json
stb_obermaubach_uw|Stb. Obermaubach UW|abfluss|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Stb.%20Obermaubach%20UWAbflussBasis.P.json
rur_monschau_lanuk|Rur Monschau LANUK|wasserstand|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Rur%20Monschau%20LANUKWasserstandImport_Internet.P.json
rur_dedenborn|Rur Dedenborn|wasserstand|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Rur%20DedenbornWasserstandBasis.P.json
rur_dedenborn|Rur Dedenborn|abfluss|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Rur%20DedenbornAbflussBasis.P.json
rurtalsperre_schwammenauel|Rurtalsperre Schwammenauel|abgabe_hauptsee|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Rurtalsperre%20Hauptsee%20AbflussAbflussTag.Mittel.json
rurtalsperre_schwammenauel|Rurtalsperre Schwammenauel|wasserstand_hauptsee|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Rurtalsperre%20Hauptsee%20OWWasserspiegelTag.Mittel.json
rurtalsperre_schwammenauel|Rurtalsperre Schwammenauel|wasserstand_obersee|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Rurtalsperre%20Obersee%20OWWasserspiegelTag.Mittel.json
urfttalsperre|Urfttalsperre|abgabe|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Urfttalsperre%20AbflussAbflussQ_gesamt_Tag.Mittel.json
urfttalsperre|Urfttalsperre|wasserstand|https://wver.de/karten_messwerte/Messdatenportal/Messdaten/Urfttalsperre%20OWWasserspiegelTag.Mittel.json
STATIONS

  if [ -n "$current_station" ]; then
    printf '\n    }\n  }\n'
  fi

  printf '}\n'
} > "$OUT"

rm -f "$TMP"

echo "Gespeichert als: $OUT"
