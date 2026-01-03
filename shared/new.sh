PACKAGE_NAME="heart_theme" # lowercase and underscores only
DESCRIPTION="Material app theme"
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
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    require_trailing_commas: true
    prefer_const_constructors: true
    prefer_final_in_for_each: true
    avoid_positional_boolean_parameters: true
    avoid_dynamic_calls: true
    prefer_single_quotes: true

formatter:
  trailing_commas: preserve
EOF

rm "lib/$PACKAGE_NAME.dart"
rm "test/${PACKAGE_NAME}_test.dart"
echo "library;" >> "lib/$PACKAGE_NAME.dart"
echo "void main() {}" >> "test/${PACKAGE_NAME}_test.dart"