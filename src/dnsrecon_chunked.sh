#!/bin/bash

start=$(date "+%s.%N")

# -------------------------- INFO --------------------------

function basic () {
	proceed=false
	echo "DNSRecon Chunked v3.0 ( github.com/ivan-sincek/dnsrecon-chunked )"
	echo ""
	echo "--- Brute force subdomains ---"
	echo "Usage:   ./dnsrecon_chunked.sh -d domain      -f file                   [-s size] [-w wildcards       ]"
	echo "Example: ./dnsrecon_chunked.sh -d example.com -f subdomains-top1mil.txt [-s 2000] [-w wildcard_ips.txt]"
	echo ""
	echo "--- Continue where you left off ---"
	echo "Usage:   ./dnsrecon_chunked.sh -c continue"
	echo "Example: ./dnsrecon_chunked.sh -c yes"
}

function advanced () {
	basic
	echo ""
	echo "DESCRIPTION"
	echo "     Brute force subdomains in multiple smaller iterations"
	echo "DOMAIN"
	echo "    Domain to brute force"
	echo "    -d <domain> - example.com | etc."
	echo "FILE"
	echo "    File with subdomains to use"
	echo "    -f <file> - subdomains-top1mil.txt | etc."
	echo "SIZE"
	echo "    Maximum number of lines for each file chunk"
	echo "    Default: 1000"
	echo "    -s <size> - 2000 | etc."
	echo "WILDCARDS"
	echo "    File with wildcard IPs to filter out subdomains"
	echo "    Sometimes DNSRecon fails to filter multiple different wildcard IPs"
	echo "    -w <wildcards> - wildcard_ips.txt | etc."
	echo "CONTINUE"
	echo "    Continue where you left off"
	echo "    -c <continue> - yes"
}

# -------------------- VALIDATION BEGIN --------------------

# my own validation algorithm

proceed=true

# $1 (required) - message
function echo_error () {
	echo "ERROR: ${1}" 1>&2
}

# $1 (required) - message
# $2 (required) - help
function error () {
	proceed=false
	echo_error "${1}"
	if [[ $2 == true ]]; then
		echo "Use -h for basic and --help for advanced info" 1>&2
	fi
}

declare -A args=([domain]="" [file]="" [size]="" [wildcards]="" [continue]="")

# $1 (required) - file
function validate_file () {
	if [[ ! -f $1 ]]; then
		error "'${1}' does not exists"
	elif [[ ! -r $1 ]]; then
		error "'${1}' does not have read permission"
	elif [[ ! -s $1 ]]; then
		error "'${1}' is empty"
	fi
}

# $1 (required) - key
# $2 (required) - value
function validate () {
	if [[ ! -z $2 ]]; then
		if [[ $1 == "-d" && -z ${args[domain]} ]]; then
			args[domain]=$2
		elif [[ $1 == "-f" && -z ${args[file]} ]]; then
			args[file]=$2
			validate_file "${args[file]}"
		elif [[ $1 == "-w" && -z ${args[wildcards]} ]]; then
			args[wildcards]=$2
			validate_file "${args[wildcards]}"
		elif [[ $1 == "-s" && -z ${args[size]} ]]; then
			args[size]=$2
			if [[ ! ( ${args[size]} =~ ^[0-9]+$ ) ]]; then
				error "Size must be numeric"
			fi
		elif [[ $1 == "-c" && -z ${args[continue]} ]]; then
			args[continue]=$2
			if [[ ${args[continue]} != "yes" ]]; then
				error "Specify 'yes' to continue where you left off"
			fi
		fi
	fi
}

# $1 (required) - argc
# $2 (required) - args
function check() {
	local argc=$1
	local -n args_ref=$2
	local count=0
	for key in ${!args_ref[@]}; do
		if [[ ! -z ${args_ref[$key]} ]]; then
			count=$((count + 1))
		fi
	done
	echo $((argc - count == argc / 2))
}

if [[ $# == 0 ]]; then
	advanced
elif [[ $# == 1 ]]; then
	if [[ $1 == "-h" ]]; then
		basic
	elif [[ $1 == "--help" ]]; then
		advanced
	else
		error "Incorrect usage" true
	fi
elif [[ $(($# % 2)) -eq 0 && $# -le $((${#args[@]} * 2)) ]]; then
	for key in $(seq 1 2 $#); do
		val=$((key + 1))
		validate "${!key}" "${!val}"
	done
	if [[ ( ! -z ${args[continue]} && ( ! -z ${args[domain]} || ! -z ${args[file]} || ! -z ${args[size]} || ! -z ${args[wildcards]} ) ) || ! ( ( ! -z ${args[domain]} && ! -z ${args[file]} ) || ! -z ${args[continue]} || ! -z ${args[wildcards]} ) || $(check $# args) -eq false ]]; then
		error "Missing a mandatory option (-d, -f) and/or optional (-s, -w)"
		error "Missing a mandatory option (-c)" true
	fi
else
	error "Incorrect usage" true
fi

# --------------------- VALIDATION END ---------------------

# ----------------------- TASK BEGIN -----------------------

# $1 (required) - domain
# $2 (required) - wildcard ips file
# $3 (required) - output
function save_state () {
	if [[ ! -z $2 ]]; then
		echo "{\"domain\": $(echo "${1}" | jq -R), \"wildcards\": $(cat "${2}" | grep -Po '[^\s]+' | jq -R | jq -s .)}" | jq > "${3}"
	else
		echo "{\"domain\": $(echo "${1}" | jq -R), \"wildcards\": []}" | jq > "${3}"
	fi
}

# $1 (required) - file
function check_file () {
	local proceed=true
	if [[ ! -f $1 ]]; then
		proceed=false
		echo_error "'${1}' does not exists"
	elif [[ ! -r $1 ]]; then
		proceed=false
		echo_error "'${1}' does not have read permission"
	elif [[ ! -s $1 ]]; then
		proceed=false
		echo_error "'${1}' is empty"
	fi
	echo $proceed
}

# $1 (required) - file
function get_domain () {
	local domain=$(jq -r '.domain | select(. != null)' "${1}" 2>/dev/nul)
	if [[ -z $domain ]]; then
		echo_error "Domain not found in '${1}'"
	fi
	echo $domain
}

# $1 (required) - placeholder
# $2 (required) - string
# $3 (required) - text
function replace () {
	echo "${3//$1/$2}"
}

# $1 (required) - file
function get_filter () {
	local filter=""
	for ip in $(jq -r '.wildcards[] | select(. != null)' "${1}" 2>/dev/nul); do
		filter="${filter}$(replace '<ip/>' "${ip}" ' and .address != "<ip/>"')"
	done
	echo $filter
}

# $1 (required) - directory
function get_chunks () {
	ls "${1}" | grep -Po '[a-z]{5}_chunk.txt'
}

# $1 (required) - directory
function count_chunks () {
	get_chunks "${1}" | wc -l
}

# $1 (required) - directory
function check_directory () {
	local proceed=true
	if [[ ! -d $1 ]]; then
		proceed=false
		echo_error "Output directory '${1}' does not exists"
	elif [[ -z $(get_chunks "${1}") ]]; then
		proceed=false
		echo_error "Output directory '${1}' does not have any file chunks"
	fi
	echo $proceed
}

# $1 (required) - directory
function create_directory () {
	local created=true
	mkdir -p "${1}"
	if [[ ! -d $1 ]]; then
		created=false
		echo_error "Cannot create '${1}' directory"
	fi
	echo $created
}

# $1 (required) - directory
function remove_directory () {
	local removed=true
	rm -rf "${1}"
	if [[ -d $1 ]]; then
		removed=false
		echo_error "Cannot remove '${1}' directory"
	fi
	echo $removed
}

# $1 (required) - file
# $2 (required) - size
# $3 (required) - output
function split_file () {
	split -a 5 --additional-suffix '_chunk.txt' -l "${2}" "${1}" "${3}"
	local total=$(count_chunks "${3}")
	if [[ $total -lt 1 ]]; then
		echo_error "No file chunks have been created"
	fi
	echo $total
}

# $1 (required) - file in
# $2 (required) - file out
# $3 (required) - regex
function append_file_jq () {
	if [[ -f $1 ]]; then
		jq -r "${3}" "${1}" 2>/dev/nul >> "${2}"
	fi
}

# $1 (required) - results
# $2 (required) - input/output directory
# $3 (required) - wildcard ips filter (can be empty)
function extract_results () {
	append_file_jq "${1}" "${2}ns.txt" "$(replace '<filter/>' "${3}" '.[] | if ((.type == "NS")<filter/>) then (.target) else (empty) end | select(. != null)')"
	append_file_jq "${1}" "${2}mx.txt" "$(replace '<filter/>' "${3}" '.[] | if ((.type == "MX")<filter/>) then (.exchange) else (empty) end | select(. != null)')"
	append_file_jq "${1}" "${2}subdomains.txt" "$(replace '<filter/>' "${3}" '.[] | if ((.type == "A" or .type == "AAAA" or .type == "CNAME" or .type == "PTR" or .type == "NS" or .type == "MX")<filter/>) then (.name, .target, .exchange) else (empty) end | select(. != null)')"
	append_file_jq "${1}" "${2}ips.txt" "$(replace '<filter/>' "${3}" '.[] | if ((.type == "A" or .type == "CNAME" or .type == "PTR" or .type == "NS" or .type == "MX")<filter/>) then (.address) else (empty) end | select(. != null)')"
	append_file_jq "${1}" "${2}canonical_names.txt" "$(replace '<filter/>' "${3}" '.[] | if ((.type == "CNAME")<filter/>) then (.target) else (empty) end | select(. != null)')"
}

function interrupt () {
	echo ""
	echo "[Interrupted]"
}

bf=true

function interrupt_bf () {
	bf=false
	interrupt
}

# $1 (required) - domain
# $2 (required) - input/output directory
# $3 (required) - wildcard ips filter (can be empty)
function brute_force () {
	local total=$(count_chunks "${2}")
	local count=0
	for chunk in $(get_chunks "${2}"); do
		if [[ $bf == false ]]; then
			break
		fi
		count=$((count + 1))
		echo "ITERATION: ${count}/${total}"
		chunk="${2}${chunk}"
		local out="${chunk//\.txt/\.json}"
		# add/edit parameters to your liking
		# python3 /root/Desktop/dnsrecon-0.10.0/dnsrecon.py --iw -f --lifetime 1 --threads 50 -t brt --json "${out}" -D "${chunk}" -d "${1}"
		dnsrecon --iw -f --lifetime 1 --threads 50 -t brt --json "${out}" -D "${chunk}" -d "${1}"
		if [[ -f $out ]]; then
			rm -rf "${chunk}"
			extract_results "${out}" "${2}" "${3}"
		fi
	done
}

if [[ $proceed == true ]]; then
	echo "#################################################################"
	echo "#                                                               #"
	echo "#                     DNSRecon Chunked v3.0                     #"
	echo "#                                 by Ivan Sincek                #"
	echo "#                                                               #"
	echo "# Brute force subdomains in multiple smaller iterations.        #"
	echo "# GitHub repository at github.com/ivan-sincek/dnsrecon-chunked. #"
	echo "#                                                               #"
	echo "#################################################################"
	output="${HOME}/dnsrecon_chunked/"
	continue="${output}dnsrecon_continue.json"
	if [[ ! -z ${args[continue]} ]]; then
		if [[ $(check_directory "${output}") == true && $(check_file "${continue}") == true ]]; then
			args[domain]=$(get_domain "${continue}")
			if [[ ! -z ${args[domain]} ]]; then
				args[wildcards]=$(get_filter "${continue}")
				brute_force "${args[domain]}" "${output}" "${args[wildcards]}"
			fi
		fi
	else
		input="yes"
		if [[ -d $output ]]; then
			echo "Output directory '${output}' already exists"
			read -p "Overwrite the output directory (yes): " input
			echo ""
			if [[ $input == "yes" ]]; then
				proceed=$(remove_directory "${output}")
			fi
		fi
		if [[ $input == "yes" && $proceed == true && $(create_directory "${output}") == true && $(split_file "${args[file]}" "${args[size]:-1000}" "${output}") -gt 0 ]]; then
			save_state "${args[domain]}" "${args[wildcards]}" "${continue}"
			args[wildcards]=$(get_filter "${continue}")
			echo "Results will be saved in '${output}'"
			echo "Continue file will be saved in '${continue}'"
			trap interrupt_bf INT
			brute_force "${args[domain]}" "${output}" "${args[wildcards]}"
			trap INT
		fi
	fi
	end=$(date "+%s.%N")
	runtime=$(echo "${end} - ${start}" | bc -l)
	echo ""
	echo "Script has finished in ${runtime}"
fi

# ------------------------ TASK END ------------------------
