PACKAGE_NAME="heart_theme" # lowercase and underscores only
DESCRIPTION="Material app theme"
ORG="vin.muffin"

mkdir "$PACKAGE_NAME"
cd "$PACKAGE_NAME" || exit

flutter create . \
  --org "$ORG" \
  --template package \
  --description "$DESCRIPTION" \
  --project-name "$PACKAGE_NAME"

mkdir "lib/src"
rm "lib/$PACKAGE_NAME.dart"
rm "test/${PACKAGE_NAME}_test.dart"
echo "library;" >> "lib/$PACKAGE_NAME.dart"
echo "void main() {}" >> "test/${PACKAGE_NAME}_test.dart"