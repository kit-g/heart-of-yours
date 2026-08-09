#!/bin/sh
# Scaffolds a new shared package. Run from shared/, editing the three
# variables first. Remember to add the package to the root pubspec's
# `workspace:` list and to the Makefile/CI matrix.
PACKAGE_NAME="${1:?usage: ./new.sh <package_name> [description]}" # lowercase and underscores only
DESCRIPTION="${2:-A shared heart package}"
ORG="me.heart-of"

mkdir "$PACKAGE_NAME"
cd "$PACKAGE_NAME" || exit

flutter create . \
  --org "$ORG" \
  --template package \
  --description "$DESCRIPTION" \
  --project-name "$PACKAGE_NAME"

mkdir "lib/src"

cat <<EOF > analysis_options.yaml
# Single source of truth: the root config carries the lint set and formatter.
include: ../../analysis_options.yaml
EOF

rm "lib/$PACKAGE_NAME.dart"
rm "test/${PACKAGE_NAME}_test.dart"
echo "library;" >> "lib/$PACKAGE_NAME.dart"
echo "void main() {}" >> "test/${PACKAGE_NAME}_test.dart"
