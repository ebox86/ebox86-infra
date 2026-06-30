# ebox86-infra

Infrastructure-as-code for the `lab.ebox86.com` homelab. Covers everything from bare-metal Proxmox provisioning through OKD cluster deployment to GitOps-managed workloads.

## Hardware

| Host | Role | Notes |
|---|---|---|
| pve-01 | Proxmox hypervisor | Runs infra VMs, OKD control plane VM |
| ml350-01 | OKD worker-0 | HPE ML350 Gen10, bare metal |
| ml350-02 | OKD worker-1 | HPE ML350 Gen10, bare metal |
| Aruba 9004 | Gateway / router | Inter-VLAN routing, DHCP |
| Aruba CX 6000 | Access switch | 16-port, VLAN-aware |

**VLANs:** mgmt (10), infra (20), okd (30), trusted (40), iot (50), guest (60), cameras (70)

---

## Repository Layout

```
.
├── core/ansible/          # Ansible — host provisioning and cluster lifecycle
├── k8s/                   # Kubernetes manifests — GitOps via ArgoCD
└── cloudflare/            # Cloudflare DNS/rules via CDKTF (TypeScript)
```

---

## `core/ansible/`

Ansible playbooks numbered by phase. Run from `core/ansible/` with:

```bash
ansible-playbook -i inventory/production/hosts.yml playbooks/<playbook>.yml
```

Secrets are in `secrets/vault.yml` (Ansible Vault — never committed in plaintext).

### Playbooks

| # | File | What it does |
|---|---|---|
| 01 | `01_proxmox_host_baseline.yml` | Baseline config for Proxmox host |
| 02 | `02_proxmox_acme_cloudflare.yml` | Let's Encrypt via Cloudflare DNS-01 on Proxmox |
| 03 | `03_build_golden_template.yml` | Build Debian 13 Trixie cloud-init VM template (VMID 9000) |
| 04 | `04_configure_proxmox_sso.yml` | Proxmox OIDC SSO via Okta |
| 10 | `10_provision_dns01.yml` | Clone dns-01 VM from golden template |
| 11 | `11_deploy_dns_server.yml` | Deploy PowerDNS on dns-01 |
| 12 | `12_configure_dns_records.yml` | PowerDNS zones and records |
| 13 | `13_configure_okd_dns_records.yml` | OKD-specific DNS records in PowerDNS |
| 14 | `14_configure_dns_sso.yml` | Okta OIDC SSO on PowerAdmin |
| 20 | `20_provision_cloudflared01.yml` | Clone cloudflared-01 VM |
| 21 | `21_deploy_cloudflared.yml` | Deploy cloudflared tunnel |
| 22 | `22_configure_cloudflare_rules.yml` | Cloudflare Transform Rules for ebox86.com |
| 30 | `30_provision_okd_infra_vms.yml` | Provision OKD control plane VM on Proxmox |
| 31 | `31_deploy_okd_assisted_installer.yml` | Deploy OKD Assisted Installer |
| 32 | `32_configure_okd_network_and_storage.yml` | OKD network and storage pre-flight |
| 33 | `33_tune_okd_control0_disk.yml` | Disk tuning for control-0 (cache, iothread, scsihw) |
| 40 | `40_bootstrap_okd_cluster.yml` | Post-install OKD bootstrap |
| 50 | `50_configure_okd_storage.yml` | NFS provisioner + default StorageClass |
| 60 | `60_configure_9004_base.yml` | Aruba 9004 gateway base config |
| 61 | `61_configure_switch.yml` | Aruba CX 6000 switch config |
| 62 | `62_configure_ap.yml` | Aruba AP config |
| 63 | `63_configure_proxmox_sdn.yml` | Proxmox SDN — VLAN-aware bridge and VNets |
| 64 | `64_deploy_dhcp_lxc.yml` | Deploy dnsmasq DHCP VM |
| 70 | `70_install_node_exporter.yml` | node_exporter on infra hosts |
| 71 | `71_deploy_okd_monitoring.yml` | Infra monitoring stack in OKD |

### Roles

`cloudflared`, `dns_server`, `node_exporter`, `okd_assisted_installer`, `okd_haproxy`, `okd_nfs_server`, `powerdns_config`, `proxmox_acme_cloudflare`, `proxmox_golden_template`, `proxmox_host_baseline`, `proxmox_vm_clone`

---

## `k8s/`

GitOps-managed workloads via ArgoCD. The **app-of-apps** pattern: one root Application watches `k8s/argocd/apps/` and creates all child apps automatically.

### Bootstrap (one-time, manual)

```bash
# ArgoCD operator is installed via OLM (community-operators, alpha channel)
# Apply the root app once — everything else is automatic from here
oc apply -f k8s/argocd/bootstrap/root-app.yaml
```

ArgoCD UI: `https://argocd-server-openshift-gitops.apps.lab.ebox86.com`

### Adding a new app

Drop a new `Application` manifest in `k8s/argocd/apps/` and push to `main`. ArgoCD picks it up within 3 minutes. For a Helm chart:

```yaml
# k8s/argocd/apps/my-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: openshift-gitops
spec:
  project: lab.ebox86.com
  source:
    repoURL: https://charts.example.com
    chart: my-app
    targetRevision: "1.*"
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Secrets — Bitnami Sealed Secrets

Secrets are managed via [Sealed Secrets](https://github.com/bitnami/sealed-secrets). The controller runs in `kube-system`. To create a secret:

```bash
oc create secret generic my-secret -n my-ns \
  --from-literal=key=value \
  --dry-run=client -o yaml \
| kubeseal --format yaml > k8s/my-ns/my-secret.yaml
# commit the output — it is encrypted and safe to push
```

**Critical:** back up the controller's private key after first install:
```bash
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-master-key.yaml
# store this OFFLINE, not in git
```

### ArgoCD Apps

| App | Chart / Source | Namespace | Notes |
|---|---|---|---|
| `argocd-projects` | `k8s/argocd/projects/` | `openshift-gitops` | Creates `lab.ebox86.com` AppProject (sync-wave -1) |
| `sealed-secrets` | bitnami-labs Helm | `kube-system` | Secret encryption controller |
| `metallb` | metallb Helm | `metallb-system` | LoadBalancer IPs — pool `10.0.1.210-230` (sync-wave -1) |
| `metallb-config` | `k8s/metallb/` | `metallb-system` | IPAddressPool, L2Advertisement, speaker SCC |
| `nfd` | node-feature-discovery Helm | `openshift-nfd` | Hardware feature labelling |
| `nfd-config` | `k8s/nfd/` | `openshift-nfd` | NFD worker privileged SCC |
| `descheduler` | descheduler Helm | `kube-system` | CronJob every 30 min |
| `grafana` | grafana Helm | `monitoring` | Requires `grafana-admin` secret pre-created |

---

## `cloudflare/`

Cloudflare DNS records and firewall/transform rules managed with [CDKTF](https://developer.hashicorp.com/terraform/cdktf) (TypeScript).

```bash
cd cloudflare/cdktn
npx ts-node src/main.ts   # synthesize
cdktf deploy              # apply
```

---

## Network Quick Reference

| VLAN | Subnet | Purpose |
|---|---|---|
| 10 | `10.10.0.0/24` | Management (Proxmox, iLO, switch) |
| 20 | `10.20.0.0/24` | Infrastructure (DNS, NFS, VMs) |
| 30 | `10.0.1.0/24` | OKD cluster |
| 40 | `10.40.0.0/24` | Trusted WiFi |
| 50 | `10.50.0.0/24` | IoT |
| 60 | `10.60.0.0/24` | Guest WiFi |
| 70 | `10.70.0.0/24` | Cameras (isolated) |

OKD API VIP: `10.0.1.200` — MetalLB pool: `10.0.1.210–10.0.1.230`
