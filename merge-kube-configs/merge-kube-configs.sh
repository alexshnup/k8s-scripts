#!/bin/bash
set -e

CONFIGS_DIR="$HOME/.kube/configs"
OUTPUT="$HOME/.kube/config"
TMPDIR=$(mktemp -d)

# Clear previous result
> "$TMPDIR/renamed_configs.yaml"

for FILE in "$CONFIGS_DIR"/*; do
    [ -f "$FILE" ] || continue
    BASENAME=$(basename "$FILE" | sed 's/[^a-zA-Z0-9]/_/g')   # suffux without spec sumbols

    yq e "
      .users |= map(.name += \"-$BASENAME\") |
      .clusters |= map(.name += \"-$BASENAME\") |
      .contexts |= map(
        .name += \"-$BASENAME\" |
        .context.cluster += \"-$BASENAME\" |
        .context.user += \"-$BASENAME\"
      )
    " "$FILE" > "$TMPDIR/renamed_$BASENAME.yaml"
    # add result list
    echo "---" >> "$TMPDIR/renamed_configs.yaml"
    cat "$TMPDIR/renamed_$BASENAME.yaml" >> "$TMPDIR/renamed_configs.yaml"
done

# if ~/.kube/config is present, will add it as is
if [ -f "$HOME/.kube/config" ]; then
    echo "---" >> "$TMPDIR/renamed_configs.yaml"
    cat "$HOME/.kube/config" >> "$TMPDIR/renamed_configs.yaml"
fi

# create one from maerge arrays
yq ea '. as $item ireduce ({}; . *+ $item )' "$TMPDIR/renamed_configs.yaml" > "$OUTPUT"

echo "✅ Merged all kubeconfigs into $OUTPUT"
rm -rf "$TMPDIR"
