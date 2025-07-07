#!/bin/bash

set -e

# === Parameters ===
REMOTE_USER="${REMOTE_USER:-alex}"
REMOTE_HOST="${REMOTE_HOST:-host}"
TARGET_PATH="${TARGET_PATH:-/data}"
COPY_PATHS="${COPY_PATHS:-/home/alex/dir1 /home/alex/dir2}"

STORAGE_DIR="${SSH_KEY_STORAGE_DIR:-/root/.ssh-copy-loader}"
KEY_PATH="$STORAGE_DIR/id_rsa"

mkdir -p "$STORAGE_DIR"

# === Use SSH key from variable or stored file ===
if [[ -n "$SSH_KEY" ]]; then
  echo "🔐 Using SSH key from SSH_KEY variable"
  echo "$SSH_KEY" > "$KEY_PATH"
  chmod 600 "$KEY_PATH"
elif [[ -f "$KEY_PATH" ]]; then
  echo "📂 Using previously generated SSH key from $KEY_PATH"
else
  echo "🛠️ Generating new SSH key at $KEY_PATH"
  ssh-keygen -q -t rsa -N "" -f "$KEY_PATH"
  PUBKEY=$(cat "$KEY_PATH.pub")

  echo ""
  echo "⚠️  Run the following command on the source machine:"
  echo ""
  echo "    mkdir -p ~/.ssh && echo \"$PUBKEY\" >> ~/.ssh/authorized_keys"
  echo ""

  echo "💾 To reuse this SSH key in future k8s jobs:"
  echo ""
  echo "1. Create a Kubernetes Secret with the following content:"
  echo ""
  echo "----- BEGIN COMMAND -----"
  echo "cat <<EOF | kubectl apply -f -"
  echo "apiVersion: v1"
  echo "kind: Secret"
  echo "metadata:"
  echo "  name: ssh-private-key"
  echo "type: Opaque"
  echo "data:"
  echo -n "  id_rsa: "
  base64 -w0 "$KEY_PATH"
  echo ""
  echo "EOF"
  echo "----- END COMMAND -----"
  echo ""
  echo "2. Reference it in your job like this:"
  echo ""
  echo "    env:"
  echo "      - name: SSH_KEY"
  echo "        valueFrom:"
  echo "          secretKeyRef:"
  echo "            name: ssh-private-key"
  echo "            key: id_rsa"
  echo ""
fi

# === Wait for SSH connection ===
echo "⏳ Waiting for SSH access to $REMOTE_USER@$REMOTE_HOST ..."

echo "… waiting …"
while true; do
    if ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
         -o LogLevel=ERROR "$REMOTE_USER@$REMOTE_HOST" 'echo ✅' >/dev/null 2>&1; then
        echo "✅ Connection established!"
        break
    else
        # echo "… waiting …"
        sleep 3
    fi
done

echo "🧪 Reached after break"

if [ -z "$COPY_PATHS" ]; then
  echo "❌ COPY_PATHS is empty"
else
  echo "✅ COPY_PATHS is set: $COPY_PATHS"
fi

# === Copying ===
echo ""
echo "🚚 Copying directories: $COPY_PATHS"
for DIR in $COPY_PATHS; do
    echo "📦 $DIR → $TARGET_PATH"
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" \
        "tar -cz -C \"$(dirname "$DIR")\" \"$(basename "$DIR")\"" \
        | tar -xz -C "$TARGET_PATH"
done

echo ""
echo "✅ Done."
