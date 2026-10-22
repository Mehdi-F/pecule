"""Complète le AndroidManifest généré par `flutter create` (nom, réseau, lien de retour bancaire)."""
import sys
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else "android/app/src/main/AndroidManifest.xml")
s = path.read_text()

s = s.replace('android:label="budget_app"', 'android:label="Pécule"')

if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)

# Lien pecule://auth : retour automatique dans l'app après validation dans l'appli de la banque.
# La gestion des liens par Flutter est coupée : c'est le package app_links qui les traite.
if "pecule" not in s.split("<application", 1)[1]:
    extra = """
            <meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>
            <intent-filter android:autoVerify="false">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="pecule" android:host="auth"/>
            </intent-filter>
        </activity>"""
    s = s.replace("</activity>", extra, 1)

path.write_text(s)
print("manifest ok:", "INTERNET" in s, "pecule" in s)
