# Podman Learning Plan

| | |
|---|---|
| **Goal** | Be able to build, run, network, and deploy containerised apps with Podman on Windows, and explain how Podman differs from Docker |
| **Environment** | Windows 11, Podman with a WSL2-backed Podman machine, PowerShell, the helpers in [`PodmanHelpers.ps1`](PodmanHelpers.ps1) |
| **Format** | 10 phases, each with objectives, tasks, a hands-on lab and exit criteria. Work through them in order. |
| **Suggested pace** | 1–2 phases a week, about 3–5 hours each. Roughly 6–8 weeks in total. |
| **Status** | Not started |

## How to use this plan

- Work through the phases in order. Each one builds on the last.
- Do each lab in its own folder, `labs/NN-topic/`, and commit your Containerfiles, compose files
  and a short `NOTES.md` with what you learned and anything that surprised you.
- Keep data written by containers in `data/` or `volumes/`, and image archives as `*.tar`.
  `.gitignore` already excludes them.
- A phase is done when you meet **every** exit criterion without looking up the answer. Tick it
  off in [Progress tracker](#progress-tracker).
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

**Concepts:** containers vs virtual machines; images vs containers; OCI image and runtime specs;
daemonless architecture (fork/exec, no background service); rootless containers; why Windows
needs a Linux VM (the Podman machine).

**Tasks**
- Read the [Podman introduction](https://docs.podman.io/en/latest/Introduction.html) and
  [What is Podman?](https://docs.podman.io/en/latest/index.html).
- Install Podman, then run `podman machine init` and `podman machine start` (or `pod_start`).
- Explore the machine: `podman machine list`, `podman machine inspect`, `podman info`,
  `podman version` (note the separate client and server versions).
- Open a shell inside the VM with `podman machine ssh` and look around (`cat /etc/os-release`,
  `ps aux`). Notice there's no Podman daemon running.
- Optional: install [Podman Desktop](https://podman-desktop.io/) and compare its view with the CLI.

**Lab 0:** Run `pod_test` and `pod_test_2`. In `labs/00-setup/NOTES.md`, sketch how a command
travels from PowerShell → Podman client → machine VM → container.

**Exit criteria**
- [ ] You can explain why Podman on Windows needs a VM, and where your containers actually run.
- [ ] You can start, stop, inspect and SSH into the Podman machine.
- [ ] You can name two practical differences between Podman and Docker.

---

## Phase 1 — Images and containers

**Objectives:** Get fluent with the core container lifecycle.

**Concepts:** fully qualified image names (`registry/namespace/name:tag`), short-name
resolution and `registries.conf`, tags vs digests, image layers, container states.

**Tasks**
- Pull and list images: `podman pull docker.io/library/nginx`, `podman images`, `podman rmi`.
- Run containers in different modes: one-off (`--rm`), interactive (`-it`), detached (`-d`),
  named (`--name`).
- Manage a running container: `podman ps -a`, `logs -f`, `exec -it <c> sh`, `stop`,
  `start`, `restart`, `rm`.
- Inspect things: `podman inspect`, `podman history <image>`, `podman top`, `podman stats`.
- Clean up with `podman system df` and `podman system prune`.

**Lab 1:** Run nginx detached, `exec` into it to edit the default page, `curl` it from inside
the container, then stop and remove it. Use `pod_ls` before and after to check the cleanup.

**Exit criteria**
- [ ] You can run, attach to, inspect, stop and remove a container without notes.
- [ ] You can explain why fully qualified image names are safer than short names.
- [ ] You can find a container's IP address, environment variables and mounts with `inspect`.

---

## Phase 2 — Building images

**Objectives:** Build small, cache-friendly images and share them.

**Concepts:** `Containerfile`/`Dockerfile` instructions (`FROM`, `RUN`, `COPY`, `WORKDIR`,
`ENV`, `EXPOSE`, `USER`, `ENTRYPOINT` vs `CMD`), build context and `.containerignore`,
layer caching, multi-stage builds, Buildah (the build engine behind `podman build`).

**Tasks**
- Build and tag an image: `podman build -t localhost/hello:1.0 .`
- Reorder instructions and watch how the cache changes; compare sizes with `podman images`.
- Turn a single-stage build into a multi-stage one and compare the image sizes.
- Run the image as a non-root user (`USER`).
- Tag and push to a registry you have an account on (Quay.io, GitHub Container Registry or
  Docker Hub): `podman login`, `podman tag`, `podman push`.
- Save and load an image offline: `podman save -o hello.tar`, `podman load -i hello.tar`.

**Lab 2:** Containerise a small app in a language you know (for example a minimal web API).
Build it single-stage, then multi-stage, and record both image sizes in `NOTES.md`.

**Exit criteria**
- [ ] You can write a multi-stage Containerfile that runs as a non-root user.
- [ ] You can explain `ENTRYPOINT` vs `CMD` and when the build cache is invalidated.
- [ ] You have pushed an image to a registry and pulled it back.

---

## Phase 3 — Storage, configuration and secrets

**Objectives:** Keep data beyond a container's life and configure containers safely.

**Concepts:** container writable layer vs named volumes vs bind mounts; how Windows paths map
into the Podman machine; environment variables; Podman secrets.

**Tasks**
- Named volumes: `podman volume create`, `-v mydata:/data`, `podman volume inspect`, `rm`.
- Bind mounts from Windows: `-v ${PWD}/data:/data` and check the file ownership inside and
  outside the container.
- Configuration: `-e KEY=value` and `--env-file .env` (keep a committed `.env.example` only).
- Secrets: `podman secret create`, `--secret`, and where secrets appear inside the container.

**Lab 3:** Run PostgreSQL with a named volume and a password from a Podman secret. Create a
table, delete the container, start a new one on the same volume and confirm the data is still
there.

**Exit criteria**
- [ ] You can choose between a volume and a bind mount and justify it.
- [ ] Data survives removing and recreating a container.
- [ ] No passwords appear in your committed files or in `podman inspect` environment output.

---

## Phase 4 — Networking

**Objectives:** Expose services and let containers talk to each other.

**Concepts:** port publishing, rootless networking (pasta by default in Podman 5, slirp4netns
before that), user-defined networks with built-in DNS (Netavark and Aardvark-dns), how ports
reach Windows through the machine.

**Tasks**
- Publish ports: `-p 8080:80`, then open `http://localhost:8080` in a Windows browser.
- Create a network: `podman network create appnet`, then `podman network ls` and `inspect`.
- Run two containers on `appnet` and reach one from the other by container name.
- Compare the default network with a user-defined one.

**Lab 4:** Connect the Phase 2 app to the Phase 3 database over a user-defined network, reaching
the database by name, and expose only the app's port to Windows.

**Exit criteria**
- [ ] You can explain the path from a Windows browser to a port inside a container.
- [ ] Containers find each other by name on a user-defined network.
- [ ] You can explain why rootless containers can't bind ports below 1024 by default.

---

## Phase 5 — Pods

**Objectives:** Use Podman's pods, a concept Docker doesn't have.

**Concepts:** pods as a group of containers sharing network (and optionally other)
namespaces; the infra container; the sidecar pattern; how pods map to Kubernetes pods.

**Tasks**
- `podman pod create --name web -p 8080:80`, then add containers with `--pod web`.
- Inspect with `podman pod ps`, `podman pod inspect` and `podman ps --pod`.
- Show that containers in a pod reach each other on `localhost`.
- Stop, start and remove the pod as a unit.

**Lab 5:** Rebuild the Lab 4 app and database as a single pod, with the app reaching the
database on `localhost`. Write down how this compares with the network approach.

**Exit criteria**
- [ ] You can explain what the infra container does.
- [ ] You can say when to use a pod and when to use a network.

---

## Phase 6 — Multi-container apps: Compose and Kubernetes YAML

**Objectives:** Describe a whole app declaratively instead of with long `run` commands.

**Concepts:** `podman compose` (a wrapper around a Compose provider such as `docker-compose`
or `podman-compose`), `podman kube generate` and `podman kube play`, how Podman-generated YAML
maps to Kubernetes.

**Tasks**
- Write a `compose.yaml` for the app and database and run it with `podman compose up -d`,
  `logs` and `down`.
- Generate Kubernetes YAML from the Lab 5 pod: `podman kube generate web > web.yaml`.
- Tear everything down and recreate it with `podman kube play web.yaml`, then remove it with
  `podman kube down web.yaml`.

**Lab 6:** Keep both a `compose.yaml` and a `web.yaml` for the same app in `labs/06-compose/`,
and note in `NOTES.md` what each one is better at.

**Exit criteria**
- [ ] One command brings the whole app up and one brings it down, both ways.
- [ ] You can explain why `podman kube` is a stepping stone to Kubernetes.

---

## Phase 7 — Rootless containers and security

**Objectives:** Understand what "rootless" really means and harden containers.

**Concepts:** user namespaces and UID mapping (`/etc/subuid`, `/etc/subgid`), `podman unshare`,
`--userns=keep-id`, Linux capabilities, SELinux labels (`:z`/`:Z` on mounts), read-only root
filesystems, rootful vs rootless machine (`podman machine set --rootful`).

**Tasks**
- Inside the machine, compare `id` on the host with `id` inside a container, and look at the UID
  mapping with `podman unshare cat /proc/self/uid_map`.
- Fix a bind-mount permission problem with `--userns=keep-id` or `podman unshare chown`.
- Run a container with `--cap-drop=ALL`, `--read-only` and `--security-opt=no-new-privileges`,
  and add back only what it needs.
- Scan an image for vulnerabilities with a scanner such as Trivy (run as a container).

**Lab 7:** Harden the Lab 2 app: non-root user, all capabilities dropped, read-only root
filesystem with a `tmpfs` where it needs to write. Record what broke and how you fixed it.

**Exit criteria**
- [ ] You can explain why root inside a rootless container isn't root on the host.
- [ ] You can diagnose and fix a "permission denied" on a bind mount.
- [ ] Your app runs with no capabilities it doesn't need.

---

## Phase 8 — Running containers as services

**Objectives:** Run containers reliably, the way you would on a Linux server.

**Concepts:** restart policies, health checks, systemd, Quadlet (`.container`, `.volume`,
`.network`, `.pod`, `.kube` unit files), `podman auto-update`. Quadlet runs on Linux, so do this
phase inside the Podman machine (`podman machine ssh`).

**Tasks**
- Add a health check (`--health-cmd` or `HEALTHCHECK`) and watch it with `podman ps` and
  `podman healthcheck run`.
- Try `--restart=always` and see what happens when the container process dies.
- Write a Quadlet `.container` file in `~/.config/containers/systemd/`, then run
  `systemctl --user daemon-reload` and `systemctl --user start <name>`.
- Enable auto-update with `--label io.containers.autoupdate=registry` (or `AutoUpdate=registry`
  in Quadlet), push a new image tag and run `podman auto-update`.

**Lab 8:** Run the app and database as Quadlet units with a health check, and confirm they come
back after `podman machine stop` / `start`. Commit the unit files to `labs/08-quadlet/`.

**Exit criteria**
- [ ] Your app starts on boot of the machine with no manual commands.
- [ ] You can read service logs with `journalctl --user -u <name>`.
- [ ] You can explain why Quadlet replaced `podman generate systemd`.

---

## Phase 9 — Troubleshooting and capstone

**Objectives:** Put it all together and prove you can debug on your own.

**Troubleshooting toolkit:** `podman logs`, `podman inspect`, `podman events`,
`podman system info`, `--log-level=debug`, `podman machine ssh`, `podman system reset`
(last resort: it deletes everything).

**Capstone project:** Build a small app of your choice with at least three services (for example
web front end, API and database) that:

- [ ] Builds each image from a multi-stage Containerfile running as non-root.
- [ ] Uses a user-defined network or a pod, a named volume and a Podman secret.
- [ ] Can be started with both `podman compose` and `podman kube play`.
- [ ] Runs as Quadlet services with health checks inside the machine.
- [ ] Has images pushed to a registry.
- [ ] Has a `README.md` explaining how to run it and the design choices.

Commit it to `labs/09-capstone/`.

**Exit criteria**
- [ ] The capstone meets every item above.
- [ ] You can break it deliberately (wrong port, bad permission, missing secret) and fix it using
      only the troubleshooting toolkit.

---

## Progress tracker

| Phase | Topic | Status | Started | Finished | Notes |
|---|---|---|---|---|---|
| 0 | Orientation and setup | Not started | | | |
| 1 | Images and containers | Not started | | | |
| 2 | Building images | Not started | | | |
| 3 | Storage, configuration and secrets | Not started | | | |
| 4 | Networking | Not started | | | |
| 5 | Pods | Not started | | | |
| 6 | Compose and Kubernetes YAML | Not started | | | |
| 7 | Rootless containers and security | Not started | | | |
| 8 | Running containers as services | Not started | | | |
| 9 | Troubleshooting and capstone | Not started | | | |

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
| The Podman machine gets into a bad state | `podman machine stop`/`start` first; `podman machine rm` and `init` as a last resort, since labs are in git |
| Losing momentum | Keep phases short, update the progress tracker after each session |
