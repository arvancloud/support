#!/bin/bash
SC_VERSION="v2023-05-24"

run_code() {
clear  
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#          ArvanCloud Network Bench Script           #'
echo -e '#                                                    #'
echo -e '#     Please share anything you see with support.    #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e
date
TIME_START=$(date '+%Y%m%d-%H%M%S')
AR_START_TIME=$(date +%s)
SERVERS="https://iperf3.s3.ir-thr-at1.arvanstorage.ir/server.json"

response=$(curl -s "$SERVERS")

# Check which Linux distribution is installed
if command -v lsb_release &> /dev/null; then
    # Ubuntu, Debian, or other Debian-based distribution
    if lsb_release -si | grep -qi "ubuntu\|debian"; then
        PACKAGE_MANAGER="apt-get"
    fi
elif command -v rpm &> /dev/null; then
    # Red Hat-based distribution
    if rpm -q redhat-release &> /dev/null; then
        if grep -qi "CentOS" /etc/redhat-release; then
            PACKAGE_MANAGER="yum"
        else
            PACKAGE_MANAGER="dnf"
        fi
    # SUSE-based distribution
    elif rpm -q sles-release &> /dev/null || rpm -q opensuse-release &> /dev/null; then
        PACKAGE_MANAGER="zypper"
    fi
elif command -v pacman &> /dev/null; then
    # Arch-based distribution
    if grep -qi "arch" /etc/os-release; then
        PACKAGE_MANAGER="pacman"
    fi
fi

if ! command -v mtr &> /dev/null || ! command -v jq &> /dev/null; then
    echo "installing prerequisites..."
    # Install mtr and jq using the appropriate package manager
    if [ "$PACKAGE_MANAGER" = "apt-get" ]; then
        sudo apt-get -qq update && sudo apt-get -qq install -y mtr jq &> /dev/null
    elif [ "$PACKAGE_MANAGER" = "dnf" ]; then
        sudo dnf -q -y install mtr jq &> /dev/null
    elif [ "$PACKAGE_MANAGER" = "yum" ]; then
        sudo yum -q -y install mtr jq &> /dev/null
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        sudo pacman -S --noconfirm mtr jq &> /dev/null
    elif [ "$PACKAGE_MANAGER" = "zypper" ]; then
        sudo zypper -n install mtr jq &> /dev/null
    else
        echo "Unknown error installing prerequisites..."
        exit 1
    fi
fi

IPERF_LOCS=()
IPERF_LOCS_COUNT=$(echo $response | jq length)

while IFS= read -r server_details ; do
	location=$(echo $server_details | jq -r ".location")
	method=$(echo $server_details | jq -r ".method")
	port=$(echo $server_details | jq -r ".port")
	provider=$(echo $server_details | jq -r ".provider")
	server=$(echo $server_details | jq -r ".server")
	IPERF_LOCS+=("$server" "$port" "$provider" "$location" "$method")
done <<< "$(echo $response | jq -c ".[]")"
# override locale to eliminate parsing errors (i.e. using commas as delimiters rather than periods)
if locale -a 2>/dev/null | grep ^C$ > /dev/null; then
    # locale "C" installed
    export LC_ALL=C
else
    # locale "C" not installed, display warning
    echo -e "\nWarning: locale 'C' not detected. Test outputs may not be parsed correctly."
fi
# determine architecture of host
ARCH=$(uname -m)
if [[ $ARCH = *x86_64* ]]; then
    # host is running a 64-bit kernel
    ARCH="x64"
elif [[ $ARCH = *i?86* ]]; then
    # host is running a 32-bit kernel
    ARCH="x86"
elif [[ $ARCH = *aarch* || $ARCH = *arm* ]]; then
    KERNEL_BIT=$(getconf LONG_BIT)
    if [[ $KERNEL_BIT = *64* ]]; then
        # host is running an ARM 64-bit kernel
        ARCH="aarch64"
    else
        # host is running an ARM 32-bit kernel
        ARCH="arm"
    fi
    echo -e "\nARM compatibility is considered *experimental*"
else
    # host is running a non-supported kernel
    echo -e "Architecture not supported by Script."
    exit 1
fi
# check for local fio/iperf installs
command -v fio >/dev/null 2>&1 && LOCAL_FIO=true || unset LOCAL_FIO
command -v iperf3 >/dev/null 2>&1 && LOCAL_IPERF=true || unset LOCAL_IPERF
# check for ping
command -v ping >/dev/null 2>&1 && LOCAL_PING=true || unset LOCAL_PING
# check for curl/wget
command -v curl >/dev/null 2>&1 && LOCAL_CURL=true || unset LOCAL_CURL
# test if the host has IPv4/IPv6 connectivity
[[ ! -z $LOCAL_CURL ]] && IP_CHECK_CMD="curl -s -m 4" || IP_CHECK_CMD="wget -qO- -T 4"
IPV4_CHECK=$((ping -4 -c 1 -W 4 ipv4.google.com >/dev/null 2>&1 && echo true) || $IP_CHECK_CMD -4 icanhazip.com 2> /dev/null)
IPV6_CHECK=$((ping -6 -c 1 -W 4 ipv6.google.com >/dev/null 2>&1 && echo true) || $IP_CHECK_CMD -6 icanhazip.com 2> /dev/null)
if [[ -z "$IPV4_CHECK" ]]; then
    echo -e
    echo -e "Warning: Both IPv4 AND IPv6 connectivity were not detected. Check for DNS issues..."
fi
# format_size
# Purpose: Formats raw disk and memory sizes from kibibytes (KiB) to largest unit
# Parameters:
#          1. RAW - the raw memory size (RAM/Swap) in kibibytes
# Returns:
#          Formatted memory size in KiB, MiB, GiB, or TiB
function format_size {
    RAW=$1 # mem size in KiB
    RESULT=$RAW
    local DENOM=1
    local UNIT="KiB"
    # ensure the raw value is a number, otherwise return blank
    re='^[0-9]+$'
    if ! [[ $RAW =~ $re ]] ; then
        echo "" 
        return 0
    fi
    if [ "$RAW" -ge 1073741824 ]; then
        DENOM=1073741824
        UNIT="TiB"
    elif [ "$RAW" -ge 1048576 ]; then
        DENOM=1048576
        UNIT="GiB"
    elif [ "$RAW" -ge 1024 ]; then
        DENOM=1024
        UNIT="MiB"
    fi
    # divide the raw result to get the corresponding formatted result (based on determined unit)
    RESULT=$(awk -v a="$RESULT" -v b="$DENOM" 'BEGIN { print a / b }')
    # shorten the formatted result to two decimal places (i.e. x.x)
    RESULT=$(echo $RESULT | awk -F. '{ printf "%0.1f",$1"."substr($2,1,2) }')
    # concat formatted result value with units and return result
    RESULT="$RESULT $UNIT"
    echo $RESULT
}
# gather basic system information (inc. CPU, AES-NI/virt status, RAM + swap + disk size)
echo -e 
echo -e "Basic System Information:"
echo -e "---------------------------------"
UPTIME=$(uptime | awk -F'( |,|:)+' '{d=h=m=0; if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes"}')
echo -e "Uptime     : $UPTIME"
if [[ $ARCH = *aarch64* || $ARCH = *arm* ]]; then
    CPU_PROC=$(lscpu | grep "Model name" | sed 's/Model name: *//g')
else
    CPU_PROC=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
fi
echo -e "Processor  : $CPU_PROC"
if [[ $ARCH = *aarch64* || $ARCH = *arm* ]]; then
    CPU_CORES=$(lscpu | grep "^[[:blank:]]*CPU(s):" | sed 's/CPU(s): *//g')
    CPU_FREQ=$(lscpu | grep "CPU max MHz" | sed 's/CPU max MHz: *//g')
    [[ -z "$CPU_FREQ" ]] && CPU_FREQ="???"
    CPU_FREQ="${CPU_FREQ} MHz"
else
    CPU_CORES=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
    CPU_FREQ=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
fi
echo -e "CPU cores  : $CPU_CORES @ $CPU_FREQ"
CPU_AES=$(cat /proc/cpuinfo | grep aes)
[[ -z "$CPU_AES" ]] && CPU_AES="\xE2\x9D\x8C Disabled" || CPU_AES="\xE2\x9C\x94 Enabled"
echo -e "AES-NI     : $CPU_AES"
CPU_VIRT=$(cat /proc/cpuinfo | grep 'vmx\|svm')
[[ -z "$CPU_VIRT" ]] && CPU_VIRT="\xE2\x9D\x8C Disabled" || CPU_VIRT="\xE2\x9C\x94 Enabled"
echo -e "VM-x/AMD-V : $CPU_VIRT"
TOTAL_RAM_RAW=$(free | awk 'NR==2 {print $2}')
TOTAL_RAM=$(format_size $TOTAL_RAM_RAW)
echo -e "RAM        : $TOTAL_RAM"
TOTAL_SWAP_RAW=$(free | grep Swap | awk '{ print $2 }')
TOTAL_SWAP=$(format_size $TOTAL_SWAP_RAW)
echo -e "Swap       : $TOTAL_SWAP"
# total disk size is calculated by adding all partitions of the types listed below (after the -t flags)
TOTAL_DISK_RAW=$(df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs -t swap --total 2>/dev/null | grep total | awk '{ print $2 }')
TOTAL_DISK=$(format_size $TOTAL_DISK_RAW)
echo -e "Disk       : $TOTAL_DISK"
DISTRO=$(grep 'PRETTY_NAME' /etc/os-release | cut -d '"' -f 2 )
echo -e "Distro     : $DISTRO"
KERNEL=$(uname -r)
echo -e "Kernel     : $KERNEL"
VIRT=$(systemd-detect-virt 2>/dev/null)
VIRT=${VIRT^^} || VIRT="UNKNOWN"
echo -e "VM Type    : $VIRT"
if [[ ! -z $IPV4_CHECK && ! -z $IPV6_CHECK ]]; then
    ONLINE="IPv4 & IPv6" 
elif [[ ! -z $IPV4_CHECK ]]; then
    ONLINE="IPv4"
elif [[ ! -z $IPV6_CHECK ]]; then
        ONLINE="IPv6"
fi
echo -e "Net Online : $ONLINE"
# Function to get information from IP Address using ip-api.com free API
function ip_info() {
    # check for curl vs wget
    [[ ! -z $LOCAL_CURL ]] && DL_CMD="curl -s" || DL_CMD="wget -qO-"
    local ip6me_resp="$($DL_CMD http://ip6.me/api/)"
    local net_type="$(echo $ip6me_resp | cut -d, -f1)"
    local net_ip="$(echo $ip6me_resp | cut -d, -f2)"
    local response=$($DL_CMD http://ip-api.com/json/$net_ip)
    # if no response, skip output
    if [[ -z $response ]]; then
        return
    fi
    local country=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^country/ {print $2}' | head -1)
    country=${country//\"}
    local region=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^regionName/ {print $2}')
    region=${region//\"}
    local region_code=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^region/ {print $2}' | head -1)
    region_code=${region_code//\"}
    local city=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^city/ {print $2}')
    city=${city//\"}
    local isp=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^isp/ {print $2}')
    isp=${isp//\"}
    local org=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^org/ {print $2}')
    org=${org//\"}
    local as=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^as/ {print $2}')
    as=${as//\"}
    
    echo
    echo "$net_type Network Information:"
    echo "---------------------------------"
    if [[ -n "$isp" && -n "$as" ]]; then
        echo "IP         : $net_ip"
        echo "ISP        : $isp"
        echo "ASN        : $as"
    fi
    if [[ -n "$org" ]]; then
        echo "Host       : $org"
    fi
    if [[ -n "$city" && -n "$region" ]]; then
        echo "Location   : $city, $region ($region_code)"
    fi
    if [[ -n "$country" ]]; then
        echo "Country    : $country"
    fi 
}
if [ -z $SKIP_NET ]; then
    ip_info
fi
if [ ! -z $JSON ]; then
    UPTIME_S=$(awk '{print $1}' /proc/uptime)
    IPV4=$([ ! -z $IPV4_CHECK ] && echo "true" || echo "false")
    IPV6=$([ ! -z $IPV6_CHECK ] && echo "true" || echo "false")
    AES=$([[ "$CPU_AES" = *Enabled* ]] && echo "true" || echo "false")
    VIRT=$([[ "$CPU_VIRT" = *Enabled* ]] && echo "true" || echo "false")
    JSON_RESULT='{"version":"'$SC_VERSION'","time":"'$TIME_START'","os":{"arch":"'$ARCH'","distro":"'$DISTRO'","kernel":"'$KERNEL'",'
    JSON_RESULT+='"uptime":'$UPTIME_S'},"net":{"ipv4":'$IPV4',"ipv6":'$IPV6'},"cpu":{"model":"'$CPU_PROC'","cores":'$CPU_CORES','
    JSON_RESULT+='"freq":"'$CPU_FREQ'","aes":'$AES',"virt":'$VIRT'},"mem":{"ram":'$TOTAL_RAM_RAW',"swap":'$TOTAL_SWAP_RAW',"disk":'$TOTAL_DISK_RAW'}'
fi

echo -e '* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *'
echo -e '*                     Setup IPERF3                      *'
echo -e '*                 This can take a while                 *'
echo -e '* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *'

# iperf_test
# Purpose: This method is designed to test the network performance of the host by executing an
#          iperf3 test to/from the public iperf server passed to the function. Both directions 
#          (send and receive) are tested.
# Parameters:
#          1. URL - URL/domain name of the iperf server
#          2. PORTS - the range of ports on which the iperf server operates
#          3. HOST - the friendly name of the iperf server host/owner
#          4. FLAGS - any flags that should be passed to the iperf command
function iperf_test {
    URL=$1
    PORTS=$2
    HOST=$3
    FLAGS=$4
    
    # attempt the iperf send test 3 times, allowing for a slot to become available on the
    #   server or to throw out any bad/error results
    I=1
    while [ $I -le 3 ]
    do
        echo -en "Performing $MODE iperf3 send test to $HOST (Attempt #$I of 3)..."
        # select a random iperf port from the range provided
        PORT=$(shuf -i $PORTS -n 1)
        # run the iperf test sending data from the host to the iperf server; includes
        #   a timeout of 15s in case the iperf server is not responding; uses 8 parallel
        #   threads for the network test
        IPERF_RUN_SEND="$(timeout 15 $IPERF_CMD $FLAGS -c $URL -p $PORT -P 8 2> /dev/null)"
        # check if iperf exited cleanly and did not return an error
        if [[ "$IPERF_RUN_SEND" == *"receiver"* && "$IPERF_RUN_SEND" != *"error"* ]]; then
            # test did not result in an error, parse speed result
            SPEED=$(echo "${IPERF_RUN_SEND}" | grep SUM | grep receiver | awk '{ print $6 }')
            # if speed result is blank or bad (0.00), rerun, otherwise set counter to exit loop
            [[ -z $SPEED || "$SPEED" == "0.00" ]] && I=$(( $I + 1 )) || I=11
        else
            # if iperf server is not responding, set counter to exit, otherwise increment, sleep, and rerun
            [[ "$IPERF_RUN_SEND" == *"unable to connect"* ]] && I=11 || I=$(( $I + 1 )) && sleep 2
        fi
        echo -en "\r\033[0K"
    done

    # small sleep necessary to give iperf server a breather to get ready for a new test
    sleep 1

    # attempt the iperf receive test 3 times, allowing for a slot to become available on
    #   the server or to throw out any bad/error results
    J=1
    while [ $J -le 3 ]
    do
        echo -n "Performing $MODE iperf3 recv test from $HOST (Attempt #$J of 3)..."
        # select a random iperf port from the range provided
        PORT=$(shuf -i $PORTS -n 1)
        # run the iperf test receiving data from the iperf server to the host; includes
        #   a timeout of 15s in case the iperf server is not responding; uses 8 parallel
        #   threads for the network test
        IPERF_RUN_RECV="$(timeout 15 $IPERF_CMD $FLAGS -c $URL -p $PORT -P 8 -R 2> /dev/null)"
        # check if iperf exited cleanly and did not return an error
        if [[ "$IPERF_RUN_RECV" == *"receiver"* && "$IPERF_RUN_RECV" != *"error"* ]]; then
            # test did not result in an error, parse speed result
            SPEED=$(echo "${IPERF_RUN_RECV}" | grep SUM | grep receiver | awk '{ print $6 }')
            # if speed result is blank or bad (0.00), rerun, otherwise set counter to exit loop
            [[ -z $SPEED || "$SPEED" == "0.00" ]] && J=$(( $J + 1 )) || J=11
        else
            # if iperf server is not responding, set counter to exit, otherwise increment, sleep, and rerun
            [[ "$IPERF_RUN_RECV" == *"unable to connect"* ]] && J=11 || J=$(( $J + 1 )) && sleep 2
        fi
        echo -en "\r\033[0K"
    done
    
    # Run a latency test via ping -c1 command -> will return "xx.x ms"
    [[ ! -z $LOCAL_PING ]] && LATENCY_RUN="$(ping -c1 $URL 2>/dev/null | grep -o 'time=.*' | sed s/'time='//)" 
    [[ -z $LATENCY_RUN ]] && LATENCY_RUN="--"

    # parse the resulting send and receive speed results
    IPERF_SENDRESULT="$(echo "${IPERF_RUN_SEND}" | grep SUM | grep receiver)"
    IPERF_RECVRESULT="$(echo "${IPERF_RUN_RECV}" | grep SUM | grep receiver)"
    LATENCY_RESULT="$(echo "${LATENCY_RUN}")"
}

# launch_iperf
# Purpose: This method is designed to facilitate the execution of iperf network speed tests to
#          each public iperf server in the iperf server locations array.
# Parameters:
#          1. MODE - indicates the type of iperf tests to run (IPv4 or IPv6)
function launch_iperf {
    MODE=$1
    [[ "$MODE" == *"IPv6"* ]] && IPERF_FLAGS="-6" || IPERF_FLAGS="-4"

    # print iperf3 network speed results as they are completed
    echo -e
    echo -e "iperf3 Network Speed Tests ($MODE):"
    echo -e "---------------------------------"
    printf "%-15s | %-25s | %-15s | %-15s | %-15s\n" "Provider" "Location (Link)" "Send Speed" "Recv Speed" "Ping"
    printf "%-15s | %-25s | %-15s | %-15s | %-15s\n" "-----" "-----" "----" "----" "----"
    
    # loop through iperf locations array to run iperf test using each public iperf server
    for (( i = 0; i < $IPERF_LOCS_COUNT; i++ )); do
        # test if the current iperf location supports the network mode being tested (IPv4/IPv6)
        if [[ "${IPERF_LOCS[i*5+4]}" == *"$MODE"* ]]; then
            # call the iperf_test function passing the required parameters
            iperf_test "${IPERF_LOCS[i*5]}" "${IPERF_LOCS[i*5+1]}" "${IPERF_LOCS[i*5+2]}" "$IPERF_FLAGS"
            # parse the send and receive speed results
            IPERF_SENDRESULT_VAL=$(echo $IPERF_SENDRESULT | awk '{ print $6 }')
            IPERF_SENDRESULT_UNIT=$(echo $IPERF_SENDRESULT | awk '{ print $7 }')
            IPERF_RECVRESULT_VAL=$(echo $IPERF_RECVRESULT | awk '{ print $6 }')
            IPERF_RECVRESULT_UNIT=$(echo $IPERF_RECVRESULT | awk '{ print $7 }')
            LATENCY_VAL=$(echo $LATENCY_RESULT)
            # if the results are blank, then the server is "busy" and being overutilized
            [[ -z $IPERF_SENDRESULT_VAL || "$IPERF_SENDRESULT_VAL" == *"0.00"* ]] && IPERF_SENDRESULT_VAL="busy" && IPERF_SENDRESULT_UNIT=""
            [[ -z $IPERF_RECVRESULT_VAL || "$IPERF_RECVRESULT_VAL" == *"0.00"* ]] && IPERF_RECVRESULT_VAL="busy" && IPERF_RECVRESULT_UNIT=""
            # print the speed results for the iperf location currently being evaluated
            printf "%-15s | %-25s | %-15s | %-15s | %-15s\n" "${IPERF_LOCS[i*5+2]}" "${IPERF_LOCS[i*5+3]}" "$IPERF_SENDRESULT_VAL $IPERF_SENDRESULT_UNIT" "$IPERF_RECVRESULT_VAL $IPERF_RECVRESULT_UNIT" "$LATENCY_VAL"
            if [ ! -z $JSON ]; then
                JSON_RESULT+='{"mode":"'$MODE'","provider":"'${IPERF_LOCS[i*5+2]}'","loc":"'${IPERF_LOCS[i*5+3]}
                JSON_RESULT+='","send":"'$IPERF_SENDRESULT_VAL' '$IPERF_SENDRESULT_UNIT'","recv":"'$IPERF_RECVRESULT_VAL' '$IPERF_RECVRESULT_UNIT'","latency":"'$LATENCY_VAL'"},'
            fi
        fi
    done
}

# if the skip iperf flag was set, skip the network performance test, otherwise test network performance
if [ -z "$SKIP_IPERF" ]; then

    if [[ -z "$PREFER_BIN" && ! -z "$LOCAL_IPERF" ]]; then # local iperf has been detected, use instead of pre-compiled binary
        IPERF_CMD=iperf3
    else
        # create a temp directory to house the required iperf binary and library
        IPERF_PATH=$PWD/iperf
        mkdir -p $IPERF_PATH

        # download iperf3 binary
        if [[ ! -z $LOCAL_CURL ]]; then
            curl -s --connect-timeout 5 --retry 5 --retry-delay 0 https://raw.githubusercontent.com/arvancloud/support/master/bin/iperf/iperf3_$ARCH -o $IPERF_PATH/iperf3
        else
            wget -q -T 5 -t 5 -w 0 https://raw.githubusercontent.com/arvancloud/support/master/bin/iperf/iperf3_$ARCH -O $IPERF_PATH/iperf3
        fi

        if [ ! -f "$IPERF_PATH/iperf3" ]; then # ensure iperf3 binary downloaded successfully
            IPERF_DL_FAIL=True
        else
            chmod +x $IPERF_PATH/iperf3
            IPERF_CMD=$IPERF_PATH/iperf3
        fi
    fi
    # array containing all currently available iperf3 public servers to use for the network test
    # format: "1" "2" "3" "4" "5" \
    #   1. domain name of the iperf server
    #   2. range of ports that the iperf server is running on (lowest-highest)
    #   3. friendly name of the host/owner of the iperf server
    #   4. location and advertised speed link of the iperf server
    #   5. network modes supported by the iperf server (IPv4 = IPv4-only, IPv4|IPv6 = IPv4 + IPv6, etc.)
    # get the total number of iperf locations (total array size divided by 8 since each location has 5 elements)
    IPERF_LOCS_NUM=${#IPERF_LOCS[@]}
    IPERF_LOCS_NUM=$((IPERF_LOCS_NUM / 6))
    if [ -z "$IPERF_DL_FAIL" ]; then
        [[ ! -z $JSON ]] && JSON_RESULT+=',"iperf":['
        # check if the host has IPv4 connectivity, if so, run iperf3 IPv4 tests
        [ ! -z "$IPV4_CHECK" ] && launch_iperf "IPv4"
        # check if the host has IPv6 connectivity, if so, run iperf3 IPv6 tests
        [ ! -z "$IPV6_CHECK" ] && launch_iperf "IPv6"
        [[ ! -z $JSON ]] && JSON_RESULT=${JSON_RESULT::${#JSON_RESULT}-1} && JSON_RESULT+=']'
    else
        echo -e "\niperf3 binary download failed. Skipping iperf network tests..."
    fi
fi

echo -e '* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *'
echo -e '*                          MTR                          *'
echo -e '*                 This can take a while                 *'
echo -e '* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *'


#MTR To 1.1.1.1 & Google.com
echo "MTR report for 1.1.1.1:"
sudo mtr -r -c 10 1.1.1.1
echo "MTR report for Google.com:"
sudo mtr -r -c 10 google.com
}

prompt_confirmation() {

echo "Welcome to the service! This script automates the execution some tests, Included are several tests to check the performance of network using iperf3 and get some MTR to check your server packet lost."
echo "Please read and accept the terms of use:"
echo "----------------------------------------------"
echo "Terms of Use:"
echo "1.Use this script at your own risk as you would with any script publicly available on the net."
echo "2.The following package will be installed on your system by running this script : MTR, JQ, Iperf3 (External Binarie) "
echo "3.This script needs root access to install JQ and MTR packages"
echo "----------------------------------------------"
echo
    read -p "Do you want to run the code? (y/n): " answer

    case $answer in
        [Yy])
            run_code
            ;;
        [Nn])
            echo "Exiting the script."
            exit 0
            ;;
        *)
            echo "Invalid response. Exiting the script."
            exit 1
            ;;
    esac
}
clear
prompt_confirmation
