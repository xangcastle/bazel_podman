<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="podman_play_kube"></a>

## podman_play_kube

<pre>
load("@bazel_podman//:kube.bzl", "podman_play_kube")

podman_play_kube(<a href="#podman_play_kube-name">name</a>, <a href="#podman_play_kube-manifest">manifest</a>, <a href="#podman_play_kube-kwargs">**kwargs</a>)
</pre>

Deploys a Kubernetes manifest using Podman pods.

Generates two targets:
  :name -> Plays the manifest (creates pods)
  :name.down -> Tears down the pods


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="podman_play_kube-name"></a>name |  Target name.   |  none |
| <a id="podman_play_kube-manifest"></a>manifest |  The yaml manifest file.   |  none |
| <a id="podman_play_kube-kwargs"></a>kwargs |  Arguments passed to underlying rules.   |  none |


