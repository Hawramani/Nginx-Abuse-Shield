```text:disable-run
# Nginx Abuse Shield

**Surgical Traffic Control & Heuristic Rate Limiting for High-Traffic Servers.**

> **Automated, Log-Driven, and Performance-Optimized.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Ubuntu-orange)](https://www.linux.org/)
[![Nginx](https://img.shields.io/badge/Nginx-High%20Performance-green)](https://nginx.org/)

Rate-limits individual IPs along with abusive crawlers/scrapers using multiple ips using intelligent range detection.

**Nginx Abuse Shield** is a robust, lightweight security suite designed to protect Ubuntu/Linux web servers from aggressive crawlers, scrapers, and DoS attacks. Unlike standard rate limiting which applies static rules, Abuse Shield uses **statistical analysis** of your access logs to detect patterns of abuse, automatically escalating restrictions from single IPs to `/24` subnets or even `/16` ranges when necessary.

**⚠️⚠️ Important: Add your server's IP, your personal IP, and any other relevant IPs to the ignore list. See the section *Ignore List* below.**

---

## 🚀 Key Features

* **🧠 Heuristic Range Detection:** Intelligent logic that analyzes traffic density across subnets. If a botnet rotates IPs within a range, Abuse Shield detects the concentration and throttles the whole block automatically.
* **⚙️ Modular Configuration:** Fully configurable via a persistent configuration file (`abuse_shield.conf`). No need to edit scripts directly to change thresholds or log paths.
* **⚡ Blazing Fast Analysis:** Powered by optimized `awk` scripts, it parses millions of log lines in seconds with negligible CPU overhead.
* **🛡 "Soft" Banning Strategy:** Integrates with Nginx's native `limit_req` module to serve `429 Too Many Requests`. This allows legitimate users to recover gracefully if they cross a threshold.
* **🔁 Rotation Aware:** Seamless integration with standard log rotation (`access.log` + `access.log.1`), ensuring no attack goes unnoticed during midnight rollovers.
* **🤖 Set & Forget:** Installs a self-healing cron job that constantly monitors your traffic. Supports seamless updates via the installer.

---

## 📦 Installation

We provide a smart **modular installer** (`install.sh`) that installs the system, updates existing scripts without breaking configuration, and sets up cron jobs.

### 1. Clone the repository
```bash
git clone [https://github.com/yourusername/nginx-abuse-shield.git](https://github.com/yourusername/nginx-abuse-shield.git)
cd nginx-abuse-shield

```

### 2. (Optional) Pre-configure

If you wish to configure the system before installing (e.g., for automated deployments), edit the `abuse_shield.conf` file in the directory. The installer will detect it and use it as the template.

```bash
nano abuse_shield.conf

```

### 3. Run the Installer

```bash
sudo ./install.sh

```

*If you encounter a "required file not found" error, ensure the scripts have Unix line endings:*

```bash
sed -i 's/\r$//' *.sh *.conf
sudo ./install.sh

```

---

## ⚙ Configuration

The system relies on a central configuration file located at:

`/etc/nginx/abuse_shield/abuse_shield.conf`

You can edit this file at any time to adjust sensitivity or paths.

| Variable | Description | Default |
| --- | --- | --- |
| `LOG_FILES` | Space-separated list of log files to analyze. | `/var/log/nginx/concise.log ...` |
| `TIME_WINDOW` | How far back to analyze (in seconds). | `3000` (50 mins) |
| `IP_PARTS` | Depth of IP analysis (2 = /16, 3 = /24). | `2` |
| `THRESH_*` | Advanced tuning parameters for sensitivity logic. | See file for formulas. |

### Required Log Format

For maximum parsing speed, this tool requires a `concise` log format starting with a timestamp (`$msec`). Add this to your `nginx.conf`:

```nginx
log_format concise '$msec $remote_addr $is_bot $host $status';

```

*(Ensure your `access_log` directive uses this format)*

---

## 🔌 Nginx Integration

The installer generates config files in `/etc/nginx/abuse_shield/`. You simply include them:

**1. In your `http` block:**

```nginx
include /etc/nginx/abuse_shield/rate_limit_logic.conf;

```

**2. In your `server` or `location` block:**

```nginx
location / {
    limit_req zone=heavily_limited_ip_rate_limit burst=2 nodelay;
    # ... application logic ...
}

# Custom Error Page
location @ratelimit {
    return 429 "Too Many Requests: Rate limit exceeded.\n";
}

```

---

## 📊 How It Works

1. **Snapshot:** Every 15 minutes (configurable in Cron), the system analyzes recent access logs defined in `abuse_shield.conf`.
2. **Statistical Baseline:** It calculates the median request count to identify statistical outliers vs. normal traffic.
3. **Escalation Logic:**
* **Level 1:** High traffic from one IP → **IP Throttle**.
* **Level 2:** High traffic from multiple IPs in a `/24` → **Subnet Throttle**.
* **Level 3:** Widespread abuse across a `/16` → **Range Throttle**.


4. **Enforcement:** Updates an Nginx map file and reloads the service only when new rules are added.

---

## 🦧 Ignore List

To whitelist specific IPs (such as your own IP or the server's IP), edit the `range_checker.sh` file.

**Location:** `/usr/local/bin/nginx-abuse-shield/range_checker.sh`

Update the `skip_ranges` array at the top of the file:

```bash
# Known good ranges to completely ignore (Google, Bing, legitimate crawlers, etc.)
skip_ranges=(
    "52.167" "57.141" "66.249" "85.208" "102.8" "103.197"
    "127.0" "192.168.1" # Add your IPs here
    # add more if needed
)

```

---

## 🤡 Rate-Limiting Abusers Using Unrelated IPs / Alias IPs

Update `offending_ips.conf` and assign an identical trailing identifier to all of the IPs (instead of the default underscore-separated IP range values). Below, we're treating these two IPs as if they're one IP:

```nginx
~^85\.208\.    "heavily_limited_range_semrush";
~^185\.191\.    "heavily_limited_range_semrush";
```

In this way `semrush` enjoys one window for hammering the server, instead of two.

## 📝 License

Copyright © 2025 **Ikram Hawramani** [Hawramani.com](https://hawramani.com/).

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

```

```
