# Runbook: Instance Down

## Alert Details
- **Alert Name:** InstanceDown
- **Severity:** Critical
- **Threshold:** Instance unreachable for 1 minute

## What This Means
Prometheus cannot reach a monitored target. This could mean
the instance crashed, the service stopped, or there is a
network connectivity issue.

## Immediate Actions

### Step 1 — Verify the instance is actually down
Check AWS Console:
- EC2 → Instances → verify instance state
- Check system status checks and instance status checks

### Step 2 — Check via AWS CLI
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=unified-observability" \
  --query "Reservations[].Instances[].[InstanceId,State.Name]" \
  --output table \
  --region ap-south-2
```

### Step 3 — Check Prometheus targets
- Open Prometheus UI → Status → Targets
- Identify which target is DOWN
- Note the error message shown

### Step 4 — Resolution options

**If instance is running but service is down:**
```bash
aws ssm start-session --target <instance-id> --region ap-south-2
systemctl status node_exporter
systemctl restart node_exporter
```

**If instance is stopped:**
```bash
aws ec2 start-instances \
  --instance-ids <instance-id> \
  --region ap-south-2
```

**If instance is terminated:**
- Run terraform apply to recreate it
```bash
cd terraform/environments/monitoring
terraform apply
```

## Escalation
Instance down is a Critical alert — escalate immediately if
not resolved within 5 minutes.

## Post-Incident
- Check CloudWatch logs for instance termination reason
- Review auto-recovery settings
- Consider enabling EC2 auto-recovery in Terraform