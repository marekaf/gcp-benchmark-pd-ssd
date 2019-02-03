# Google Cloud Platform - check GCE PD SSDs for IOPS bottlenecks
set your gcp project via gcloud CLI tool and run this script to fetch all your instances and their attached gce-pd-ssd and generate a report if either the instance's cpu or disk size is READ/WRITE IOPS bottleneck.

based on the docs here https://cloud.google.com/compute/docs/disks/performance


## dependencies
`jq` https://stedolan.github.io/jq/

`cp joins.jq ~/.jq`

## example output 
```
./gce-pd-ssd-generate-report.sh: init
./gce-pd-ssd-generate-report.sh: init finished
./gce-pd-ssd-generate-report.sh: fetching data from remote server
fetching data to ./disks.json
fetching data to ./machinetypes.json
fetching data to ./instances.json
concatenating data to ./datamerged.json
./gce-pd-ssd-generate-report.sh: fetching data finished
./gce-pd-ssd-generate-report.sh: denormalizing data
./gce-pd-ssd-generate-report.sh: denormalizing data finished
./gce-pd-ssd-generate-report.sh: computing additional attributes
./gce-pd-ssd-generate-report.sh: computing additional attributes finished
./gce-pd-ssd-generate-report.sh: generating report

"as-n1-disk (1200Gb) disk maximum potential read iops are higher than the instances (as-n1,8vCPU) cpu potential (36000>15000)"
"gke-test-as1-pool-1-2997a072-c1b8 (1200Gb) disk maximum potential read iops are higher than the instances (gke-test-as1-pool-1-2997a072-c1b8,24vCPU) cpu potential (36000>25000)"
"eu-osm1-data (1500Gb) disk maximum potential read iops are higher than the instances (eu-osm1,16vCPU) cpu potential (45000>25000)"

"as-n1-disk (1200Gb) disk maximum potential write iops are higher than the instances (as-n1,8vCPU) cpu potential (30000>15000)"
"gke-test-as1-pool-1-2997a072-c1b8 (1200Gb) disk maximum potential write iops are higher than the instances (gke-test-as1-pool-1-2997a072-c1b8,24vCPU) cpu potential (30000>25000)"
"eu-osm1-data (1500Gb) disk maximum potential write iops are higher than the instances (eu-osm1,16vCPU) cpu potential (30000>25000)"

"gke-test-as1-2dd54287-pvc-a35535ba-a147-11e8-9551-42010af00174 (215Gb) disk maximum potential read iops are lower than the instances (gke-test-as1-pool-1-2997a072-c1b8,24vCPU) cpu potential (6450<25000)"
"eu-gr1 (150Gb) disk maximum potential read iops are lower than the instances (eu-gr1,8vCPU) cpu potential (4500<15000)"
"eu-o1-data (450Gb) disk maximum potential read iops are lower than the instances (eu-o1,8vCPU) cpu potential (13500<15000)"
"eu-m1-data (600Gb) disk maximum potential read iops are lower than the instances (eu-m1,32vCPU) cpu potential (18000<60000)"

"gke-test-as1-2dd54287-pvc-a35535ba-a147-11e8-9551-42010af00174 (215Gb) disk maximum potential write iops are lower than the instances (gke-test-as1-pool-1-2997a072-c1b8,24vCPU) cpu potential (6450<25000)"
"eu-gr1 (150Gb) disk maximum potential write iops are lower than the instances (eu-gr1,8vCPU) cpu potential (4500<15000)"
"eu-o1-data (450Gb) disk maximum potential write iops are lower than the instances (eu-o1,8vCPU) cpu potential (13500<15000)"
"eu-m1-data (600Gb) disk maximum potential write iops are lower than the instances (eu-m1,32vCPU) cpu potential (18000<30000)"

./gce-pd-ssd-generate-report.sh: generating report finished
./gce-pd-ssd-generate-report.sh: all done, exiting now
```
