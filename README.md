<!--
  Copyright 2012-2025 Rùnag project contributors

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->

# Rùnag

## Table of contents

* [Rùnag](#rùnag)
  * [General environment variables](#general-environment-variables)
  * [Environment variables related to remote operations](#environment-variables-related-to-remote-operations)
    * [Basic SSH connection](#basic-ssh-connection)
    * [Remote environment configuration](#remote-environment-configuration)
    * [Retry and debug options](#retry-and-debug-options)
    * [SSH session options](#ssh-session-options)
  * [License](#license)
  * [Get involved](#get-involved)

## General environment variables

* **`RUNAG_TASK` —  Global task array**

  * Although not an environment variable, `RUNAG_TASK` is a global Bash array accessible during script runtime.
  
  * Stores the list of tasks used by `task::` functions.
  
  * Documented here to help prevent naming conflicts.

* **`RUNAG_VERBOSE` — Verbose shell tracing**

  * When set to `"true"`, enables detailed shell tracing.
  
  * The output includes function names, source files, and line numbers.

## Environment variables related to remote operations

These environment variables configure the behavior of remote operations performed by functions such as `ssh::call` and `rsync::sync`.

### Basic SSH connection

* **`REMOTE_USER` — SSH username**

  * Specifies the username for the SSH connection.

* **`REMOTE_HOST` — Remote host address**

  * Specifies the target host, in any format accepted by `ssh` (e.g., `"example.com"` or an IP address).

* **`REMOTE_PORT` — SSH port**

  * Specifies the port to use when connecting via SSH.

### Remote environment configuration

* **`REMOTE_DIR` — Remote working directory**

  * Specifies the directory to switch to on the remote host before running a script or command.

* **`REMOTE_ENV` — Forwarded environment variables**

  * A space-separated list of local environment variable names to forward to the remote host.

  * Only variables that are already defined locally (i.e., `[ -n "$VAR" ]` evaluates as true) are forwarded.

  * *Example:* `"VAR1 VAR2"`

* **`REMOTE_LOCALE` — Remote locale configuration**

  * A space-separated list of locale variable assignments to apply in the remote environment for a single `ssh::call`.

  * This sidesteps SSH’s `SendEnv` and `AcceptEnv` mechanism to ensure consistent locale behavior without relying on SSH environment forwarding.

  * Before applying the new values, `ssh::call` clears any existing `LANG`, `LANGUAGE`, and `LC_*` variables.

  * The locale is first set locally in a subshell for the `ssh` invocation, and then again on the remote host before running the command.

  * *Example:* `"LANG=C.UTF-8 LC_TIME=en_DK.UTF-8"`

  * *See also:* Use `linux::update_remote_locale` to configure persistent locale defaults on the remote system.

* **`REMOTE_NON_ROOT_UMASK` — Umask for non-root users**

  * Sets the file creation mask (`umask`) when the remote command is run by a non-root user.

  * Accepts standard `umask` syntax.

  * *Example:* `0022`

* **`REMOTE_UMASK` — Explicit umask**

  * Sets the file creation mask (`umask`) for the remote session, regardless of user.

  * If both `REMOTE_UMASK` and `REMOTE_NON_ROOT_UMASK` are set, this value takes precedence.

  * *Example:* `0022`

### Retry and debug options

* **`REMOTE_KEEP_TEMP_FILES` — Preserve temporary files**

  * If set to `true`, temporary files created by `ssh::call` (such as the script and I/O streams) are kept on both local and remote machines.

  * Useful for debugging.

  * Defaults to `false`.

* **`REMOTE_RECONNECT_DELAY` — Retry delay**

  * Delay (in seconds) between retry attempts to retrieve results after a remote command fails due to a network-related `ssh` error.

  * Supports integers or floating-point values, depending on the `sleep` implementation.

  * Defaults to `5`.

* **`REMOTE_RECONNECT_TIME_LIMIT` — Maximum retry duration**

  * Maximum time (in seconds) that `ssh::call` will spend attempting to reconnect before stopping.

  * Defaults to `600` (10 minutes).

### SSH session options

* **`REMOTE_CONTROL_MASTER` — SSH connection sharing**

  * Enables SSH connection sharing via the `ControlMaster` setting.

  * Defaults to `auto`, which enables connection sharing on non-Windows systems.

  * Set to `no` to disable connection sharing.

* **`REMOTE_CONTROL_PATH` — SSH control socket path**

  * Sets the path to the SSH control socket used for connection sharing.

  * Defaults to `"${HOME}/.ssh/control-sockets/%C"`.

  * If `REMOTE_FORWARD_AGENT` is `true`, the default path changes to `"${HOME}/.ssh/control-sockets/%C.with-forward-agent"`.

* **`REMOTE_CONTROL_PERSIST` — SSH control socket lifetime**

  * Sets the `ControlPersist` timeout (in seconds), allowing the control socket to remain open after a command finishes.

  * Defaults to `600` (10 minutes).

  * Set to `no` to disable persistence.

* **`REMOTE_FORWARD_AGENT` — Enable SSH agent forwarding**

  * Set to `true` to enable SSH agent forwarding (`ForwardAgent=yes`), allowing the remote host to access SSH keys from the local agent.

  * When enabled, the default control socket filename gains a `.with-forward-agent` suffix to avoid conflicts.

* **`REMOTE_IDENTITY_FILE` — SSH private key path**

  * Specifies the path to the SSH private key used for authentication.

  * If unset, `ssh` uses its default keys or those specified in its configuration.

  * *Example:* `"${HOME}/.ssh/id_ed25519"`

* **`REMOTE_SERVER_ALIVE_INTERVAL` — Keep-alive interval**

  * Sets the SSH `ServerAliveInterval` in seconds.

  * When non-zero, SSH sends periodic keep-alive messages to prevent disconnection due to inactivity.

  * Defaults to `20`.

  * Set to `0` to disable keep-alive messages.

  * Set to `unset` to let the SSH configuration decide.

## License

This project is licensed under the terms of the [Apache License, Version 2.0](LICENSE)

## Get involved

Check out the [CONTRIBUTING](CONTRIBUTING.md) file to learn how to contribute, and the [CONTRIBUTORS](CONTRIBUTORS.md) file to see who’s helped make it happen.
