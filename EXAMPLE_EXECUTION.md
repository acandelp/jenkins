# 📺 Ejemplo de Ejecución - Degraded Operators Check

Este documento muestra exactamente qué verás en cada stage del pipeline.

---

## 🎬 Ejecución Completa (Caso: Sin Operadores Degradados)

### Stage 1: Validate Parameters

```
[Pipeline] stage
[Pipeline] { (Validate Parameters)
[Pipeline] script
[Pipeline] {
[Pipeline] echo
✓ Cluster ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
[Pipeline] echo
✓ Lookback Days: 6
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
```

✅ **Qué verificar**: El CLUSTER_ID aparece correctamente

---

### Stage 2: Setup Authentication

```
[Pipeline] stage
[Pipeline] { (Setup Authentication)
[Pipeline] script
[Pipeline] {
[Pipeline] echo
Setting up cluster authentication...
[Pipeline] sh
+ mkdir -p /var/lib/jenkins/workspace/cluster-health-degraded-operators/.kube
[Pipeline] withCredentials
[Pipeline] {
[Pipeline] sh
+ cp **** /var/lib/jenkins/workspace/cluster-health-degraded-operators/.kube/config
[Pipeline] }
[Pipeline] // withCredentials
[Pipeline] withCredentials
[Pipeline] {
[Pipeline] sh
+ ocm login --token=****
Logged in as 'your-user' on 'https://api.openshift.com'
[Pipeline] }
[Pipeline] // withCredentials
[Pipeline] sh
+ oc whoami
system:serviceaccount:openshift-monitoring:prometheus-k8s
[Pipeline] sh
+ oc get clusterversion
NAME      VERSION   AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.14.8    True        False         7d      Cluster version is 4.14.8
[Pipeline] echo
✓ Authentication successful
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
```

✅ **Qué verificar**: 
- `ocm login` exitoso
- `oc whoami` devuelve un usuario
- `oc get clusterversion` muestra la versión del cluster

---

### Stage 3: Checkout

```
[Pipeline] stage
[Pipeline] { (Checkout)
[Pipeline] checkout
Cloning the remote Git repository
Cloning repository https://github.com/your-user/jenkins-health-checks.git
 > git init /var/lib/jenkins/workspace/cluster-health-degraded-operators
 > git fetch --no-tags --progress https://github.com/your-user/jenkins-health-checks.git +refs/heads/*:refs/remotes/origin/*
 > git config remote.origin.url https://github.com/your-user/jenkins-health-checks.git
 > git config core.sparsecheckout
 > git checkout -f origin/main
Commit message: "Add detailed Service Logs for degraded operators"
[Pipeline] }
[Pipeline] // stage
```

✅ **Qué verificar**: 
- Repositorio clonado correctamente
- Branch correcto (`main`)

---

### Stage 4: Setup Scripts

```
[Pipeline] stage
[Pipeline] { (Setup Scripts)
[Pipeline] sh
+ chmod +x scripts/*.sh utils/*.sh
[Pipeline] sh
+ ls -la scripts/ utils/
scripts/:
total 64
-rwxr-xr-x  1 jenkins  jenkins   784 Oct 15 10:12 check-certificates.sh
-rwxr-xr-x  1 jenkins  jenkins   717 Oct 15 10:12 check-operators.sh
...
utils/:
total 8
-rwxr-xr-x  1 jenkins  jenkins   617 Oct 15 10:14 send-service-log.sh
[Pipeline] }
[Pipeline] // stage
```

✅ **Qué verificar**: Scripts tienen permisos de ejecución (`-rwxr-xr-x`)

---

### Stage 5: Check Degraded Operators

#### Caso A: Sin operadores degradados

```
[Pipeline] stage
[Pipeline] { (Check Degraded Operators)
[Pipeline] script
[Pipeline] {
[Pipeline] sh
+ ./scripts/check-operators.sh 6
Checking degraded operators in last 6 days...
[Pipeline] echo
✅ No degraded operators in last 6 days
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
```

✅ **Resultado**: Build marcado como SUCCESS

---

#### Caso B: Con operadores degradados

```
[Pipeline] stage
[Pipeline] { (Check Degraded Operators)
[Pipeline] script
[Pipeline] {
[Pipeline] sh
+ ./scripts/check-operators.sh 6
Checking degraded operators in last 6 days...
[Pipeline] echo
⚠️  Found degraded cluster operators
[Pipeline] echo
Degraded Cluster Operators Detected

SUMMARY:
Found 1 cluster operator(s) in degraded state within the last 6 days.

DEGRADED OPERATORS:

• Operator: authentication
  Degraded Since: 2 day(s) ago
  Status: Degraded
  Reason: OAuthServerDeploymentDegraded: waiting for the OAuth deployment...

IMPACT:
Degraded operators can cause:
- Core cluster functionality impairment
- Failed deployments or builds
...

[Pipeline] sh
+ ./utils/send-service-log.sh 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 'Warning' 'Degraded Cluster Operators (1 affected)' '...'
Sending Service Log to cluster a1b2c3d4-e5f6-7890-abcd-ef1234567890...
Severity: Warning
Summary: Degraded Cluster Operators (1 affected)

{
  "cluster_uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "id": "1a2b3c4d5e6f",
  "severity": "Warning",
  "service_name": "SREManualAction",
  "summary": "Degraded Cluster Operators (1 affected)",
  "timestamp": "2026-10-15T10:35:22.123456Z"
}

✅ Service Log sent successfully!
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
```

⚠️ **Resultado**: Build marcado como UNSTABLE

---

### Post Actions

```
[Pipeline] stage
[Pipeline] { (Declarative: Post Actions)
[Pipeline] script
[Pipeline] {
[Pipeline] echo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Job Summary:
  Cluster: a1b2c3d4-e5f6-7890-abcd-ef1234567890
  Status: UNSTABLE
  Duration: 2 min 34 sec
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Pipeline] }
[Pipeline] // script
[Pipeline] sh
+ rm -f /var/lib/jenkins/workspace/cluster-health-degraded-operators/.kube/config
[Pipeline] echo
⚠️  Degraded operators detected - Service Log sent to customer
[Pipeline] }
[Pipeline] // stage
[Pipeline] End of Pipeline
Finished: UNSTABLE
```

✅ **Qué verificar**: 
- Kubeconfig limpiado (seguridad)
- Status correcto mostrado
- Duración razonable (~2-3 minutos)

---

## 📊 Resultado Final en Jenkins UI

### Build SUCCESS (Sin degradados)

```
┌─────────────────────────────────────────────────────────────┐
│ #3                                    Oct 15, 2026 10:30 AM │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                             │
│ Status: ✅ SUCCESS                                          │
│ Duration: 2 min 18 sec                                      │
│ Description: ✅ No degraded operators                       │
│                                                             │
│ Triggered by: Cron schedule                                 │
│ Cluster: a1b2c3d4-e5f6-7890-abcd-ef1234567890              │
│                                                             │
│ Stages:                                                     │
│   ✅ Validate Parameters       (1 sec)                      │
│   ✅ Setup Authentication      (15 sec)                     │
│   ✅ Checkout                  (45 sec)                     │
│   ✅ Setup Scripts             (2 sec)                      │
│   ✅ Check Degraded Operators  (1 min 15 sec)               │
│                                                             │
│ [Console Output] [Rebuild] [Delete Build]                  │
└─────────────────────────────────────────────────────────────┘
```

---

### Build UNSTABLE (Con degradados)

```
┌─────────────────────────────────────────────────────────────┐
│ #4                                    Oct 21, 2026 8:00 AM  │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                             │
│ Status: ⚠️  UNSTABLE                                        │
│ Duration: 2 min 34 sec                                      │
│ Description: ⚠️ 1 degraded operator(s) found                │
│                                                             │
│ Triggered by: Cron schedule                                 │
│ Cluster: a1b2c3d4-e5f6-7890-abcd-ef1234567890              │
│                                                             │
│ Stages:                                                     │
│   ✅ Validate Parameters       (1 sec)                      │
│   ✅ Setup Authentication      (16 sec)                     │
│   ✅ Checkout                  (43 sec)                     │
│   ✅ Setup Scripts             (2 sec)                      │
│   ⚠️  Check Degraded Operators  (1 min 32 sec)              │
│      └─ Found: authentication (degraded 2 days)            │
│      └─ Service Log sent                                   │
│                                                             │
│ [Console Output] [Rebuild] [Delete Build]                  │
└─────────────────────────────────────────────────────────────┘
```

---

### Build FAILED (Error)

```
┌─────────────────────────────────────────────────────────────┐
│ #2                                    Oct 14, 2026 2:30 PM  │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                             │
│ Status: ❌ FAILED                                           │
│ Duration: 45 sec                                            │
│ Description: ❌ Pipeline failed                             │
│                                                             │
│ Triggered by: user admin                                    │
│ Cluster: a1b2c3d4-e5f6-7890-abcd-ef1234567890              │
│                                                             │
│ Stages:                                                     │
│   ✅ Validate Parameters       (1 sec)                      │
│   ❌ Setup Authentication      (44 sec)                     │
│      └─ Error: You must be logged in to the server         │
│                                                             │
│ [Console Output] [Rebuild] [Delete Build]                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔍 Verificar Service Log Enviado

### Desde CLI

```bash
# Ver último Service Log enviado
ocm get /api/service_logs/v1/cluster_logs \
  --parameter search="cluster_uuid='a1b2c3d4-e5f6-7890-abcd-ef1234567890'" \
  --parameter order_by="timestamp desc" \
  --parameter size=1 | jq '.'
```

**Output esperado**:

```json
{
  "items": [
    {
      "id": "1a2b3c4d5e6f",
      "cluster_uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "severity": "Warning",
      "service_name": "SREManualAction",
      "summary": "Degraded Cluster Operators (1 affected)",
      "description": "Degraded Cluster Operators Detected\n\nSUMMARY:\nFound 1 cluster operator(s)...",
      "timestamp": "2026-10-15T10:35:22.123456Z",
      "username": "ocm-user"
    }
  ],
  "size": 1,
  "total": 1
}
```

---

### Desde OCM Web Console

1. Ir a: https://console.redhat.com/openshift
2. Clusters → Seleccionar tu cluster
3. Support → Service Logs
4. Buscar: "Degraded Cluster Operators"

Verás:

```
┌──────────────────────────────────────────────────────────────┐
│ Service Logs                                                 │
├──────────────────────────────────────────────────────────────┤
│ Oct 15, 2026 10:35 AM    ⚠️  Warning                         │
│ Degraded Cluster Operators (1 affected)                      │
│                                                              │
│ Found 1 cluster operator(s) in degraded state within the     │
│ last 6 days.                                                 │
│                                                              │
│ [View Full Details]                                          │
└──────────────────────────────────────────────────────────────┘
```

---

## 🎯 Siguientes Builds

### Build History tras varias ejecuciones

```
┌─────────────────────────────────────────────────────────────┐
│ Build History                                               │
├─────────────────────────────────────────────────────────────┤
│ #7  Nov 2, 2026 8:00 AM   ✅ Success                        │
│     ✅ No degraded operators                                 │
│     Duration: 2 min 15 sec                                  │
│                                                             │
│ #6  Oct 27, 2026 8:00 AM  ✅ Success                        │
│     ✅ No degraded operators                                 │
│     Duration: 2 min 18 sec                                  │
│                                                             │
│ #5  Oct 21, 2026 8:00 AM  ⚠️  Unstable                      │
│     ⚠️ 2 degraded operator(s) found                          │
│     Duration: 2 min 41 sec                                  │
│                                                             │
│ #4  Oct 15, 2026 8:00 AM  ⚠️  Unstable                      │
│     ⚠️ 1 degraded operator(s) found                          │
│     Duration: 2 min 34 sec                                  │
│                                                             │
│ #3  Oct 14, 2026 3:15 PM  ✅ Success                        │
│     ✅ No degraded operators                                 │
│     Duration: 2 min 22 sec                                  │
│                                                             │
│ #2  Oct 14, 2026 2:30 PM  ❌ Failed                         │
│     ❌ Pipeline failed                                       │
│     Duration: 45 sec                                        │
│                                                             │
│ #1  Oct 14, 2026 2:15 PM  ✅ Success                        │
│     ✅ No degraded operators                                 │
│     Duration: 2 min 19 sec                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 📈 Build Trend

Jenkins mostrará un gráfico:

```
Success Rate: 71% (5/7)

 7 ●━━━━━━━━━━━━━━━━━━━━━━━ ✅
 6 ●━━━━━━━━━━━━━━━━━━━━━━━ ✅
 5 ●━━━━━━━━━━━━━━━━━━━━━━━ ⚠️
 4 ●━━━━━━━━━━━━━━━━━━━━━━━ ⚠️
 3 ●━━━━━━━━━━━━━━━━━━━━━━━ ✅
 2 ●━━━━━━━━━━━━━━━━━━━━━━━ ❌
 1 ●━━━━━━━━━━━━━━━━━━━━━━━ ✅
```

---

## 💡 Tips

### Ver solo stages fallidos
```bash
# En Console Output, busca por:
[Pipeline] // stage (Failed)
```

### Rerun con más debug
Añade al principio del Jenkinsfile:
```groovy
options {
    timestamps()
    ansiColor('xterm')
}
```

### Guardar artifacts (opcional)
Añade al final del pipeline:
```groovy
post {
    always {
        archiveArtifacts artifacts: 'scripts/*.sh', allowEmptyArchive: true
    }
}
```

---

**Última actualización**: 2026-10-15
