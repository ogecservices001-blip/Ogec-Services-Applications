# google_mlkit_text_recognition référence en interne les reconnaisseurs
# chinois/devanagari/japonais/coréen même si on n'utilise que le latin
# (TextRecognitionScript.latin) — ces classes ne sont pas dans nos
# dépendances (on n'a pas ajouté ces modules ML Kit optionnels), R8
# échoue sinon en release faute de les trouver.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
