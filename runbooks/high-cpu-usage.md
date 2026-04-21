# Runbook: High CPU Usage

## Alert Details
- **Alert Name:** HighCPUUsage
- **Severity:** Warning
- **Threshold:** CPU usage > 80% for 2 minutes

## What This Means
The EC2 instance CPU usage has exceeded 80% for more than 2 minutes.
This could indicate a runaway process, traffic spike, or insufficient
instance size.

## Immediate Actions

### Step 1 — Identify the cause
SSH into the instance or use SSM Session Manager:
```bash
aws ssm start-session --target <instance-id> --region ap-south-2
```

Check top processes consuming CPU:
```bash
top -bn1 | head -20
ps aux --sort=-%cpu | head -10
```

### Step 2 — Check system metrics in Grafana
- Open Grafana → EC2 System Metrics dashboard
- Check CPU Usage % panel for trend
- Check if spike is sudden or gradual

### Step 3 — Identify the offending process
```bash
# Find process consuming most CPU
ps aux --sort=-%cpu | head -5

# Check if it's a known service
systemctl status prometheus
systemctl status node_exporter
systemctl status demo-app
```

### Step 4 — Resolution options

**If it's a runaway process:**
```bash
kill -15 <pid>   # graceful stop
kill -9 <pid>    # force stop if graceful fails
```

**If it's legitimate high load:**
- Consider scaling up instance type in Terraform
- Change `instance_type` in `terraform/modules/ec2/variables.tf`
- Run `terraform apply` to resize

**If it's a traffic spike:**
- Monitor if it resolves on its own
- Consider adding auto-scaling

## Escalation
If CPU stays above 80% for more than 15 minutes after investigation
escalate to the infrastructure team.

## Post-Incident
- Document what caused the spike
- Update this runbook if new resolution steps were found
- Consider adding auto-remediation Lambda if pattern repeats