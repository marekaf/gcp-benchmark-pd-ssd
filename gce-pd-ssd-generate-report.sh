#!/bin/bash

## GLOBAL VARS
echo "$0: init"

# tmp files for fetching data from Google APIs
DISKS_FILE=./disks.json
MACHINE_TYPES_FILE=./machinetypes.json
INSTANCES_FILE=./instances.json

# other tmp files
DATA_MERGED_FILE=./datamerged.json
DATA_DENORM_FILE=./datadenorm.json
DATA_COMPUTED_FILE=./datacomputed.json

echo "$0: init finished"

## FETCH DATA
echo "$0: fetching data from remote server"

# fetch all gce pd ssds and save it to file
echo "fetching data to $DISKS_FILE"
gcloud compute disks         list --format json | jq '[ .[] | select(.type | match(".*pd-ssd$")) | {diskId: .selfLink, type: .type, blockSize: .physicalBlockSizeBytes, sizeGb: .sizeGb, instanceId: .users[]} ]' >"$DISKS_FILE"

# fetch all gce machine types and save it to file
echo "fetching data to $MACHINE_TYPES_FILE"
gcloud compute machine-types list --format json | jq '[ .[] | {machineTypeId: .selfLink, ram: .memoryMb, cpu: .guestCpus} ] ' >"$MACHINE_TYPES_FILE"

# fetch all gce instances and save it to file
echo "fetching data to $INSTANCES_FILE"
gcloud compute instances     list --format json | jq '[ .[] | {instanceId: .selfLink, machineTypeId: .machineType, diskId: .disks[].source }]' >"$INSTANCES_FILE"

# concatenate everything to one big json data file
echo "concatenating data to $DATA_MERGED_FILE"
( echo '{ "machinetypes": ' ; cat "$MACHINE_TYPES_FILE" ; echo ', "instances": ' ; cat "$INSTANCES_FILE" ; echo ', "disks": ' ; cat "$DISKS_FILE"; echo "}" ) \
  | jq '.' >"$DATA_MERGED_FILE"

echo "$0: fetching data finished"

## LEFT JOIN
echo "$0: denormalizing data"
# we need the left join because of the fact that custom machines are not in machine-types, so after this:
#cat "$DATA_MERGED_FILE" | jq '[.instances, .machinetypes] | left_joins(.machineTypeId) | add'
# we have instances LEFT JOIN machinetypes USING machineTypeId, concatenated (the '| add' command) to one object having attributed from both instances and machinetypes

## computedCpu
# if the instance has a custom machine type, LEFT JOIN won't match any machinetype but will stay in the dataset, we need to parse the number of vCPUs from the resource's URI
# {computedcpu: (if(.cpu==null) then (.machineTypeId|split("-"))[-2]|tonumber  else .cpu end)}
# (.machineTypeId|split("-"))[-2] means split string intro array by separator '-' a take the last-but-one's value 
# for: https://www.googleapis.com/compute/v1/projects/my-test/zones/europe-west1-b/machineTypes/custom-24-159744 it spits out '24'

## SECOND LEFT JOIN
# ((instances LEFT JOIN machine-types) LEFT JOIN disks ) 
# again we could end up having some instances with 0 disks, rather than implementing INNER JOIN, we do LEFT JOIN and NOT NULL 
# |  jq 'select(.sizeGb!=null)' # .sizeGb is an attribute from disks
 
cat "$DATA_MERGED_FILE" \
 | jq '[[[.instances, .machinetypes] | left_joins(.machineTypeId)  | add | . + {computedcpu: (if(.cpu==null) then (.machineTypeId|split("-"))[-2]|tonumber else .cpu end)}], .disks] | left_joins(.instanceId) | add |  {vcpu: .computedcpu, instanceSelfLink: .instanceId, diskSelfLink: .diskId, blockSizeBytes: .blockSize, sizeGb: .sizeGb}' \
 |  jq 'select(.sizeGb!=null)' >"$DATA_DENORM_FILE"

echo "$0: denormalizing data finished"

## compute additional attributes
echo "$0: computing additional attributes"

# compute sustained random iops read/write potential based on disk size and number of vCPUs
cat "$DATA_DENORM_FILE" \
 | jq '. | . + {maxsustainedrandomiopsread: (if (.sizeGb | tonumber *30)>60000 then 60000 else (.sizeGb | tonumber *30) end), maxsustainedrandomiopswrite: (if (.sizeGb | tonumber *30)>30000 then 30000 else (.sizeGb | tonumber *30) end),  cpusustainedrandomiopsread: (if (.vcpu|tonumber)<16 then 15000 elif (.vcpu|tonumber)<32 then 25000 else 60000 end ), cpusustainedrandomiopswrite: (if (.vcpu|tonumber)<16 then 15000 elif (.vcpu|tonumber)<32 then 25000 else 30000 end )}'  >"$DATA_COMPUTED_FILE"

echo "$0: computing additional attributes finished"

## REPORT
echo "$0: generating report"
# check if read iops are blocked by cpu
cat "$DATA_COMPUTED_FILE" \
 | jq 'select(.maxsustainedrandomiopsread > .cpusustainedrandomiopsread) | (.diskSelfLink|split("/"))[-1] + " ("+ .sizeGb +"Gb) disk maximum potential read iops are higher than the instances ("+ (.instanceSelfLink|split("/"))[-1] +","+(.vcpu|tostring)+"vCPU) cpu potential (" + (.maxsustainedrandomiopsread|tostring) + ">" + (.cpusustainedrandomiopsread|tostring) + ")"'

# check if write iops are blocked by cpu
cat "$DATA_COMPUTED_FILE" \
 | jq 'select(.maxsustainedrandomiopswrite > .cpusustainedrandomiopswrite) | (.diskSelfLink|split("/"))[-1] + " ("+ .sizeGb +"Gb) disk maximum potential write iops are higher than the instances ("+ (.instanceSelfLink|split("/"))[-1] +","+(.vcpu|tostring)+"vCPU) cpu potential (" + (.maxsustainedrandomiopswrite|tostring) + ">" + (.cpusustainedrandomiopswrite|tostring) + ")"'

# check if disk size is the read iops bottleneck
cat "$DATA_COMPUTED_FILE" \
 | jq 'select(.maxsustainedrandomiopsread < .cpusustainedrandomiopsread) | (.diskSelfLink|split("/"))[-1] + " ("+ .sizeGb +"Gb) disk maximum potential read iops are lower than the instances ("+ (.instanceSelfLink|split("/"))[-1] +","+(.vcpu|tostring)+"vCPU) cpu potential (" + (.maxsustainedrandomiopsread|tostring) + "<" + (.cpusustainedrandomiopsread|tostring) + ")"'

# check if disk size is the write iops bottleneck
cat "$DATA_COMPUTED_FILE" \
 | jq 'select(.maxsustainedrandomiopswrite < .cpusustainedrandomiopswrite) | (.diskSelfLink|split("/"))[-1] + " ("+ .sizeGb +"Gb) disk maximum potential write iops are lower than the instances ("+ (.instanceSelfLink|split("/"))[-1] +","+(.vcpu|tostring)+"vCPU) cpu potential (" + (.maxsustainedrandomiopswrite|tostring) + "<" + (.cpusustainedrandomiopswrite|tostring) + ")"'

echo "$0: generating report finished"

echo "$0: all done, exiting now"

