#!/usr/bin/env python3
"""Fetch current conditions and today's high/low from Open-Meteo."""
import json
import sys
import os
import time
import urllib.parse
import urllib.request

GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search"
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
CACHE_HOME = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
CACHE_PATH = os.path.join(CACHE_HOME, "quickshell", "weather-cache.json")
CACHE_TTL_SECONDS = 2 * 60 * 60

CODES = {
    0: ("Clear sky", "☀️"),
    1: ("Mainly clear", "🌤️"),
    2: ("Partly cloudy", "⛅"),
    3: ("Overcast", "☁️"),
    45: ("Fog", "🌫️"),
    48: ("Rime fog", "🌫️"),
    51: ("Light drizzle", "🌦️"),
    53: ("Drizzle", "🌦️"),
    55: ("Dense drizzle", "🌧️"),
    56: ("Freezing drizzle", "🌧️"),
    57: ("Freezing drizzle", "🌧️"),
    61: ("Light rain", "🌦️"),
    63: ("Rain", "🌧️"),
    65: ("Heavy rain", "🌧️"),
    66: ("Freezing rain", "🌧️"),
    67: ("Heavy freezing rain", "🌧️"),
    71: ("Light snow", "🌨️"),
    73: ("Snow", "❄️"),
    75: ("Heavy snow", "❄️"),
    77: ("Snow grains", "🌨️"),
    80: ("Rain showers", "🌦️"),
    81: ("Rain showers", "🌧️"),
    82: ("Heavy rain showers", "🌧️"),
    85: ("Snow showers", "🌨️"),
    86: ("Heavy snow showers", "❄️"),
    95: ("Thunderstorm", "⛈️"),
    96: ("Thunderstorm with hail", "⛈️"),
    99: ("Thunderstorm with hail", "⛈️"),
}

def get_json(base_url, params):
    url = base_url + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(
        url, headers={"User-Agent": "Veyra-Calendar-Weather/1.0"}
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)

def main():
    force = "--force" in sys.argv[1:]
    args = [arg for arg in sys.argv[1:] if arg != "--force"]
    if not args or not args[0].strip():
        raise ValueError("Provide a city or location in the command line.")

    query = args[0].strip()
    cached = None

    try:
        with open(CACHE_PATH, encoding="utf-8") as cache_file:
            cached = json.load(cache_file)

        age = time.time() - float(cached.get("fetchedAt", 0))
        same_location = (
            str(cached.get("query", "")).casefold() == query.casefold()
        )
        if not force and same_location and 0 <= age < CACHE_TTL_SECONDS:
            print(json.dumps(cached["result"], ensure_ascii=False))
            return
    except (OSError, ValueError, TypeError, KeyError):
        cached = None
    geo = get_json(GEOCODING_URL, {
        "name": query, "count": 1, "language": "en", "format": "json"
    })
    results = geo.get("results") or []
    if not results:
        raise ValueError("Location not found: " + query)

    place = results[0]
    forecast = get_json(FORECAST_URL, {
        "latitude": place["latitude"],
        "longitude": place["longitude"],
        "current": (
            "temperature_2m,apparent_temperature,relative_humidity_2m,"
            "weather_code,wind_speed_10m,is_day"
        ),
        "daily": "weather_code,temperature_2m_max,temperature_2m_min",
        "forecast_days": 1,
        "timezone": "auto",
        "temperature_unit": "celsius",
        "wind_speed_unit": "kmh",
    })

    current = forecast["current"]
    daily = forecast["daily"]
    code = int(current["weather_code"])
    is_day = int(current.get("is_day", 1)) == 1
    description, emoji = CODES.get(code, ("Weather conditions", "🌡️"))
    if not is_day:
        # Clear or mostly clear nighttime skies should not show a sun.
        emoji = {0: "🌙", 1: "🌙", 2: "☁️", 3: "☁️"}.get(code, emoji)

    parts = []
    for key in ("name", "admin1", "country"):
        value = place.get(key)
        if value and value not in parts:
            parts.append(value)

    result = {
        "location": ", ".join(parts) or query,
        "temperature": round(float(current["temperature_2m"])),
        "feelsLike": round(float(current["apparent_temperature"])),
        "humidity": int(current["relative_humidity_2m"]),
        "wind": round(float(current["wind_speed_10m"])),
        "high": round(float(daily["temperature_2m_max"][0])),
        "low": round(float(daily["temperature_2m_min"][0])),
        "code": code,
        "isDay": is_day,
        "description": description,
        "emoji": emoji,
    }
    try:
        os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
        cache_temp = CACHE_PATH + ".tmp"
        with open(cache_temp, "w", encoding="utf-8") as cache_file:
            json.dump({
                "query": query,
                "fetchedAt": time.time(),
                "result": result,
            }, cache_file, ensure_ascii=False)
        os.replace(cache_temp, CACHE_PATH)
    except OSError as exc:
        print("Weather cache could not be saved: " + str(exc), file=sys.stderr)

    print(json.dumps(result, ensure_ascii=False))

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("Veyra weather: " + str(exc), file=sys.stderr)
        sys.exit(1)
