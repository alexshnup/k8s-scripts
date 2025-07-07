
# SSH Directory Copy Script

This Bash script allows you to securely copy directories from a remote host using SSH. It can generate a new SSH key or use an existing key provided through an environment variable.
I used it for PVC pre-load.

## Prerequisites
- SSH access to the remote host
- ssh and tar installed on both local and remote machines

## Usage
### Set Environment Variables (optional)
  You can set the following environment variables before running the script:
  
  REMOTE_USER: The username for SSH on the remote host (default: alex)
  REMOTE_HOST: The hostname or IP address of the remote machine (default: host)
  TARGET_PATH: The destination directory where the directories will be copied (default: /data)
  COPY_PATHS: The directories to be copied (default: /home/alex/dir1 /home/alex/dir2)
  SSH_KEY: A custom SSH private key (optional)
  SSH_KEY_STORAGE_DIR: Directory path to store the SSH key (default: /root/.ssh-copy-loader).
  
### Usage in Linux
```
REMOTE_USER=alex  \
REMOTE_HOST=192.168.0.106  \
COPY_PATHS="/home/alex/ti-linux-kernel-dev/3rdparty /home/alex/ti-linux-kernel-dev/deploy"  \
TARGET_PATH=/opt  \
./pvc-ssh-loader.sh
```

## Usage in Kubernetes

```
kubectl create ns test 
```

Create new PVC
```yaml
kubectl -n test apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: longhorn
EOF

```

### Start Job 
we will copy directory /home/alex/ti-linux-kernel-dev/3rdparty   and /home/alex/ti-linux-kernel-dev/deploy  to the claimName: my-data-pvc

First run with Generating SSH key
```yaml
kubectl -n test delete job/copy-to-pvc
kubectl -n test apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: copy-to-pvc
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: copy-loader
          image: alpine:latest
          command: ["/bin/sh", "-c"]
          args:
            - |
              apk add --no-cache openssh bash curl tar && \
              curl -sL https://raw.githubusercontent.com/alexshnup/k8s-scripts/refs/heads/main/pvc-ssh-loader/pvc-ssh-loader.sh -o /tmp/loader.sh && \
              chmod +x /tmp/loader.sh && \
              bash /tmp/loader.sh
          env:
            - name: REMOTE_USER
              value: "alex"
            - name: REMOTE_HOST
              value: "192.168.0.106"
            - name: COPY_PATHS
              value: "/home/alex/ti-linux-kernel-dev/3rdparty /home/alex/ti-linux-kernel-dev/deploy"
            - name: TARGET_PATH
              value: "/mnt/data"
            #- name: SSH_KEY
            #  valueFrom:
            #    secretKeyRef:
            #      name: ssh-private-key
            #      key: id_rsa
          volumeMounts:
            - name: data
              mountPath: /mnt/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: my-data-pvc
EOF
```


```
kubectl -n test get all
NAME                    READY   STATUS    RESTARTS   AGE
pod/copy-to-pvc-rgf6f   1/1     Running   0          58s

NAME                    STATUS    COMPLETIONS   DURATION   AGE
job.batch/copy-to-pvc   Running   0/1           58s        58s
```

Let's see logs

```
kubectl -n test logs job/copy-to-pvc
```

```
Executing busybox-1.37.0-r18.trigger
OK: 24 MiB in 39 packages
🛠️ Generating new SSH key at /root/.ssh-copy-loader/id_rsa

⚠️  Run the following command on the source machine:

    mkdir -p ~/.ssh && echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAA..... root@copy-to-pvc-rgf6f" >> ~/.ssh/authorized_keys

💾 To reuse this SSH key in future k8s jobs:

1. Create a Kubernetes Secret with the following content:

----- BEGIN COMMAND -----
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ssh-private-key
type: Opaque
data:
  id_rsa: LS0tLS1CRUdJTiBPUEVO...
EOF
----- END COMMAND -----

2. Reference it in your job like this:

    env:
      - name: SSH_KEY
        valueFrom:
          secretKeyRef:
            name: ssh-private-key
            key: id_rsa

⏳ Waiting for SSH access to alex@192.168.0.106 ...
… waiting …
```


So our Job is waiting when we run command on remote host

Let's run command on Remote Host
```bash
alex@ubuntu:~$
alex@ubuntu:~$ mkdir -p ~/.ssh && echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQAB.... root@copy-to-pvc-rgf6f" >> ~/.ssh/authorized_keys
```

Check logs again
```
...
...
… waiting …
✅ Connection established!
🧪 Reached after break
✅ COPY_PATHS is set: /home/alex/ti-linux-kernel-dev/3rdparty /home/alex/ti-linux-kernel-dev/deploy

🚚 Copying directories: /home/alex/ti-linux-kernel-dev/3rdparty /home/alex/ti-linux-kernel-dev/deploy
📦 /home/alex/ti-linux-kernel-dev/3rdparty → /mnt/data
📦 /home/alex/ti-linux-kernel-dev/deploy → /mnt/data

✅ Done.

```




List files on PVC
```
kubectl -n test delete pod pvc-inspect
kubectl -n test apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pvc-inspect
spec:
  containers:
  - name: inspector
    image: alpine:latest
    command: ["/bin/sh", "-c"]
    args:
      - |
        echo "📂 Listing contents of mounted PVC:" && \
        ls -lR /data && \
        echo "" && \
        echo "📄 You can also exec into this pod to explore manually."
    volumeMounts:
    - name: data-volume
      mountPath: /data
  restartPolicy: Never
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: my-data-pvc
EOF

```

```
kubectl -n test logs pod/pvc-inspect
```
out:
```
📂 Listing contents of mounted PVC:
/data:
total 24
drwxrwxr-x    3 1000     1000          4096 Apr 21 02:12 3rdparty
drwxrwxr-x    2 1000     1000          4096 Apr 21 14:38 deploy
drwx------    2 root     root         16384 Jul  7 15:18 lost+found

/data/3rdparty:
total 4
drwxrwxr-x    2 1000     1000          4096 Apr 21 13:59 readme

/data/3rdparty/readme:
total 12
-rw-rw-r--    1 1000     1000           765 Apr 21 02:12 FUNDING.yml
-rw-rw-r--    1 1000     1000            73 Apr 21 02:12 README.md
-rw-rw-r--    1 1000     1000           361 Apr 21 02:12 bug_report.md

/data/deploy:
total 85584
-rw-r--r--    1 1000     1000       7647316 Apr 21 14:37 linux-headers-5.10.168-ti-arm64-r118_1xross_arm64.deb
-rw-r--r--    1 1000     1000       7818544 Apr 21 03:25 linux-headers-5.10.168-ti-r82.1_1xross_armhf.deb
```


Okay! All files have been copied.



### More Examples
This is examlpe logs with defined SSH_KEY (without generating ssh-key)
```
kubectl -n test logs job/copy-to-pvc
```
out:
```
Executing busybox-1.37.0-r18.trigger
OK: 24 MiB in 39 packages
🔐 Using SSH key from SSH_KEY variable
⏳ Waiting for SSH access to alex@192.168.0.106 ...
… waiting …
✅ Connection established!
🧪 Reached after break
✅ COPY_PATHS is set: /home/alex/ti-linux-kernel-dev/3rdparty /home/alex/ti-linux-kernel-dev/deploy

🚚 Copying directories: /home/alex/ti-linux-kernel-dev/3rdparty /home/alex/ti-linux-kernel-dev/deploy
📦 /home/alex/ti-linux-kernel-dev/3rdparty → /mnt/data
📦 /home/alex/ti-linux-kernel-dev/deploy → /mnt/data

✅ Done.
```



### Using as InitContainer
```yaml
initContainers:
  - name: scp-loader
    image: alpine:latest
    command: ["sh", "-c"]
    args:
      - |
        apk add --no-cache openssh bash curl tar && \
        curl -sL https://raw.githubusercontent.com/alexshnup/k8s-scripts/refs/heads/main/pvc-ssh-loader/pvc-ssh-loader.sh -o /tmp/loader.sh && \
        chmod +x /tmp/loader.sh && \
        bash /tmp/loader.sh
    env:
      - name: REMOTE_USER
        value: "alex"
      - name: REMOTE_HOST
        value: "192.168.1.55"
      - name: COPY_PATHS
        value: "/etc/myapp /var/log/myapp"
      - name: TARGET_PATH
        value: "/data"
      - name: SSH_KEY
        valueFrom:
          secretKeyRef:
            name: ssh-private-key
            key: id_rsa
    volumeMounts:
      - mountPath: /data
        name: data
```

### Complete SSH Key Setup
Follow the logs instructions to set up the SSH key on the remote host.

### Wait for Connection
The script will wait until the connection to the remote host is successful.

### Copying
The specified directories will be copied to the target path on the local machine.

## Notes
- Ensure that the ~/.ssh directory on the remote host exists and that the authorized_keys file is set up correctly.
- The script will display progress and status messages throughout the process.
- If you provide a key via SSH_KEY, the script will use it instead of generating a new one.
- You can reuse the generated key by exporting it as an environment variable.



