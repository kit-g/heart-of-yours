keytool -genkeypair \
  -v \
  -keystore keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias dev