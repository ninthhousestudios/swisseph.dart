"""Generate reference values from pyswisseph for cross-validation with swisseph.dart.

Uses pyswisseph from libaditya (https://gitlab.com/ninthhouse/libaditya).

Run from a libaditya environment:
    cd <libaditya-checkout>
    uv run python <swisseph.dart>/test/libaditya-validation/generate_reference.py

Outputs JSON to test/libaditya-validation/reference_data.json (next to this script).
"""

import json
import os
import swisseph as swe

EPHE_PATH = os.path.join(os.path.dirname(__file__),
                         "../../libaditya/libaditya/ephe/")
OUTPUT = os.path.join(os.path.dirname(__file__), "reference_data.json")

# ── Test parameters ──────────────────────────────────────────────────────

# Dates as (year, month, day, decimal_hour)
DATES = [
    (2000, 1, 1, 0.0),     # J2000.0 midnight
    (2000, 1, 1, 12.0),    # J2000.0 noon
    (1985, 1, 1, 0.0),     # Known reference date
    (1990, 6, 15, 18.5),   # Roundtrip test date
    (2024, 3, 20, 12.0),   # Vernal equinox 2024 (approx)
    (1947, 8, 15, 0.0),    # Historical: India independence
    (2050, 12, 31, 23.99), # Future date
]

# Planets: (swe_id, name)
PLANETS = [
    (swe.SUN, "Sun"),
    (swe.MOON, "Moon"),
    (swe.MERCURY, "Mercury"),
    (swe.VENUS, "Venus"),
    (swe.MARS, "Mars"),
    (swe.JUPITER, "Jupiter"),
    (swe.SATURN, "Saturn"),
    (swe.URANUS, "Uranus"),
    (swe.NEPTUNE, "Neptune"),
    (swe.PLUTO, "Pluto"),
    (swe.MEAN_NODE, "Mean Node"),
    (swe.TRUE_NODE, "True Node"),
    (swe.CHIRON, "Chiron"),
]

# House systems: (code_char, name)
HOUSE_SYSTEMS = [
    ("P", "Placidus"),
    ("K", "Koch"),
    ("O", "Porphyry"),
    ("R", "Regiomontanus"),
    ("C", "Campanus"),
    ("E", "Equal"),
    ("W", "Whole Sign"),
    ("B", "Alcabitius"),
    ("T", "Topocentric"),
    ("X", "Meridian"),
    ("M", "Morinus"),
]

# Locations: (lat, lon, alt, name)
LOCATIONS = [
    (38.8977, -77.0365, 0, "Washington DC"),
    (28.6139, 77.2090, 0, "New Delhi"),
    (51.5074, -0.1278, 0, "London"),
    (-33.8688, 151.2093, 0, "Sydney"),
    (0.0, 0.0, 0, "Null Island"),
    (64.1466, -21.9426, 0, "Reykjavik"),         # High latitude
    (-54.8019, -68.3030, 0, "Ushuaia"),           # Far south
]

# Ayanamsa modes: (swe_id, name)
AYANAMSAS = [
    (swe.SIDM_FAGAN_BRADLEY, "Fagan-Bradley"),
    (swe.SIDM_LAHIRI, "Lahiri"),
    (swe.SIDM_RAMAN, "Raman"),
    (swe.SIDM_KRISHNAMURTI, "Krishnamurti"),
    (swe.SIDM_YUKTESHWAR, "Yukteshwar"),
    (swe.SIDM_JN_BHASIN, "JN Bhasin"),
    (swe.SIDM_DELUCE, "DeLuce"),
    (swe.SIDM_ARYABHATA, "Aryabhata"),
    (swe.SIDM_TRUE_CITRA, "True Citra"),
    (swe.SIDM_TRUE_REVATI, "True Revati"),
    (swe.SIDM_TRUE_PUSHYA, "True Pushya"),
    (swe.SIDM_GALCENT_MULA_WILHELM, "GalCent Mula Wilhelm"),
    (swe.SIDM_HIPPARCHOS, "Hipparchos"),
    (swe.SIDM_SASSANIAN, "Sassanian"),
]


def generate():
    data = {
        "_meta": {
            "generator": "generate_reference.py",
            "pyswisseph_version": swe.version,
            "ephe_path": os.path.abspath(EPHE_PATH),
            "description": (
                "Reference values from pyswisseph for cross-validation "
                "with swisseph.dart FFI bindings."
            ),
        }
    }

    # ── 1. Julian Day conversion ─────────────────────────────────────────

    juldays = []
    for y, m, d, h in DATES:
        jd = swe.julday(y, m, d, h)
        rev = swe.revjul(jd)
        juldays.append({
            "input": {"year": y, "month": m, "day": d, "hour": h},
            "jd": jd,
            "revjul": {
                "year": rev[0], "month": rev[1],
                "day": rev[2], "hour": rev[3],
            },
        })
    data["julday"] = juldays

    # ── 2. Planet positions — Moshier (tropical) ─────────────────────────

    planet_positions_moshier = []
    for y, m, d, h in DATES:
        jd = swe.julday(y, m, d, h)
        for pid, pname in PLANETS:
            try:
                result, rflag = swe.calc_ut(jd, pid, swe.FLG_MOSEPH | swe.FLG_SPEED)
                planet_positions_moshier.append({
                    "date": {"year": y, "month": m, "day": d, "hour": h},
                    "jd": jd,
                    "body": pid,
                    "body_name": pname,
                    "flags": swe.FLG_MOSEPH | swe.FLG_SPEED,
                    "flags_desc": "MOSEPH|SPEED",
                    "longitude": result[0],
                    "latitude": result[1],
                    "distance": result[2],
                    "longitude_speed": result[3],
                    "latitude_speed": result[4],
                    "distance_speed": result[5],
                    "return_flag": rflag,
                })
            except swe.Error as e:
                planet_positions_moshier.append({
                    "date": {"year": y, "month": m, "day": d, "hour": h},
                    "body": pid,
                    "body_name": pname,
                    "error": str(e),
                })
    data["planet_positions_moshier"] = planet_positions_moshier

    # ── 3. Planet positions — Swiss Ephemeris files (tropical) ───────────

    swe.set_ephe_path(EPHE_PATH)
    planet_positions_swieph = []
    # Use a subset of dates for swieph (only dates covered by .se1 files)
    swieph_dates = [
        (2000, 1, 1, 0.0),
        (2000, 1, 1, 12.0),
        (2024, 3, 20, 12.0),
    ]
    for y, m, d, h in swieph_dates:
        jd = swe.julday(y, m, d, h)
        for pid, pname in PLANETS:
            try:
                result, rflag = swe.calc_ut(jd, pid, swe.FLG_SWIEPH | swe.FLG_SPEED)
                planet_positions_swieph.append({
                    "date": {"year": y, "month": m, "day": d, "hour": h},
                    "jd": jd,
                    "body": pid,
                    "body_name": pname,
                    "flags": swe.FLG_SWIEPH | swe.FLG_SPEED,
                    "flags_desc": "SWIEPH|SPEED",
                    "longitude": result[0],
                    "latitude": result[1],
                    "distance": result[2],
                    "longitude_speed": result[3],
                    "latitude_speed": result[4],
                    "distance_speed": result[5],
                    "return_flag": rflag,
                })
            except swe.Error as e:
                planet_positions_swieph.append({
                    "date": {"year": y, "month": m, "day": d, "hour": h},
                    "body": pid,
                    "body_name": pname,
                    "error": str(e),
                })
    data["planet_positions_swieph"] = planet_positions_swieph

    # ── 4. Sidereal positions — multiple ayanamsas ───────────────────────

    sidereal_positions = []
    jd_j2000 = swe.julday(2000, 1, 1, 0.0)
    jd_2024 = swe.julday(2024, 3, 20, 12.0)

    for jd, jd_label in [(jd_j2000, "J2000"), (jd_2024, "2024-03-20")]:
        for sid_id, sid_name in AYANAMSAS:
            swe.set_sid_mode(sid_id)
            # Get ayanamsa value
            aya = swe.get_ayanamsa_ut(jd)
            # Get sidereal Sun and Moon
            for pid, pname in [(swe.SUN, "Sun"), (swe.MOON, "Moon")]:
                result, rflag = swe.calc_ut(
                    jd, pid, swe.FLG_MOSEPH | swe.FLG_SPEED | swe.FLG_SIDEREAL
                )
                sidereal_positions.append({
                    "jd": jd,
                    "jd_label": jd_label,
                    "ayanamsa_id": sid_id,
                    "ayanamsa_name": sid_name,
                    "ayanamsa_value": aya,
                    "body": pid,
                    "body_name": pname,
                    "longitude": result[0],
                    "latitude": result[1],
                    "longitude_speed": result[3],
                })
    data["sidereal_positions"] = sidereal_positions

    # ── 5. Ayanamsa values at multiple dates ─────────────────────────────

    ayanamsa_values = []
    for y, m, d, h in DATES:
        jd = swe.julday(y, m, d, h)
        for sid_id, sid_name in AYANAMSAS:
            swe.set_sid_mode(sid_id)
            aya = swe.get_ayanamsa_ut(jd)
            ayanamsa_values.append({
                "date": {"year": y, "month": m, "day": d, "hour": h},
                "jd": jd,
                "ayanamsa_id": sid_id,
                "ayanamsa_name": sid_name,
                "value": aya,
            })
    data["ayanamsa_values"] = ayanamsa_values

    # ── 6. Ayanamsa names ────────────────────────────────────────────────

    ayanamsa_names = []
    for sid_id, sid_name in AYANAMSAS:
        swe.set_sid_mode(sid_id)
        name = swe.get_ayanamsa_name(sid_id)
        ayanamsa_names.append({
            "id": sid_id,
            "expected_name": sid_name,
            "swe_name": name,
        })
    data["ayanamsa_names"] = ayanamsa_names

    # ── 7. House cusps — multiple systems × locations × dates ────────────

    house_cusps = []
    house_dates = [
        (2000, 1, 1, 12.0),
        (2024, 3, 20, 12.0),
    ]
    for y, m, d, h in house_dates:
        jd = swe.julday(y, m, d, h)
        for lat, lon, alt, loc_name in LOCATIONS:
            for hsys_char, hsys_name in HOUSE_SYSTEMS:
                try:
                    cusps, ascmc = swe.houses(jd, lat, lon, hsys_char.encode())
                    house_cusps.append({
                        "date": {"year": y, "month": m, "day": d, "hour": h},
                        "jd": jd,
                        "location": {"lat": lat, "lon": lon, "name": loc_name},
                        "hsys_char": hsys_char,
                        "hsys_code": ord(hsys_char),
                        "hsys_name": hsys_name,
                        "cusps": list(cusps),  # 12 or 36 values
                        "ascmc": list(ascmc),   # 8+ values
                    })
                except Exception as e:
                    house_cusps.append({
                        "date": {"year": y, "month": m, "day": d, "hour": h},
                        "jd": jd,
                        "location": {"lat": lat, "lon": lon, "name": loc_name},
                        "hsys_char": hsys_char,
                        "hsys_name": hsys_name,
                        "error": str(e),
                    })
    data["house_cusps"] = house_cusps

    # ── 8. House system names ────────────────────────────────────────────

    house_names = []
    for hsys_char, hsys_name in HOUSE_SYSTEMS:
        swe_name = swe.house_name(hsys_char.encode())
        house_names.append({
            "char": hsys_char,
            "code": ord(hsys_char),
            "expected": hsys_name,
            "swe_name": swe_name,
        })
    data["house_names"] = house_names

    # ── 9. Planet names ──────────────────────────────────────────────────

    planet_names = []
    for pid, pname in PLANETS:
        swe_name = swe.get_planet_name(pid)
        planet_names.append({
            "id": pid,
            "expected": pname,
            "swe_name": swe_name,
        })
    data["planet_names"] = planet_names

    # ── 10. Rise/set times ───────────────────────────────────────────────

    rise_set = []
    rise_dates = [
        (2000, 1, 1, 0.0),
        (2024, 3, 20, 0.0),
    ]
    for y, m, d, h in rise_dates:
        jd = swe.julday(y, m, d, h)
        for lat, lon, alt, loc_name in LOCATIONS[:4]:  # Subset of locations
            for pid, pname in [(swe.SUN, "Sun"), (swe.MOON, "Moon")]:
                for flag, flag_name in [
                    (swe.CALC_RISE, "rise"),
                    (swe.CALC_SET, "set"),
                ]:
                    try:
                        # pyswisseph signature:
                        # rise_trans(tjdut, body, rsmi, geopos, atpress, attemp, flags)
                        result = swe.rise_trans(
                            jd, pid, flag,
                            (lon, lat, alt),
                            1013.25, 15.0,
                            swe.FLG_MOSEPH,
                        )
                        rise_set.append({
                            "date": {"year": y, "month": m, "day": d, "hour": h},
                            "jd": jd,
                            "body": pid,
                            "body_name": pname,
                            "event": flag_name,
                            "flag": flag,
                            "location": {
                                "lat": lat, "lon": lon,
                                "alt": alt, "name": loc_name,
                            },
                            "transit_jd": result[1][0],
                            "return_flag": result[0],
                        })
                    except Exception as e:
                        rise_set.append({
                            "date": {"year": y, "month": m, "day": d, "hour": h},
                            "body": pid,
                            "body_name": pname,
                            "event": flag_name,
                            "location": {"name": loc_name},
                            "error": str(e),
                        })
    data["rise_set"] = rise_set

    # ── 11. Degree normalization ─────────────────────────────────────────

    degnorm_cases = []
    test_values = [
        0.0, 90.0, 180.0, 270.0, 359.999, 360.0,
        -10.0, -90.0, -180.0, -360.0, -720.5,
        370.0, 720.0, 1080.123, 0.001,
    ]
    for val in test_values:
        result = swe.degnorm(val)
        degnorm_cases.append({"input": val, "output": result})
    data["degnorm"] = degnorm_cases

    # ── 12. Topocentric positions ────────────────────────────────────────

    topocentric = []
    jd = swe.julday(2000, 1, 1, 12.0)
    for lat, lon, alt, loc_name in LOCATIONS[:4]:
        swe.set_topo(lon, lat, alt)
        for pid, pname in [(swe.SUN, "Sun"), (swe.MOON, "Moon")]:
            result, rflag = swe.calc_ut(
                jd, pid, swe.FLG_MOSEPH | swe.FLG_SPEED | swe.FLG_TOPOCTR
            )
            topocentric.append({
                "jd": jd,
                "body": pid,
                "body_name": pname,
                "location": {"lat": lat, "lon": lon, "alt": alt, "name": loc_name},
                "longitude": result[0],
                "latitude": result[1],
                "distance": result[2],
                "longitude_speed": result[3],
            })
    data["topocentric"] = topocentric

    # ── 13. Equatorial coordinates ───────────────────────────────────────

    equatorial = []
    jd = swe.julday(2000, 1, 1, 0.0)
    for pid, pname in PLANETS[:7]:  # Classical planets
        result, rflag = swe.calc_ut(
            jd, pid, swe.FLG_MOSEPH | swe.FLG_SPEED | swe.FLG_EQUATORIAL
        )
        equatorial.append({
            "jd": jd,
            "body": pid,
            "body_name": pname,
            "right_ascension": result[0],
            "declination": result[1],
            "distance": result[2],
            "ra_speed": result[3],
            "dec_speed": result[4],
        })
    data["equatorial"] = equatorial

    # ── Write output ─────────────────────────────────────────────────────

    with open(OUTPUT, "w") as f:
        json.dump(data, f, indent=2)

    # Print summary
    total = 0
    for key, val in data.items():
        if key.startswith("_"):
            continue
        count = len(val)
        total += count
        print(f"  {key}: {count} entries")
    print(f"  TOTAL: {total} reference values")
    print(f"Written to {OUTPUT}")


if __name__ == "__main__":
    generate()
