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


#!/usr/bin/env bash

echo -e "NAMESPACE\tPOD\tCPU(used/limit)\tMEM(used/limit)"

kubectl get pods -A -o json | jq -r '
  .items[] |
  .metadata.namespace as $ns |
  .metadata.name as $pod |
  (
    [ .spec.containers[]?.resources.limits.cpu // "0" ]
    | map(if test("m$") then sub("m$";"")|tonumber else (.|tonumber*1000) end)
    | add
  ) as $cpu_limit_m |
  (
    [ .spec.containers[]?.resources.limits.memory // "0" ]
    | map(
        if test("Gi$") then sub("Gi$";"")|tonumber*1024
        elif test("Mi$") then sub("Mi$";"")|tonumber
        else 0 end
      )
    | add
  ) as $mem_limit_mi |
  [$ns, $pod, $cpu_limit_m, $mem_limit_mi]
| @tsv' | while IFS=$'\t' read -r ns pod cpu_limit mem_limit; do
  usage=$(kubectl top pod -n "$ns" "$pod" --no-headers 2>/dev/null)
  cpu_used=$(awk '{print $2}' <<<"$usage" | sed 's/m//')
  mem_used=$(awk '{print $3}' <<<"$usage" | sed 's/Mi//')
  if [[ -z "$cpu_used" || -z "$mem_used" ]]; then continue; fi
  cpu_pct=$(awk "BEGIN {if ($cpu_limit>0) printf \"%.0f%%\", $cpu_used/$cpu_limit*100; else print \"-\"}")
  mem_pct=$(awk "BEGIN {if ($mem_limit>0) printf \"%.0f%%\", $mem_used/$mem_limit*100; else print \"-\"}")
  echo -e "$ns\t$pod\t${cpu_used}m/${cpu_limit}m ($cpu_pct)\t${mem_used}Mi/${mem_limit}Mi ($mem_pct)"
done | column -t

#!/usr/bin/env bash

echo -e "NAMESPACE\tPOD\tCPU_LIMIT(m)\tCPU_REQUEST(m)\tCPU_USAGE(m)\tMEM_LIMIT(Mi)\tMEM_REQUEST(Mi)\tMEM_USAGE(Mi)"

kubectl get pods -A -o json | jq -r '
  .items[] |
  .metadata.namespace as $ns |
  .metadata.name as $pod |

  # CPU limit
  ([
    (.spec.containers[]?.resources.limits.cpu // "0"),
    (.spec.initContainers[]?.resources.limits.cpu // "0")
  ] | map(
      if test("m$") then sub("m$";"")|tonumber
      else (.|tonumber*1000)
      end
    ) | add) as $cpu_limit |

  # CPU request
  ([
    (.spec.containers[]?.resources.requests.cpu // "0"),
    (.spec.initContainers[]?.resources.requests.cpu // "0")
  ] | map(
      if test("m$") then sub("m$";"")|tonumber
      else (.|tonumber*1000)
      end
    ) | add) as $cpu_req |

  # MEM limit
  ([
    (.spec.containers[]?.resources.limits.memory // "0"),
    (.spec.initContainers[]?.resources.limits.memory // "0")
  ] | map(
      if test("Gi$") then sub("Gi$";"")|tonumber*1024
      elif test("Mi$") then sub("Mi$";"")|tonumber
      else 0 end
    ) | add) as $mem_limit |

  # MEM request
  ([
    (.spec.containers[]?.resources.requests.memory // "0"),
    (.spec.initContainers[]?.resources.requests.memory // "0")
  ] | map(
      if test("Gi$") then sub("Gi$";"")|tonumber*1024
      elif test("Mi$") then sub("Mi$";"")|tonumber
      else 0 end
    ) | add) as $mem_req |

  [$ns, $pod, $cpu_limit, $cpu_req, $mem_limit, $mem_req]
| @tsv' | while IFS=$'\t' read -r ns pod cpu_lim cpu_req mem_lim mem_req; do
  usage=$(kubectl top pod -n "$ns" "$pod" --no-headers 2>/dev/null)
  cpu_used=$(awk '{print $2}' <<<"$usage" | sed 's/m//')
  mem_used=$(awk '{print $3}' <<<"$usage" | sed 's/Mi//')
  if [[ -z "$cpu_used" || -z "$mem_used" ]]; then continue; fi
  echo -e "$ns\t$pod\t${cpu_lim}\t${cpu_req}\t${cpu_used}\t${mem_lim}\t${mem_req}\t${mem_used}"
done | column -t

