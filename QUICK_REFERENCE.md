# 🚀 Quick Reference - Jenkins Job Setup

## ✅ Checklist Rápida

### Pre-requisitos
- [ ] oc CLI instalado en Jenkins
- [ ] ocm CLI instalado en Jenkins
- [ ] jq instalado en Jenkins
- [ ] Repository Git subido

### Credenciales en Jenkins
- [ ] `jenkins-git-credentials` → Username/Password para Git
- [ ] `cluster-kubeconfig` → Secret File con kubeconfig
- [ ] `ocm-token` → Secret Text con token OCM

### Configuración del Job
- [ ] Nombre: `cluster-health-degraded-operators`
- [ ] Tipo: Pipeline
- [ ] Descripción añadida
- [ ] Discard old builds: 30 días / 10 builds
- [ ] Parámetros: CLUSTER_ID, CLUSTER_API_URL, LOOKBACK_DAYS
- [ ] Build trigger: `0 8 */6 * *`
- [ ] Pipeline from SCM: Git
- [ ] Repository URL configurada
- [ ] Credentials seleccionadas
- [ ] Branch: `*/main`
- [ ] Script Path: `Jenkinsfile-degraded-operators-complete`

### Primera ejecución
- [ ] Build with Parameters
- [ ] Rellenar CLUSTER_ID
- [ ] Rellenar CLUSTER_API_URL
- [ ] Verificar Console Output
- [ ] Verificar Service Log enviado

---

## 📝 Valores Rápidos de Copia-Pega

### Credencial IDs
```
jenkins-git-credentials
cluster-kubeconfig
ocm-token
```

### Nombre del Job
```
cluster-health-degraded-operators
```

### Cron Schedule
```
0 8 */6 * *
```
(Cada 6 días a las 8 AM)

### Parámetros

| Name | Default | Description |
|------|---------|-------------|
| CLUSTER_ID | (vacío) | Target cluster UUID (required) |
| CLUSTER_API_URL | (vacío) | Cluster API URL |
| LOOKBACK_DAYS | 6 | Number of days to look back |

### Script Path
```
Jenkinsfile-degraded-operators-complete
```

### Branch Specifier
```
*/main
```

---

## 🧪 Comandos de Testing

### Verificar herramientas en Jenkins
```bash
ssh jenkins@jenkins-server
oc version
ocm version
jq --version
```

### Obtener OCM token
```bash
ocm login
ocm token
```

### Verificar kubeconfig
```bash
export KUBECONFIG=/path/to/kubeconfig
oc whoami
oc get clusterversion
```

### Test manual del script
```bash
cd /path/to/repo
./scripts/check-operators.sh 6
```

### Verificar Service Logs enviados
```bash
ocm get /api/service_logs/v1/cluster_logs \
  --parameter search="cluster_uuid='CLUSTER-ID-HERE'" \
  --parameter size=5
```

---

## 🔥 Troubleshooting Rápido

| Error | Causa | Solución |
|-------|-------|----------|
| `oc: command not found` | oc CLI no instalado | Instalar oc en `/usr/local/bin/` |
| `ocm: command not found` | ocm CLI no instalado | Instalar ocm en `/usr/local/bin/` |
| `You must be logged in` | Kubeconfig inválido | Verificar credencial `cluster-kubeconfig` |
| `CLUSTER_ID required` | Parámetro no pasado | Usar "Build with Parameters" |
| Service Log no enviado | OCM token expirado | Renovar token en credencial `ocm-token` |
| `Permission denied` | Scripts no ejecutables | `chmod +x scripts/*.sh utils/*.sh` |

---

## 📧 Build Status Icons

| Icon | Status | Significado |
|------|--------|-------------|
| ✅ | SUCCESS | No hay operadores degradados |
| ⚠️ | UNSTABLE | Operadores degradados detectados, Service Log enviado |
| ❌ | FAILED | Error en la ejecución del pipeline |

---

## 🔗 URLs Importantes

### Jenkins
```
https://jenkins.example.com
```

### OCM
```
https://console.redhat.com/openshift
```

### Documentación
```
/Users/adriancandelprestel/Desktop/SRE/jenkins/JENKINS_SETUP_GUIDE.md
/Users/adriancandelprestel/Desktop/SRE/jenkins/README.md
```

---

## 📞 Contactos

| Rol | Contacto |
|-----|----------|
| Jenkins Admin | jenkins-admin@example.com |
| SRE Team | sre-team@example.com |
| Escalation | #sre-alerts en Slack |
