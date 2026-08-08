#!/bin/sh
# One-time recipe: generates the Android upload keystore (the real one lives in S3;
# see google-play-deployment.yml). Run from wherever the keystore should land.
keytool -genkeypair \
  -v \
  -keystore keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias dev