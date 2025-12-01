<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="container_bash"></a>

## container_bash

<pre>
load("@bazel_podman//:container.bzl", "container_bash")

container_bash(<a href="#container_bash-name">name</a>, <a href="#container_bash-container_name">container_name</a>)
</pre>

Start a bash inside a running container.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_bash-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="container_bash-container_name"></a>container_name |  Name of the container   | String | required |  |


<a id="container_logs"></a>

## container_logs

<pre>
load("@bazel_podman//:container.bzl", "container_logs")

container_logs(<a href="#container_logs-name">name</a>, <a href="#container_logs-container_name">container_name</a>)
</pre>

See logs of a running container.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_logs-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="container_logs-container_name"></a>container_name |  Name of the container   | String | required |  |


<a id="container_stop"></a>

## container_stop

<pre>
load("@bazel_podman//:container.bzl", "container_stop")

container_stop(<a href="#container_stop-name">name</a>, <a href="#container_stop-container_name">container_name</a>)
</pre>

Stop a container.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_stop-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="container_stop-container_name"></a>container_name |  Name of the container   | String | required |  |


<a id="container_run"></a>

## container_run

<pre>
load("@bazel_podman//:container.bzl", "container_run")

container_run(<a href="#container_run-name">name</a>, <a href="#container_run-loader">loader</a>, <a href="#container_run-tag">tag</a>, <a href="#container_run-kwargs">**kwargs</a>)
</pre>

Macro to run a container.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="container_run-name"></a>name |  The name of the target.   |  none |
| <a id="container_run-loader"></a>loader |  Either a string (remote image reference) or a Label (an existing `oci_load` target). If `loader` is a Label, it is executed to load the image. If `loader` is a string, it is treated as a remote image reference (e.g. `postgres:16`) and no loader step is performed.   |  none |
| <a id="container_run-tag"></a>tag |  (Optional) The image tag/reference to run. Only used if `loader` is a Label. If not provided, defaults to `{name}:latest`.   |  `None` |
| <a id="container_run-kwargs"></a>kwargs |  Additional arguments passed to the underlying rule (ports, env, volumes, command).   |  none |


