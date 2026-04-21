# Runbook: High Memory Usage

## Alert Details
- **Alert Name:** HighMemoryUsage
- **Severity:** Warning
- **Threshold:** Memory usage > 80% for 2 minutes

## What This Means
Available memory on the EC2 instance has dropped below 20%.
This could cause application slowdowns, OOM kills, or instance
becoming unresponsive.

## Immediate Actions

### Step 1 — Check memory usage
Connect via SSM Session Manager:
```bash
aws ssm start-session --target <instance-id> --region ap-south-2
```

Check memory details:
```bash
free -h
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable"
```

### Step 2 — Find memory-hungry processes
```bash
ps aux --sort=-%mem | head -10
```

### Step 3 — Check for memory leaks
```bash
# Check if memory is growing over time
watch -n 5 free -h
```

### Step 4 — Resolution options

**If it's a specific process:**
```bash
systemctl restart <service-name>
```

**If it's a memory leak in demo-app:**
```bash
systemctl restart demo-app
```

**If memory is consistently high:**
- Increase instance type in Terraform
- Add swap space as temporary relief:
```bash
dd if=/dev/zero of=/swapfile bs=128M count=16
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

## Escalation
If memory usage causes OOM kills or instance becomes unresponsive
escalate immediately — this can cause data loss.

## Post-Incident
- Check application logs for memory leak indicators
- Review Grafana memory trend for past 24 hours
- Consider rightsizing the instance