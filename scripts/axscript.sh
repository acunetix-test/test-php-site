#!/bin/bash

# Declare functions
cleanup(){
# delete the scan
Dummy=`curl -sS -k -X DELETE "$MyAXURL/scans/{$MyScanID}" -H "Accept: application/json" -H "X-Auth: $MyAPIKEY"`
# delete the target
Dummy=`curl -sS -k -X DELETE "$MyAXURL/targets/{$MyTargetID}" -H "Accept: application/json" -H "X-Auth: $MyAPIKEY"`
}

# Create our intended target
MyTargetID=`curl -sS -k -X POST $MyAXURL/targets -H "Content-Type: application/json" -H "X-Auth: $MyAPIKEY" --data "{\"address\":\"$MyTargetURL\",\"description\":\"$MyTargetDESC\",\"type\":\"default\",\"criticality\":10}" | grep -Po '"target_id": *\K"[^"]*"' | tr -d '"'`

# Trigger a scan on the target
MyScanID=`curl -i -sS -k -X POST $MyAXURL/scans -H "Content-Type: application/json" -H "X-Auth: $MyAPIKEY" --data "{\"profile_id\":\"$ScanProfileID\",\"incremental\":false,\"schedule\":{\"disable\":false,\"start_date\":null,\"time_sensitive\":false},\"user_authorized_to_scan\":\"yes\",\"target_id\":\"$MyTargetID\"}" | grep "Location: " | sed "s/Location: \/api\/v1\/scans\///" | sed "s/\r//g" | sed -z "s/\n//g"`

while true; do
 MyScanStatus=`curl -sS -k -X GET "$MyAXURL/scans/{$MyScanID}" -H "Accept: application/json" -H "X-Auth: $MyAPIKEY"`
 if [[ "$MyScanStatus" == *"\"status\": \"processing\""* ]]; then
   echo "Scan Status: Processing - waiting 30 seconds"
 elif [[ "$MyScanStatus" == *"\"status\": \"scheduled\""* ]]; then
   echo "Scan Status: Scheduled - waiting 30 seconds"
 elif [[ "$MyScanStatus" == *"\"status\": \"completed\""* ]]; then
   echo "Scan Status: Completed"
   # Break out of loop
   break
 else
   echo "Invalid Scan Status: Aborting"
   # Clean Up and Exit script
   cleanup
   exit 1
 fi
 sleep 30
done

# Obtain the Scan Session ID
MyScanSessionID=`echo "$MyScanStatus" | grep -Po '"scan_session_id": *\K"[^"]*"' | tr -d '"'`

# Obtain the Scan Result ID
MyScanResultID=`curl -sS -k -X GET "$MyAXURL/scans/{$MyScanID}/results" -H "Accept: application/json" -H "X-Auth: $MyAPIKEY" | grep -Po '"result_id": *\K"[^"]*"' | tr -d '"'`

# Obtain Scan Vulnerabilities
MyScanVulnerabilities=`curl -sS -k -X GET "$MyAXURL/scans/{$MyScanID}/results/{$MyScanResultID}/vulnerabilities" -H "Accept: application/json" -H "X-Auth: $MyAPIKEY"`

# Count Vulnerabilities
MyVulnerabilityCount=$(echo $MyScanVulnerabilities | jq '.vulnerabilities | length')

# Exit with error if we find vulnerabilities; exit WITHOUT error if vulnerabilities count is 0
if [ $MyVulnerabilityCount -gt 0 ] ; then exit 1 ; else exit 0 ; fi
