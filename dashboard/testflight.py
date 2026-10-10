"""Build- und Testerstand aus App Store Connect. Vom Dashboard aufgerufen."""
import time
from pathlib import Path

import jwt
import requests

KEY_ID = "63WW8ZZB26"
ISSUER = "f96b1f15-9ce2-44d4-8390-7400a5ab496a"
KEY = Path(__file__).resolve().parent.parent / "authkeys" / f"AuthKey_{KEY_ID}.p8"
BASE = "https://api.appstoreconnect.apple.com/v1"
APP = "6756582828"
GRUPPE = "b3eb117d-58d6-4168-8fa7-54ef30c71877"


def token() -> str:
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 600,
                       "aud": "appstoreconnect-v1"},
                      KEY.read_text(), algorithm="ES256", headers={"kid": KEY_ID})


def hole(pfad: str, **params) -> dict:
    r = requests.get(BASE + pfad, headers={"Authorization": "Bearer " + token()},
                     params=params, timeout=30)
    r.raise_for_status()
    return r.json()


if __name__ == "__main__":
    b = hole("/builds", **{"filter[app]": APP, "sort": "-uploadedDate",
                           "limit": 4, "include": "buildBetaDetail"})
    det = {i["id"]: i["attributes"] for i in b.get("included", [])}
    for x in b["data"]:
        a = x["attributes"]
        d = det.get(x["relationships"]["buildBetaDetail"]["data"]["id"], {})
        print(f'Build {a["version"]:>3}  {a["processingState"]:<10} '
              f'{a["uploadedDate"][:10]}  extern: {d.get("externalBuildState")}')
    print()
    t = hole(f"/betaGroups/{GRUPPE}/betaTesters", **{"limit": 50})["data"]
    for x in t:
        a = x["attributes"]
        print(f'{a.get("email") or "anonym":<30} {a.get("state")}')
