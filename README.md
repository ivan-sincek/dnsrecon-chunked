# DNSRecon Chunked

Brute force subdomains in multiple smaller iterations. Based on DNSRecon.

Script will split a wordlist into multiple smaller chunks and run each chunk through DNSRecon.

You can easily cancel brute forcing and continue later.

Tested on Kali Linux v2023.1 (64-bit).

Made for educational purposes. I hope it will help!

## How to Run

Open your preferred console from [/src/](https://github.com/ivan-sincek/dnsrecon-chunked/tree/main/src) and run the commands shown below.

Install required packages:

```fundamental
apt-get -y install bc jq dnsrecon
```

Change file permissions:

```fundamental
chmod +x dnsrecon_chunked.sh
```

Run the script:

```fundamental
./dnsrecon_chunked.sh
```

**Use DNSRecon [v1.1.0](https://github.com/darkoperator/dnsrecon/releases/tag/1.1.0) for best results.**

If you want to run DNSRecon as a Python3 script, replace `dnsrecon` with e.g. `python3 /root/Desktop/dnsrecon-0.10.0/dnsrecon.py`.

## Extract Results

The tool will do this for you.

Extract name servers from the results:

```bash
for file in dnsrecon_chunked/*_chunked.json; do jq -r '.[] | if (.type == "NS") then (.target) else (empty) end | select(. != null)' "${file}"; done | sort -u -f | tee -a ns.txt
```

Extract exchange servers from the results:

```bash
for file in dnsrecon_chunked/*_chunked.json; do jq -r '.[] | if (.type == "MX") then (.exchange) else (empty) end | select(. != null)' "${file}"; done | sort -u -f | tee -a mx.txt
```

Extract hosts from the results:

```bash
for file in dnsrecon_chunked/*_chunked.json; do jq -r '.[] | if (.type == "A" or .type == "AAAA" or .type == "CNAME" or .type == "PTR" or .type == "NS" or .type == "MX") then (.name, .target, .exchange) else (empty) end | select(. != null)' "${file}"; done | sort -u -f | tee -a subdomains.txt
```

Extract IPs from the results:

```bash
for file in dnsrecon_chunked/*_chunked.json; do jq -r '.[] | if (.type == "A" or .type == "CNAME" or .type == "PTR" or .type == "NS" or .type == "MX") then (.address) else (empty) end | select(. != null)' "${file}"; done | sort -u -f | tee -a ips.txt
```

Extract canonical names for a subdomain takeover vulnerability from the results:

```bash
for file in dnsrecon_chunked/*_chunked.json; do jq -r '.[] | if (.type == "CNAME") then (.target) else (empty) end | select(. != null)' "${file}"; done | sort -u -f | tee -a cnames.txt
```

P.S. You can find `subdomains-top1mil.txt` wordlist located at `/usr/share/dnsrecon/` directory.

## Usage

```fundamental
DNSRecon Chunked v3.0 ( github.com/ivan-sincek/dnsrecon-chunked )

--- Brute force subdomains ---
Usage:   ./dnsrecon_chunked.sh -d domain      -f file                   [-s size] [-w wildcards       ]
Example: ./dnsrecon_chunked.sh -d example.com -f subdomains-top1mil.txt [-s 2000] [-w wildcard_ips.txt]

--- Continue where you left off ---
Usage:   ./dnsrecon_chunked.sh -c continue
Example: ./dnsrecon_chunked.sh -c yes

DESCRIPTION
     Brute force subdomains in multiple smaller iterations
DOMAIN
    Domain to brute force
    -d <domain> - example.com | etc.
FILE
    File with subdomains to use
    -f <file> - subdomains-top1mil.txt | etc.
SIZE
    Maximum number of lines for each file chunk
    Default: 1000
    -s <size> - 2000 | etc.
WILDCARDS
    File with wildcard IPs to filter out subdomains
    Sometimes DNSRecon fails to filter multiple different wildcard IPs
    -w <wildcards> - wildcard_ips.txt | etc.
CONTINUE
    Continue where you left off
    -c <continue> - yes
```
