kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,POD:.metadata.name,CONTAINER:.spec.containers[*].name,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEM_LIMIT:.spec.containers[*].resources.limits.memory,CPU_REQUEST:.spec.containers[*].resources.requests.cpu,MEM_REQUEST:.spec.containers[*].resources.requests.memory

kubectl get pods -A -o json | jq -r '
.items[] |
  .metadata.namespace as $ns |
  .metadata.name as $pod |
  ([
    .spec.containers[]?.resources.requests.cpu // "0",
    .spec.initContainers[]?.resources.requests.cpu // "0"
  ] | map(sub("m$";"") | tonumber) | add) as $req_cpu_m |
  ([
    .spec.containers[]?.resources.limits.cpu // "0",
    .spec.initContainers[]?.resources.limits.cpu // "0"
  ] | map(sub("m$";"") | tonumber) | add) as $lim_cpu_m |
  ([
    .spec.containers[]?.resources.requests.memory // "0",
    .spec.initContainers[]?.resources.requests.memory // "0"
  ] | map(sub("Mi$";"") | sub("Gi$";"000") | tonumber) | add) as $req_mem_mi |
  ([
    .spec.containers[]?.resources.limits.memory // "0",
    .spec.initContainers[]?.resources.limits.memory // "0"
  ] | map(sub("Mi$";"") | sub("Gi$";"000") | tonumber) | add) as $lim_mem_mi |
  [$ns, $pod, "\($req_cpu_m)m", "\($lim_cpu_m)m", "\($req_mem_mi)Mi", "\($lim_mem_mi)Mi"]
| @tsv' | column -t
