# DNSRecon Chunked

Brute force subdomains in multiple smaller iterations. Based on DNSRecon.

Script will split a wordlist into multiple smaller chunks and run each chunk through DNSRecon.

You can easily cancel brute forcing and continue later.

Tested on Kali Linux v2021.2 (64-bit).

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

**Use DNSRecon [v0.10.0](https://github.com/darkoperator/dnsrecon/releases/tag/0.10.0) for best results.**

If you want to run DNSRecon as a Python3 script, replace `dnsrecon` with e.g. `python3 /root/Desktop/dnsrecon-0.10.0/dnsrecon.py`.

## Extract Results

The tool will do this for you.

Extract name servers from the results:

```bash
for file in dnsrecon_chunked/*_chunked.json; do jq -r '.[] | if (.type == "NS") then (.target) else (empty) end | select(. != null)' "${file}"; done | sort -u -f | tee -a subdomains.txt
```

Extract exchange servers from the results:

```bash
for file in dnsrecon_chunked/*_chunked.json; do jq -r '.[] | if (.type == "MX") then (.exchange) else (empty) end | select(. != null)' "${file}"; done | sort -u -f | tee -a subdomains.txt
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
for file in dnsrecon_chunked/*_chunked.json; do jq -r '.[] | if (.type == "CNAME") then (.target) else (empty) end | select(. != null)' "${file}"; done | sort -u -f | tee -a canonical_names.txt
```

P.S. You can find `subdomains-top1mil.txt` wordlist located at `/usr/share/dnsrecon/` directory.

## Images

<p align="center"><img src="https://github.com/ivan-sincek/dnsrecon-chunked/blob/main/img/help.png" alt="Help"></p>

<p align="center">Figure 1 - Help</p>

<p align="center"><img src="https://github.com/ivan-sincek/dnsrecon-chunked/blob/main/img/brute_force.png" alt="Brute Force"></p>

<p align="center">Figure 2 - Brute Force</p>

<p align="center"><img src="https://github.com/ivan-sincek/dnsrecon-chunked/blob/main/img/continue.png" alt="Continue"></p>

<p align="center">Figure 3 - Continue</p>
