# Podman Learning Plan

| | |
|---|---|
| **Goal** | Be able to build, run, network, and deploy containerised apps with Podman on Windows, and explain how Podman differs from Docker |
| **Environment** | Windows 11, Podman with a WSL2-backed Podman machine, PowerShell, the helpers in [`PodmanHelpers.ps1`](PodmanHelpers.ps1) |
| **Format** | 10 phases of short lessons. Each lesson teaches one concept in a sentence or two, with something to try. |
| **Suggested pace** | 1–2 phases a week. Each lesson takes 5–15 minutes. Roughly 6–8 weeks in total. |
| **Status** | In progress: Phase 0 done |

## How to use this plan

- Work through the phases and lessons in order. Each one builds on the last: the app image you
  build in Phase 2 is reused through to Phase 8.
- Run the **Try** commands in PowerShell unless the lesson says to run them inside the machine
  (`podman machine ssh`).
- Keep the files you create for each phase in its own folder, such as `02-building-images/`,
  and commit your Containerfiles, compose files and a short `NOTES.md` with what you learned
  and anything that surprised you.
- Keep data written by containers in `data/` or `volumes/`, and image archives as `*.tar`.
  `.gitignore` already excludes them.
- Update the [Progress tracker](#progress-tracker) when you start and finish a phase.
- If a phase adds a command you keep typing, turn it into a helper in `PodmanHelpers.ps1` and
  add it to the README table.

## Learning objectives

When you finish, you should be able to:

1. Explain containers, images, registries and the OCI standards, and how Podman's daemonless,
   rootless design differs from Docker's.
2. Manage the Podman machine on Windows and know which commands run on Windows and which run
   inside the Linux VM.
3. Run, inspect, debug and clean up containers and images.
4. Write efficient Containerfiles, including multi-stage builds, and publish images to a
   registry.
5. Persist data with volumes and bind mounts, and pass config and secrets safely.
6. Connect containers with networks and pods.
7. Define multi-container apps with Compose and with Kubernetes YAML (`podman kube`).
8. Run containers as systemd services with Quadlet, with health checks and auto-update.
9. Apply rootless security practices and troubleshoot common failures.

---

## Phase 0 — Orientation and setup

**Objectives:** Understand what a container is and get a working Podman environment.

#### 0.1 The Podman machine
Containers need a Linux kernel, so on Windows Podman runs them in a small Linux VM called the
Podman machine. You create it once and then start and stop it.

**Try:** `podman machine init`, then `pod-start` and `podman machine list`.

#### 0.2 Client and server
The `podman` command on Windows is only a client; it sends each command to Podman inside the
machine.

**Try:** `podman version` (note the separate client and server) and `podman system connection list`.

`pod-ls` shows both: the client and server versions on its first line, and each connection
under CONNECTIONS.

#### 0.3 Containers vs virtual machines
A container is an isolated process that shares the host's kernel; a VM boots its own kernel.

**Try:** `pod-run docker.io/library/alpine uname -r` and `podman machine ssh uname -r`. The
kernel version is the same.

`pod-ls` shows the machine's kernel (from `podman info`) on its first line.

#### 0.4 Images vs containers
An image is a read-only template; a container is one instance of it, running or stopped.

**Try:** run `podman run quay.io/podman/hello` twice, then compare `podman ps -a` (two
containers) with `podman images` (one image).

#### 0.5 Daemonless
Docker runs every container under one long-running daemon (`dockerd`). If the daemon stops or
crashes, so do the containers, and anything that can talk to it effectively has root. Podman
has no such daemon. `podman run` starts the container, hands it to a small monitor called
`conmon` (one per container), and exits. `conmon` holds the container's logs and exit code, and
its parent is the init process (PID 1), not Podman, so nothing else needs to keep running.

On Windows there *is* a `podman system service` in the machine, because the Windows client
needs an API to talk to (see 0.2). It's started on demand when a command arrives, and the
containers don't depend on it.

**Try:** `podman run -d --name sleeper docker.io/library/alpine sleep 600`, then
`podman machine ssh "ps -eo pid,ppid,args --forest | grep -E 'podman|conmon|sleep 600' | cut -c1-80"`.
The `sleep` process's parent (PPID) is `conmon`, and `conmon`'s parent is `1`.

**Try:** show that the container doesn't need the service. Stop it with
`podman machine ssh "sudo systemctl stop podman.socket podman.service"`, list the processes
again (`conmon` and `sleep` are still running), and see `podman ps` fail from Windows because
the API has gone. Bring it back with `podman machine ssh "sudo systemctl start podman.socket"`,
then `podman ps` shows `sleeper` still up. Remove it with `podman rm -f sleeper`.

If your default connection is rootless (see `pod-ls`), use `systemctl --user` without `sudo`.

#### 0.6 Rootless
By default Podman runs containers as your ordinary user, not as root.

**Try:** `podman info --format '{{.Host.Security.Rootless}}'`

If it prints `false`, the machine has been set to rootful (`podman machine set --rootful`), so
the default connection runs as root. `pod-ls` marks each connection rootless or rootful and
shows which is the default.

#### 0.7 OCI standards
Images and runtimes follow the Open Container Initiative standards, so the same image works in
Podman, Docker and Kubernetes. Podman hands the actual running of a container to an OCI
runtime.

**Try:** `podman info --format '{{.Host.OCIRuntime.Name}}'`

`pod-ls` shows the runtime at the end of its first line.

Optional: install [Podman Desktop](https://podman-desktop.io/) and compare its view with the CLI.

---

## Phase 1 — Images and containers

**Objectives:** Get fluent with the core container lifecycle.

#### 1.1 Image names
A full image name is `registry/namespace/name:tag`, so it's clear where the image comes from.

**Try:** `podman pull docker.io/library/nginx:alpine`

#### 1.2 Short names
A short name like `nginx` has to be resolved to a registry, through aliases or by asking you.
Fully qualified names avoid pulling a lookalike from the wrong registry.

**Try:** `podman machine ssh cat /etc/containers/registries.conf.d/000-shortnames.conf | Select-Object -First 20`

#### 1.3 Tags and digests
A tag like `alpine` can be moved to a new image at any time; a digest (`sha256:…`) always means
exactly the same image.

**Try:** `podman images --digests`

#### 1.4 Layers
An image is a stack of read-only layers, one for each build step, shared between images that
use the same base.

**Try:** `podman history docker.io/library/nginx:alpine`

#### 1.5 One-off containers
`--rm` removes the container as soon as it exits. `pod-run` uses it.

**Try:** `pod-run docker.io/library/alpine ls /`

#### 1.6 Interactive containers
`-it` connects your terminal to the container, for poking around inside it.

**Try:** `podman run -it --rm docker.io/library/alpine sh`, then `exit`.

#### 1.7 Detached, named containers
`-d` runs a container in the background, and `--name` gives it a name to use in later commands.

**Try:** `podman run -d --name web docker.io/library/nginx:alpine`, then `podman ps`.

#### 1.8 Logs
A container's output goes to its log.

**Try:** `podman logs -f web` (Ctrl+C to stop following).

#### 1.9 Exec
`exec` runs an extra command inside a running container.

**Try:** `podman exec -it web sh`, then `wget -qO- localhost` inside it.

#### 1.10 Container states
Containers move between created, running and exited; stopping one keeps it, removing it
deletes it.

**Try:** `podman stop web`, `podman ps -a`, `podman start web`, `podman ps`.

#### 1.11 Inspect
`inspect` shows everything Podman knows about a container or image, as JSON.

**Try:** `podman inspect web`, then pick one field: `podman inspect web --format '{{.State.Status}}'`

#### 1.12 Resource use
`top` shows a container's processes and `stats` its CPU and memory.

**Try:** `podman top web` and `podman stats --no-stream`

#### 1.13 Cleaning up
Stopped containers, unused images and volumes take up disk until you remove them.

**Try:** `podman rm -f web`, then `pod-ls`, `podman system df`, `podman system prune`, `pod-ls`.

---

## Phase 2 — Building images

**Objectives:** Build small, cache-friendly images and share them.

#### 2.1 Containerfiles
A Containerfile (the same format as a Dockerfile) is the recipe for an image. `podman build`
uses Buildah to turn it into one.

**Try:** save this as `Containerfile`, then `podman build -t localhost/hello:1.0 .` and
`podman run --rm localhost/hello:1.0`:
```dockerfile
FROM docker.io/library/alpine:3
CMD ["echo", "hello from my image"]
```

#### 2.2 Build context
Everything in the build folder is sent to the build; `.containerignore` leaves files out.

**Try:** add a large file to the folder, rebuild and watch the context size, then add it to
`.containerignore`.

#### 2.3 RUN, COPY and WORKDIR
`RUN` runs a command at build time, `COPY` adds files and `WORKDIR` sets the working directory.
Each creates a layer.

**Try:** add `WORKDIR /app`, `COPY . .` and `RUN ls` to your Containerfile, rebuild, and run
`podman history localhost/hello:1.0`.

#### 2.4 The build cache
Podman reuses a layer if its step and inputs haven't changed, and rebuilds every step after the
first change.

**Try:** rebuild twice and look for cached steps, then change a copied file and rebuild.

#### 2.5 Ordering for the cache
Put steps that rarely change (installing dependencies) before steps that often change (copying
your source).

**Try:** reorder your Containerfile so a source change doesn't reinstall dependencies.

#### 2.6 ENTRYPOINT vs CMD
`ENTRYPOINT` is the command that always runs; `CMD` gives default arguments, which
`podman run <image> <args>` replaces.

**Try:** `podman run --rm localhost/hello:1.0 echo replaced`, then switch to
`ENTRYPOINT ["echo"]` with `CMD ["hello"]` and run it with and without arguments.

#### 2.7 ENV and EXPOSE
`ENV` sets default environment variables. `EXPOSE` only documents a port; it doesn't publish it.

**Try:** add `ENV GREETING=hi`, rebuild and run `podman run --rm localhost/hello:1.0 env`.

#### 2.8 Multi-stage builds
A multi-stage build compiles in one stage and copies only the result into a small final image.

**Try:** write a small web API in a language you know, containerise it in two stages
(`COPY --from=build …`), and compare its size with a single-stage build. You'll reuse this app
in later phases.

#### 2.9 Non-root users
`USER` makes the container run as an unprivileged user.

**Try:** add a user and `USER` to your app's Containerfile, rebuild, and check with
`podman run --rm <image> id`.

#### 2.10 Registries
Pushing an image to a registry lets you pull it anywhere.

**Try:** `podman login quay.io` (or `ghcr.io` or `docker.io`), `podman tag` your app image with
the registry name, `podman push` it, then remove it locally and `podman pull` it back.

#### 2.11 Saving and loading
`save` writes an image to a tar archive and `load` reads it back, without a registry.

**Try:** `podman save -o hello.tar localhost/hello:1.0`, `podman rmi localhost/hello:1.0`,
`podman load -i hello.tar`.

---

## Phase 3 — Storage, configuration and secrets

**Objectives:** Keep data beyond a container's life and configure containers safely.

#### 3.1 The writable layer is temporary
Each container gets its own writable layer on top of the image, and it's deleted with the
container.

**Try:** `podman run --name tmp docker.io/library/alpine sh -c 'echo hi > /f'`, `podman rm tmp`,
then run a new container and look for `/f`.

#### 3.2 Named volumes
A named volume is storage managed by Podman that outlives any container.

**Try:** `podman volume create mydata`, then
`podman run --rm -v mydata:/data docker.io/library/alpine sh -c 'echo hi > /data/f'` and read it
back from a second container.

#### 3.3 Bind mounts
A bind mount shares a folder from your computer with the container. Windows paths are passed
through to the machine.

**Try:** `podman run --rm -v ${PWD}/data:/data docker.io/library/alpine sh -c 'echo hi > /data/f'`,
then look for `data\f` in Explorer.

#### 3.4 Environment variables
`-e` passes configuration into a container without rebuilding the image.

**Try:** `podman run --rm -e GREETING=hi docker.io/library/alpine env`

#### 3.5 Env files
`--env-file` reads many variables from a file. Commit a `.env.example`, never the real `.env`.

**Try:** create `.env` with two variables and run `podman run --rm --env-file .env docker.io/library/alpine env`.

#### 3.6 Secrets
Podman secrets are mounted as files under `/run/secrets`, so they don't show up in
`podman inspect` like environment variables do.

**Try:** `'S3cret' | podman secret create db_pass -`, then
`podman run --rm --secret db_pass docker.io/library/alpine cat /run/secrets/db_pass`.

#### 3.7 Data outlives the container
With a volume for its data, you can replace a database container without losing anything.

**Try:**
```powershell
podman run -d --name db --secret db_pass -e POSTGRES_PASSWORD_FILE=/run/secrets/db_pass -v pgdata:/var/lib/postgresql/data docker.io/library/postgres:16
```
Create a table with `podman exec -it db psql -U postgres`, remove the container with
`podman rm -f db`, run it again and check the table is still there.

---

## Phase 4 — Networking

**Objectives:** Expose services and let containers talk to each other.

#### 4.1 Publishing ports
`-p host:container` makes a container's port reachable from outside it.

**Try:** `podman run -d --name web -p 8080:80 docker.io/library/nginx:alpine`, then open
`http://localhost:8080` in your browser.

#### 4.2 How ports reach Windows
A published port is opened in the machine and forwarded to Windows' `localhost`.

**Try:** `podman port web`

#### 4.3 Rootless networking
Rootless containers can't create real network interfaces on the host, so Podman 5 uses `pasta`
to give them network access (older versions used `slirp4netns`).

**Try:** `pod-run docker.io/library/alpine ip addr` and compare with
`podman machine ssh ip addr`.

#### 4.4 Low ports
On a standard Linux host, rootless containers can't publish ports below 1024 unless
`net.ipv4.ip_unprivileged_port_start` is lowered.

**Try:** `podman machine ssh sysctl net.ipv4.ip_unprivileged_port_start`

#### 4.5 User-defined networks
A network you create connects the containers you attach to it.

**Try:** `podman network create appnet`, `podman network ls`, `podman network inspect appnet`.

#### 4.6 Container DNS
On a user-defined network, containers find each other by name.

**Try:**
```powershell
podman run -d --name web2 --network appnet docker.io/library/nginx:alpine
podman run --rm --network appnet docker.io/library/alpine wget -qO- web2
```

#### 4.7 The default network has no DNS
Containers on the default network can't reach each other by name.

**Try:** run the same `wget` without `--network appnet` and see it fail.

#### 4.8 Expose only the front door
Only publish ports that need to be reached from outside; containers talk to each other over
the network.

**Try:** run your Phase 2 app and the Phase 3 database on `appnet`, point the app at the
database by name, and publish only the app's port.

---

## Phase 5 — Pods

**Objectives:** Use Podman's pods, a concept Docker doesn't have.

#### 5.1 Pods
A pod is a group of containers that share a network namespace, like a Kubernetes pod.

**Try:** `podman pod create --name web -p 8080:80`, then `podman pod ps`.

#### 5.2 The infra container
Every pod has a small infra container that holds the shared namespaces open.

**Try:** `podman ps -a --pod`

#### 5.3 Adding containers to a pod
Containers join a pod with `--pod`. Ports are published on the pod, not on each container.

**Try:** `podman run -d --pod web docker.io/library/nginx:alpine`, then open `http://localhost:8080`.

#### 5.4 localhost inside a pod
Containers in the same pod reach each other on `localhost`.

**Try:** `podman run --rm --pod web docker.io/library/alpine wget -qO- localhost`

#### 5.5 The sidecar pattern
A sidecar is a helper container, such as a log shipper or proxy, running next to the main one
in a pod.

**Try:** add a container to the pod that fetches `localhost` every few seconds and prints the
result, and watch its logs.

#### 5.6 Pods as a unit
A pod is started, stopped and removed as a whole.

**Try:** `podman pod stop web`, `podman pod start web`, `podman pod rm -f web`.

#### 5.7 Pod or network?
Use a pod for tightly coupled containers that always run together; use a network for services
that scale or change separately.

**Try:** rebuild your app and database as one pod, reaching the database on `localhost`, and
note in `NOTES.md` how it compares with Lesson 4.8.

---

## Phase 6 — Multi-container apps: Compose and Kubernetes YAML

**Objectives:** Describe a whole app declaratively instead of with long `run` commands.

#### 6.1 Compose files
A `compose.yaml` file describes all of an app's containers, networks and volumes in one place.

**Try:** write a `compose.yaml` for your app and database.

#### 6.2 Compose providers
`podman compose` hands the file to a Compose tool (`docker-compose` or `podman-compose`), which
talks to Podman.

**Try:** `podman compose version`

#### 6.3 The Compose lifecycle
One command brings the whole app up and one takes it down.

**Try:** `podman compose up -d`, `podman compose ps`, `podman compose logs`, `podman compose down`.

#### 6.4 Generating Kubernetes YAML
Podman can write Kubernetes YAML describing a pod or container that's already running.

**Try:** recreate your Phase 5 pod, then `podman kube generate web > web.yaml` and read the file.

#### 6.5 Playing Kubernetes YAML
`podman kube play` creates pods, containers and volumes from Kubernetes YAML.

**Try:** remove the pod, then `podman kube play web.yaml`, and `podman kube down web.yaml` to
remove it again.

#### 6.6 A stepping stone to Kubernetes
Because it's Kubernetes YAML, the same file can be the starting point for a real cluster.

**Try:** note in `NOTES.md` what `compose.yaml` and `web.yaml` are each better at.

---

## Phase 7 — Rootless containers and security

**Objectives:** Understand what "rootless" really means and harden containers.

#### 7.1 User namespaces
Root inside a rootless container is mapped to your ordinary user on the host.

**Try:** `podman run -d --name s docker.io/library/alpine sleep 300`, then `podman top s user huser`
shows the user inside and outside the container. Remove it with `podman rm -f s`.

#### 7.2 UID mapping
Container user IDs are mapped to a range of host IDs listed in `/etc/subuid` and `/etc/subgid`.

**Try:** inside the machine, `cat /etc/subuid` and `podman unshare cat /proc/self/uid_map`.

#### 7.3 Bind-mount permissions
Files a non-root container user creates in a bind mount are owned by a mapped ID on the host,
which causes "permission denied". `--userns=keep-id` maps your host user to the same ID inside.

**Try:** inside the machine, write to a bind mount as a non-root container user, check the owner
with `ls -ln`, then repeat with `--userns=keep-id`.

#### 7.4 Capabilities
Root's powers are split into capabilities; containers get a reduced set, and you can drop the rest.

**Try:** `pod-run docker.io/library/alpine grep Cap /proc/self/status`, then
`podman run --rm --cap-drop=ALL docker.io/library/alpine grep Cap /proc/self/status`.

#### 7.5 Read-only root filesystem
`--read-only` stops a container changing its own files; `--tmpfs` gives it scratch space.

**Try:** `podman run --rm --read-only --tmpfs /tmp docker.io/library/alpine sh -c 'touch /f; touch /tmp/f'`

#### 7.6 No new privileges
`--security-opt=no-new-privileges` stops processes gaining privileges through setuid programs.

**Try:** run your app with it and check it still works.

#### 7.7 SELinux labels
On SELinux hosts such as Fedora and RHEL, bind mounts need `:z` (shared) or `:Z` (private) so the
container may use them. They're harmless elsewhere.

**Try:** `podman machine ssh getenforce` to see whether your machine enforces SELinux.

#### 7.8 Rootful machines
A rootful machine runs containers as root inside the VM, for the few things rootless can't do.

**Try:** `podman machine inspect --format '{{.Rootful}}'`. Switch with
`podman machine set --rootful` on a stopped machine only if you need it.

#### 7.9 Image scanning
Scanners check the packages in an image against known vulnerabilities.

**Try:** `podman run --rm docker.io/aquasec/trivy image docker.io/library/nginx:alpine`

#### 7.10 Least privilege
Give a container only what it needs to work.

**Try:** run your app as non-root with `--cap-drop=ALL`, `--read-only`, a `tmpfs` and
`no-new-privileges`, adding back only what it needs. Record what broke and how you fixed it.

---

## Phase 8 — Running containers as services

**Objectives:** Run containers reliably, the way you would on a Linux server. Quadlet runs on
Linux, so do Lessons 8.3–8.8 inside the machine (`podman machine ssh`).

#### 8.1 Restart policies
A restart policy restarts a container automatically when it exits.

**Try:** `podman run -d --name crash --restart=on-failure docker.io/library/alpine sh -c 'sleep 5; exit 1'`,
wait a while, then `podman inspect crash --format '{{.RestartCount}}'`.

#### 8.2 Health checks
A health check is a command Podman runs regularly to see whether the app still works.

**Try:** `podman run -d --name hc --health-cmd 'wget -qO- localhost || exit 1' --health-interval 10s docker.io/library/nginx:alpine`,
then `podman ps` and `podman healthcheck run hc`.

#### 8.3 systemd user services
systemd starts, stops and supervises services; `systemctl --user` manages your own.

**Try:** inside the machine, `systemctl --user list-units --type=service`.

#### 8.4 Quadlet
Quadlet turns a short `.container` file into a systemd service.

**Try:** inside the machine, save this as `~/.config/containers/systemd/web.container`, then run
`systemctl --user daemon-reload` and `systemctl --user start web`:
```ini
[Container]
Image=docker.io/library/nginx:alpine
PublishPort=8080:80

[Install]
WantedBy=default.target
```

#### 8.5 Service logs
systemd collects a service's output in the journal.

**Try:** `journalctl --user -u web`

#### 8.6 Starting at boot
`WantedBy=default.target` starts the service when your user session starts; lingering keeps
user services running without a login.

**Try:** `loginctl show-user $USER --property=Linger`, then `podman machine stop` and `start` and
check the service came back.

#### 8.7 Volumes and networks in Quadlet
`.volume` and `.network` files define those too, and `.container` files refer to them by name.

**Try:** move your app and database to Quadlet, with `Network=appnet.network` and
`Volume=pgdata.volume:/var/lib/postgresql/data`.

#### 8.8 Auto-update
`AutoUpdate=registry` lets `podman auto-update` pull a newer image and restart the service.

**Try:** add it to your app's unit, push a new version of the image, then
`podman auto-update --dry-run` and `podman auto-update`.

Copy your unit files into this repo and commit them. `podman generate systemd` is the older way
to do this, deprecated in favour of Quadlet.

---

## Phase 9 — Troubleshooting and capstone

**Objectives:** Put it all together and practise debugging on your own.

#### 9.1 Events
`podman events` streams everything Podman does as it happens.

**Try:** run `podman events` in one window and start and stop a container in another.

#### 9.2 Debug logging
`--log-level=debug` shows each step Podman takes, which pinpoints where a command fails.

**Try:** `podman --log-level=debug run --rm docker.io/library/alpine true`

#### 9.3 System information and reset
`podman info` describes the whole setup; `podman system reset` deletes all containers, images and
volumes and is a last resort.

**Try:** `podman info` (don't run the reset).

#### 9.4 Practising failure
Breaking things on purpose is the quickest way to learn the error messages.

**Try:** start a container with a wrong port, a bad bind-mount permission and a missing secret,
and fix each using only Lessons 9.1–9.3 and `podman logs`/`inspect`.

### Capstone project

Build a small app of your choice with at least three services (for example web front end, API
and database) that:

- Builds each image from a multi-stage Containerfile running as non-root.
- Uses a user-defined network or a pod, a named volume and a Podman secret.
- Starts with both `podman compose` and `podman kube play`.
- Runs as Quadlet services with health checks inside the machine.
- Has its images pushed to a registry.
- Has a `README.md` explaining how to run it and the design choices.

---

## Progress tracker

| Phase | Topic | Lessons | Status | Started | Finished | Notes |
|---|---|---|---|---|---|---|
| 0 | Orientation and setup | 7 | Done | 2026-09-24 | 2026-09-24 | 0.2, 0.3, 0.6 and 0.7 built into `pod-ls` (versions, kernel, connections, runtime) |
| 1 | Images and containers | 13 | Not started | | | |
| 2 | Building images | 11 | Not started | | | |
| 3 | Storage, configuration and secrets | 7 | Not started | | | |
| 4 | Networking | 8 | Not started | | | |
| 5 | Pods | 7 | Not started | | | |
| 6 | Compose and Kubernetes YAML | 6 | Not started | | | |
| 7 | Rootless containers and security | 10 | Not started | | | |
| 8 | Running containers as services | 8 | Not started | | | |
| 9 | Troubleshooting and capstone | 4 + project | Not started | | | |

Status values: Not started, In progress, Done.

## Resources

- [Podman documentation](https://docs.podman.io/) — command reference and tutorials
- [Podman tutorials](https://github.com/containers/podman/tree/main/docs/tutorials) — rootless
  setup, basic networking, and more
- [Podman on Windows](https://github.com/containers/podman/blob/main/docs/tutorials/podman-for-windows.md)
- [Quadlet reference (`podman-systemd.unit`)](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Podman Desktop](https://podman-desktop.io/)
- *Podman in Action* by Daniel Walsh (Manning) — in-depth book by one of Podman's creators
- [OCI specifications](https://opencontainers.org/) — the image and runtime standards

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Docker-centric tutorials don't work as written | Most `docker` commands work as `podman`; check the Podman docs when they differ, and note the differences in `NOTES.md` |
| Windows-specific issues (paths, line endings, WSL) | Use forward slashes in mounts, keep Containerfiles and shell scripts LF, and debug from inside `podman machine ssh` |
| The Podman machine gets into a bad state | `podman machine stop`/`start` first; `podman machine rm` and `init` as a last resort, since your files are in git |
| Losing momentum | Lessons are short, so do one or two whenever you have ten minutes, and update the progress tracker after each session |
