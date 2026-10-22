"""Signe la release avec la clé du projet (ci/debug.keystore) au lieu de la clé debug de la machine de build.

Sans ça, chaque build GitHub Actions est signé avec une clé différente et Android refuse
d'installer la mise à jour par-dessus la version existante.
"""
import re
import sys
from pathlib import Path

app = Path(sys.argv[1] if len(sys.argv) > 1 else "android/app")
kts = app / "build.gradle.kts"
groovy = app / "build.gradle"

if kts.exists():
    s = kts.read_text()
    if 'create("pecule")' not in s:
        block = '''    signingConfigs {
        create("pecule") {
            storeFile = file("../../ci/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {'''
        s = s.replace("    buildTypes {", block, 1)
        s = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                   'signingConfig = signingConfigs.getByName("pecule")', s)
    kts.write_text(s)
    print("build.gradle.kts patché:", 'getByName("pecule")' in s)
elif groovy.exists():
    s = groovy.read_text()
    if "pecule {" not in s:
        block = """    signingConfigs {
        pecule {
            storeFile file('../../ci/debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
    }

    buildTypes {"""
        s = s.replace("    buildTypes {", block, 1)
        s = s.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.pecule")
    groovy.write_text(s)
    print("build.gradle patché:", "signingConfigs.pecule" in s)
else:
    sys.exit("build.gradle introuvable")
