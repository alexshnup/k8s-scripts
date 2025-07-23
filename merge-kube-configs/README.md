# Kubernetes Multi-Cluster Setup with kubectx and Auto-Merging Kubeconfigs

This guide describes how to quickly set up your workstation for easy management of multiple Kubernetes clusters using [`kubectx`](https://github.com/ahmetb/kubectx) and a merge script for kubeconfig files.


## 1. Install Required Tools

### Install `kubectx` and `kubens`

- **macOS:**
  ```sh
  brew install kubectx
  ```

- **Ubuntu/Debian:**
  ```sh
  sudo apt update
  sudo apt install kubectx
  ```

- **Manual/GitHub:**  
  [See official repo instructions](https://github.com/ahmetb/kubectx)



### Install `yq` (YAML CLI processor)

- **macOS:**
  ```sh
  brew install yq
  ```
- **Ubuntu/Debian:**
  ```sh
  sudo snap install yq
  ```
- **Or download latest from GitHub:**  
  [https://github.com/mikefarah/yq#install](https://github.com/mikefarah/yq#install)

---

## 2. Organize Your Kubeconfig Files

- Store all your cluster config files in a directory:  
  `~/.kube/configs/`
- Do not manually edit your main `~/.kube/config` — it will be auto-generated.

---

## 3. Add the Merge Script

Save the script below as `~/merge-kubeconfigs.sh` and make it executable:

```bash
#!/bin/bash
set -e

CONFIGS_DIR="$HOME/.kube/configs"
OUTPUT="$HOME/.kube/config"
TMPDIR=$(mktemp -d)

> "$TMPDIR/renamed_configs.yaml"

for FILE in "$CONFIGS_DIR"/*; do
    [ -f "$FILE" ] || continue
    BASENAME=$(basename "$FILE" | sed 's/[^a-zA-Z0-9]/_/g')

    yq e "
      .users |= map(.name += "-$BASENAME") |
      .clusters |= map(.name += "-$BASENAME") |
      .contexts |= map(
        .name += "-$BASENAME" |
        .context.cluster += "-$BASENAME" |
        .context.user += "-$BASENAME"
      )
    " "$FILE" > "$TMPDIR/renamed_$BASENAME.yaml"

    echo "---" >> "$TMPDIR/renamed_configs.yaml"
    cat "$TMPDIR/renamed_$BASENAME.yaml" >> "$TMPDIR/renamed_configs.yaml"
done

if [ -f "$HOME/.kube/config" ]; then
    echo "---" >> "$TMPDIR/renamed_configs.yaml"
    cat "$HOME/.kube/config" >> "$TMPDIR/renamed_configs.yaml"
fi

yq ea '. as $item ireduce ({}; . *+ $item )' "$TMPDIR/renamed_configs.yaml" > "$OUTPUT"

echo "✅ Merged all kubeconfigs into $OUTPUT"
rm -rf "$TMPDIR"
```

Make it executable:
```sh
chmod +x ~/merge-kubeconfigs.sh
```

---

## 4. Usage

**Whenever you add or update kubeconfig files in `~/.kube/configs/`, run:**
```sh
~/merge-kubeconfigs.sh
```
This will merge all kubeconfig files into your main `~/.kube/config` with unique names.

---

## 5. Working with kubectx and kubectl

- List all available contexts:
  ```sh
  kubectx
  ```
- Switch to a desired context:
  ```sh
  kubectx <context_name>
  ```
- Run standard kubectl commands:
  ```sh
  kubectl get nodes
  ```

---

## Typical Workflow Example

```sh
cp new-cluster-config.yaml ~/.kube/configs/
~/merge-kubeconfigs.sh
kubectx              # See the list of all available contexts
kubectx my-prod-context  # Switch to the desired cluster
kubectl get pods
```

---

## Quick Summary

1. Install `kubectx` and `yq`.
2. Place all kubeconfig files in `~/.kube/configs/`.
3. Use the provided merge script to rebuild `~/.kube/config` whenever you add/remove configs.
4. Use `kubectx` to switch clusters and manage resources.

---

**Tip:**  
You can alias the merge script for convenience, e.g.  
`alias kube-merge="~/merge-kubeconfigs.sh"`

---

Now you are ready to work with any number of Kubernetes clusters from one terminal!

  
