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
    if "isCoreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(s)
    print("build.gradle.kts patché:", 'getByName("pecule")' in s, "desugaring" in s)
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
    if "coreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    groovy.write_text(s)
    print("build.gradle patché:", "signingConfigs.pecule" in s)
else:
    sys.exit("build.gradle introuvable")

# Petite icône des notifications (silhouette blanche) + règle pour que le shrinker ne la supprime pas.
res = app / "src" / "main" / "res"
(res / "drawable").mkdir(parents=True, exist_ok=True)
icon = Path("assets/icon/ic_stat_pecule.png")
if icon.exists():
    (res / "drawable" / "ic_stat_pecule.png").write_bytes(icon.read_bytes())
(res / "raw").mkdir(parents=True, exist_ok=True)
(res / "raw" / "keep.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_pecule" />\n'
)
print("icône de notification:", icon.exists())
