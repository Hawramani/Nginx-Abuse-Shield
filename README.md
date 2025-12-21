# Nginx Abuse Shield

**Surgical Traffic Control & Heuristic Rate Limiting for High-Traffic Servers.**

> **Automated, Log-Driven, and Performance-Optimized.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Ubuntu-orange)](https://www.linux.org/)
[![Nginx](https://img.shields.io/badge/Nginx-High%20Performance-green)](https://nginx.org/)

**Nginx Abuse Shield** is a robust, lightweight security suite designed to protect Ubuntu/Linux web servers from aggressive crawlers, scrapers, and DoS attacks. Unlike standard rate limiting which applies static rules, Abuse Shield uses **statistical analysis** of your access logs to detect patterns of abuse, automatically escalating restrictions from single IPs to `/24` subnets or even `/16` ranges when necessary.

---

## 🚀 Key Features

* **🧠 Heuristic Range Detection:** Intelligent logic that analyzes traffic density across subnets. If a botnet rotates IPs within a range, Abuse Shield detects the concentration and throttles the whole block automatically.
* **⚡ Blazing Fast Analysis:** Powered by optimized `awk` scripts, it parses millions of log lines in seconds with negligible CPU overhead.
* **🛡 "Soft" Banning Strategy:** Instead of blocking users with a harsh `403 Forbidden`, it integrates with Nginx's native `limit_req` module to serve `429 Too Many Requests`. This allows legitimate users to recover gracefully if they cross a threshold.
* **🔁 Rotation Aware:** Seamless integration with standard log rotation (`access.log` + `access.log.1`), ensuring no attack goes unnoticed during midnight rollovers.
* **📂 Zero-Dependency:** Built entirely with Bash and standard Linux tools. No heavy databases, Python environments, or Lua scripts required.
* **🤖 Set & Forget:** Installs a self-healing cron job that constantly monitors your traffic.

---

## 📦 Installation

We provide an **interactive installer** (`setup_abuse_shield.sh`) that auto-detects your environment, generates the necessary scripts, and schedules the cron jobs.

1. **Clone the repository:**
    ```bash
    git clone [https://github.com/yourusername/nginx-abuse-shield.git](https://github.com/yourusername/nginx-abuse-shield.git)
    cd nginx-abuse-shield
    chmod +x setup_abuse_shield.sh
    ```

2. **Run the installer:**
    ```bash
    sudo ./setup_abuse_shield.sh
    ```

3. **Follow the prompts:** The script will ask for your log location and preferred time windows, then generate the configuration files.

---

## ⚙ Configuration Guidelines

### 1. Required Log Format
For maximum parsing speed, this tool requires a `concise` log format starting with a timestamp (`$msec`). Add this to your `nginx.conf`:

```nginx
log_format concise '$msec $remote_addr $is_bot $host $status';

```

### 2. Nginx Integration

The installer generates config files in `/etc/nginx/abuse_shield/`. You simply include them:

**In your `http` block:**

```nginx
include /etc/nginx/abuse_shield/rate_limit_logic.conf;

```

**In your `server` or `location` block:**

```nginx
location / {
    limit_req zone=heavily_limited_ip_rate_limit burst=2 nodelay;
    # ... application logic ...
}

# Custom Error Page
error_page 429 @ratelimit;
location @ratelimit {
    return 429 "Too Many Requests: Rate limit exceeded.\n";
}

```

---

## 📊 How It Works

1. **Snapshot:** Every 15 minutes (configurable), the system analyzes recent access logs.
2. **Statistical Baseline:** It calculates the median request count to identify statistical outliers vs. normal traffic.
3. **Escalation Logic:**
* **Level 1:** High traffic from one IP → **IP Throttle**.
* **Level 2:** High traffic from multiple IPs in a `/24` → **Subnet Throttle**.
* **Level 3:** Widespread abuse across a `/16` → **Range Throttle**.


4. **Enforcement:** Updates an Nginx map file and reloads the service only when new rules are added.

---

## 📝 License

Copyright © 2025 **Ikram Hawramani** [Hawramani.com](https://hawramani.com/).

This project is licensed under the [MIT License](https://www.google.com/search?q=LICENSE).

```

```
