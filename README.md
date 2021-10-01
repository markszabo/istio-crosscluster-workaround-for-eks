# istio-crosscluster-workaround-for-eks

Workaround for multi-network cross-cluster istio communication being broken on EKS (ref: https://github.com/istio/istio/issues/29359).
This performs the workaround steps decribed in the issue, as summarized here: https://szabo.jp/2021/09/22/multicluster-istio-on-eks/

## How to use:

```bash
kubectl apply -f https://raw.githubusercontent.com/markszabo/istio-crosscluster-workaround-for-eks/main/patch_istio_configmap.yaml
```

This will setup a `CronJob`, that runs every midnight (in case the IP changes), gets the hostname for `istio-eastwestgateway` from the remote cluster, resolves it, checks if the IPs are in the `istio` `ConfigMap` and update it if any IP is missing.

PRs are welcome.