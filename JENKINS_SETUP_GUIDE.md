# 📘 Guía Completa: Configurar Job de Jenkins para Degraded Operators

## 📋 Índice
1. [Pre-requisitos](#pre-requisitos)
2. [Configurar Credenciales](#paso-1-configurar-credenciales)
3. [Crear el Job](#paso-2-crear-el-job)
4. [Configurar el Job](#paso-3-configurar-el-job)
5. [Probar el Job](#paso-4-probar-el-job)
6. [Monitorear y Troubleshoot](#paso-5-monitorear)

---

## Pre-requisitos

### En el servidor Jenkins

```bash
# Conectarse al servidor Jenkins
ssh jenkins@jenkins-server.example.com

# Verificar herramientas instaladas
oc version          # OpenShift CLI
ocm version         # OCM CLI
jq --version        # JSON processor
git --version       # Git
```

Si falta algo, instalar:

```bash
# oc CLI
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xvf openshift-client-linux.tar.gz
sudo mv oc /usr/local/bin/
sudo chmod +x /usr/local/bin/oc

# ocm CLI
curl -Lo ocm https://github.com/openshift-online/ocm-cli/releases/latest/download/ocm-linux-amd64
chmod +x ocm
sudo mv ocm /usr/local/bin/

# jq
sudo yum install jq -y  # RHEL/CentOS
```

### Obtener credenciales necesarias

```bash
# 1. OCM Token
ocm login  # Login interactivo
ocm token  # Copiar el token que aparece

# 2. Cluster credentials
# Opción A: Descargar kubeconfig desde OCM
ocm get /api/clusters_mgmt/v1/clusters/<cluster-id>/credentials | jq -r .kubeconfig > kubeconfig

# Opción B: Login y exportar kubeconfig
oc login https://api.cluster.example.com:6443
# El kubeconfig estará en ~/.kube/config
```

---

## Paso 1: Configurar Credenciales

### 1.1 Acceder a Credentials

1. Abre Jenkins: `https://jenkins.example.com`
2. Click en **Manage Jenkins** (izquierda)
3. Click en **Manage Credentials**
4. Click en **System** → **(global)** domain
5. Click en **Add Credentials**

### 1.2 Añadir Credencial de Git (si repo privado)

```
┌─────────────────────────────────────────┐
│ Add Credentials                         │
├─────────────────────────────────────────┤
│ Kind: Username with password         ▼  │
│ Scope: Global (Jenkins, nodes, ...)  ▼  │
│ Username: [tu-usuario-git]              │
│ Password: [********************]        │
│ ID: jenkins-git-credentials             │
│ Description: Git access for health repo │
│                                         │
│ [Create]  [Cancel]                      │
└─────────────────────────────────────────┘
```

**Valores**:
- **Kind**: `Username with password`
- **Scope**: `Global (Jenkins, nodes, items, all child items, etc)`
- **Username**: Tu usuario de Git/GitHub/GitLab
- **Password**: Tu token de acceso personal
- **ID**: `jenkins-git-credentials` ⚠️ **Importante: anota este ID**
- **Description**: `Git credentials for cluster-health repository`

Click **Create**

### 1.3 Añadir Credencial de Cluster (kubeconfig)

Click **Add Credentials** de nuevo:

```
┌─────────────────────────────────────────┐
│ Add Credentials                         │
├─────────────────────────────────────────┤
│ Kind: Secret file                    ▼  │
│ Scope: Global (Jenkins, nodes, ...)  ▼  │
│ File: [Choose File] kubeconfig          │
│ ID: cluster-kubeconfig                  │
│ Description: Kubeconfig for cluster     │
│                                         │
│ [Create]  [Cancel]                      │
└─────────────────────────────────────────┘
```

**Valores**:
- **Kind**: `Secret file`
- **Scope**: `Global`
- **File**: Sube tu archivo `kubeconfig` que descargaste
- **ID**: `cluster-kubeconfig` ⚠️ **Importante: anota este ID**
- **Description**: `Kubeconfig for target OpenShift cluster`

Click **Create**

### 1.4 Añadir Credencial de OCM

Click **Add Credentials** de nuevo:

```
┌─────────────────────────────────────────┐
│ Add Credentials                         │
├─────────────────────────────────────────┤
│ Kind: Secret text                    ▼  │
│ Scope: Global (Jenkins, nodes, ...)  ▼  │
│ Secret: [********************]          │
│ ID: ocm-token                           │
│ Description: OCM authentication token   │
│                                         │
│ [Create]  [Cancel]                      │
└─────────────────────────────────────────┘
```

**Valores**:
- **Kind**: `Secret text`
- **Scope**: `Global`
- **Secret**: Pega el token que obtuviste con `ocm token`
- **ID**: `ocm-token` ⚠️ **Importante: anota este ID**
- **Description**: `OCM authentication token for Service Logs`

Click **Create**

**Resultado**: Deberías ver 3 credenciales:

```
┌────────────────────────────────────────────────────────────────┐
│ ID                          │ Description                      │
├────────────────────────────────────────────────────────────────┤
│ jenkins-git-credentials     │ Git access for health repo       │
│ cluster-kubeconfig          │ Kubeconfig for cluster           │
│ ocm-token                   │ OCM authentication token         │
└────────────────────────────────────────────────────────────────┘
```

---

## Paso 2: Crear el Job

### 2.1 Crear Nuevo Item

1. Vuelve al Dashboard de Jenkins
2. Click **New Item** (arriba izquierda)

```
┌─────────────────────────────────────────────────┐
│ Enter an item name                              │
│ ┌─────────────────────────────────────────────┐ │
│ │ cluster-health-degraded-operators           │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ ○ Freestyle project                             │
│ ● Pipeline                                      │
│ ○ Multi-configuration project                   │
│ ○ Folder                                        │
│ ○ Multibranch Pipeline                          │
│                                                 │
│ [OK]  [Cancel]                                  │
└─────────────────────────────────────────────────┘
```

**Valores**:
- **Item name**: `cluster-health-degraded-operators`
- Selecciona: **Pipeline**

Click **OK**

---

## Paso 3: Configurar el Job

Ahora estás en la página de configuración del job. Vamos sección por sección:

### 3.1 General Section

```
┌─────────────────────────────────────────────────────────────┐
│ ☐ Discard old builds                                        │
│ ☐ This project is parameterized                             │
│ ☐ Throttle builds                                           │
│ ☐ Disable this project                                      │
│ ☐ Execute concurrent builds if necessary                    │
└─────────────────────────────────────────────────────────────┘
```

**Description**:
```
Proactive monitoring job that checks for degraded cluster operators 
and sends detailed Service Logs to customers.

Schedule: Runs every 6 days
Lookback: Last 6 days of operator status
Severity: Warning
```

✅ **Marca**: `☑ Discard old builds`
   - **Strategy**: Log Rotation
   - **Days to keep builds**: `30`
   - **Max # of builds to keep**: `10`

✅ **Marca**: `☑ This project is parameterized`

Click **Add Parameter** → **String Parameter**

#### Parámetro 1: CLUSTER_ID
```
Name: CLUSTER_ID
Default Value: [dejar vacío]
Description: Target cluster UUID (required)
Example: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

#### Parámetro 2: CLUSTER_API_URL
```
Name: CLUSTER_API_URL
Default Value: [dejar vacío o poner URL de prueba]
Description: Cluster API URL
Example: https://api.mycluster.example.com:6443
```

#### Parámetro 3: LOOKBACK_DAYS
```
Name: LOOKBACK_DAYS
Default Value: 6
Description: Number of days to look back for degraded operators
```

Tu configuración debería verse así:
```
┌─────────────────────────────────────────────────────────────┐
│ ☑ This project is parameterized                             │
│   String Parameter                                          │
│     Name: CLUSTER_ID                                        │
│     Default Value:                                          │
│     Description: Target cluster UUID (required)             │
│                                                             │
│   String Parameter                                          │
│     Name: CLUSTER_API_URL                                   │
│     Default Value:                                          │
│     Description: Cluster API URL                            │
│                                                             │
│   String Parameter                                          │
│     Name: LOOKBACK_DAYS                                     │
│     Default Value: 6                                        │
│     Description: Number of days to look back                │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Build Triggers Section

```
┌─────────────────────────────────────────────────────────────┐
│ Build Triggers                                              │
├─────────────────────────────────────────────────────────────┤
│ ☐ Trigger builds remotely                                   │
│ ☐ Build after other projects are built                      │
│ ☑ Build periodically                                        │
│ ☐ GitHub hook trigger                                       │
│ ☐ Poll SCM                                                  │
└─────────────────────────────────────────────────────────────┘
```

✅ **Marca**: `☑ Build periodically`

**Schedule** (sintaxis cron):
```
0 8 */6 * *
```

Esto significa: **Cada 6 días a las 8:00 AM**

Jenkins te mostrará:
```
This project is currently configured to run periodically.
Last run: N/A
Next run: Oct 21, 2026 8:00 AM
```

**Otros ejemplos de Schedule**:
```
0 8 */3 * *          # Cada 3 días a las 8 AM
0 8 1,7,14,21,28 * * # Días específicos del mes
0 20 * * 5           # Cada viernes a las 8 PM
H 8 * * 1            # Cada lunes (H = hash para distribuir carga)
```

### 3.3 Pipeline Section

```
┌─────────────────────────────────────────────────────────────┐
│ Pipeline                                                    │
├─────────────────────────────────────────────────────────────┤
│ Definition: Pipeline script from SCM                     ▼  │
│                                                             │
│ SCM: Git                                                 ▼  │
│                                                             │
│ Repositories                                                │
│   Repository URL: [________________]                        │
│   Credentials: [Select credentials]                      ▼  │
│                                                             │
│ Branches to build                                           │
│   Branch Specifier: */main                                  │
│                                                             │
│ Script Path: Jenkinsfile-degraded-operators-complete       │
│                                                             │
│ ☐ Lightweight checkout                                      │
└─────────────────────────────────────────────────────────────┘
```

**Valores**:

**Definition**: Selecciona `Pipeline script from SCM`

**SCM**: Selecciona `Git`

**Repository URL**:
```
https://github.com/tu-usuario/jenkins-health-checks.git
```
O la URL de tu repositorio Git

**Credentials**: 
- Selecciona `jenkins-git-credentials` (si es repo privado)
- Selecciona `- none -` (si es repo público)

**Branches to build**:
```
Branch Specifier (blank for 'any'): */main
```
(O `*/master` si usas master)

Click **Add** en **Additional Behaviours** y selecciona:
- ✅ **Clean before checkout**
  - ☑ Delete untracked nested repositories
- ✅ **Shallow clone** (opcional, para repos grandes)
  - Enable shallow clone: ☑
  - Depth: `1`

**Script Path**:
```
Jenkinsfile-degraded-operators-complete
```
⚠️ **Importante**: Este es el nombre del archivo Jenkinsfile en tu repo

**Lightweight checkout**: ☐ Desmarcado

---

## Paso 4: Probar el Job

### 4.1 Guardar Configuración

Scroll hasta abajo y click **Save**

### 4.2 Build Manual (Primera Prueba)

1. En la página del job, click **Build with Parameters** (izquierda)

```
┌─────────────────────────────────────────────────────────────┐
│ Build with Parameters                                       │
├─────────────────────────────────────────────────────────────┤
│ CLUSTER_ID                                                  │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ a1b2c3d4-e5f6-7890-abcd-ef1234567890                    │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ CLUSTER_API_URL                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ https://api.cluster.example.com:6443                    │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ LOOKBACK_DAYS                                               │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 6                                                       │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ [Build]  [Cancel]                                           │
└─────────────────────────────────────────────────────────────┘
```

2. Rellena los parámetros:
   - **CLUSTER_ID**: UUID de tu cluster de prueba
   - **CLUSTER_API_URL**: API URL del cluster
   - **LOOKBACK_DAYS**: `6` (o el valor que quieras)

3. Click **Build**

### 4.3 Monitorear la Ejecución

El build aparecerá en **Build History**:

```
┌─────────────────────────────────────────────┐
│ Build History                               │
├─────────────────────────────────────────────┤
│ #1  Oct 15, 2026 10:30 AM                   │
│     ● In Progress                           │
│     [Console Output] [Delete]               │
└─────────────────────────────────────────────┘
```

Click en **Console Output** para ver logs en tiempo real:

```
Started by user Admin
Running in Durability level: MAX_SURVIVABILITY
[Pipeline] Start of Pipeline
[Pipeline] node
Running on Jenkins in /var/lib/jenkins/workspace/cluster-health-degraded-operators
[Pipeline] {
[Pipeline] stage
[Pipeline] { (Validate Parameters)
[Pipeline] script
[Pipeline] {
[Pipeline] echo
✓ Cluster ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
[Pipeline] echo
✓ Lookback Days: 6
...
```

### 4.4 Verificar Resultado

Si todo va bien, verás:

```
[Pipeline] echo
✅ No degraded operators in last 6 days
[Pipeline] echo
✅ Degraded operator check completed successfully
[Pipeline] }
[Pipeline] // stage
[Pipeline] End of Pipeline
Finished: SUCCESS
```

O si encuentra operadores degradados:

```
[Pipeline] echo
⚠️  Found degraded cluster operators
[Pipeline] echo
Degraded Cluster Operators Detected

SUMMARY:
Found 1 cluster operator(s) in degraded state...
...
[Pipeline] sh
+ ./utils/send-service-log.sh ...
Sending Service Log to cluster a1b2c3d4...
✅ Service Log sent successfully!
[Pipeline] }
[Pipeline] // stage
[Pipeline] End of Pipeline
Finished: UNSTABLE
```

---

## Paso 5: Monitorear

### 5.1 Ver Historial de Builds

En la página del job:

```
┌──────────────────────────────────────────────────────────┐
│ Build History                                            │
├──────────────────────────────────────────────────────────┤
│ #5  Oct 27, 2026 8:00 AM  ✅ Success                     │
│ #4  Oct 21, 2026 8:00 AM  ⚠️  Unstable (1 degraded)      │
│ #3  Oct 15, 2026 8:00 AM  ✅ Success                     │
│ #2  Oct 14, 2026 2:30 PM  ❌ Failed (auth error)         │
│ #1  Oct 14, 2026 2:15 PM  ✅ Success                     │
└──────────────────────────────────────────────────────────┘
```

### 5.2 Verificar Service Logs Enviados

Desde CLI:

```bash
# Listar Service Logs enviados a un cluster
ocm get /api/service_logs/v1/cluster_logs \
  --parameter search="cluster_uuid='a1b2c3d4-e5f6-7890-abcd-ef1234567890'" \
  --parameter size=10 | jq '.items[] | {summary: .summary, severity: .severity, timestamp: .timestamp}'
```

### 5.3 Dashboard View (Opcional)

Puedes crear una vista de Dashboard:

1. Jenkins → **+** (New View)
2. Name: `Cluster Health Checks`
3. Type: **List View**
4. Add jobs: Selecciona `cluster-health-degraded-operators`
5. Columns: Status, Weather, Name, Last Success, Last Duration
6. Click **OK**

---

## 🔧 Troubleshooting

### Error: "CLUSTER_ID parameter is required"

**Problema**: Parámetro no proporcionado

**Solución**: 
- Asegúrate de usar **Build with Parameters** (no solo "Build")
- Rellena el campo CLUSTER_ID

### Error: "oc: command not found"

**Problema**: CLI de OpenShift no instalado en Jenkins

**Solución**:
```bash
# En el servidor Jenkins
sudo curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
sudo tar -xvf openshift-client-linux.tar.gz -C /usr/local/bin/
sudo chmod +x /usr/local/bin/oc
```

### Error: "error: You must be logged in to the server"

**Problema**: Autenticación al cluster falló

**Solución**:
1. Verifica que la credencial `cluster-kubeconfig` existe
2. Verifica que el kubeconfig es válido:
   ```bash
   export KUBECONFIG=/path/to/kubeconfig
   oc whoami
   ```
3. Verifica que el ID de credencial en el Jenkinsfile coincide: `cluster-kubeconfig`

### Error: "ocm: command not found"

**Problema**: OCM CLI no instalado

**Solución**:
```bash
# En el servidor Jenkins
curl -Lo ocm https://github.com/openshift-online/ocm-cli/releases/latest/download/ocm-linux-amd64
chmod +x ocm
sudo mv ocm /usr/local/bin/
```

### Error: Service Log no se envía

**Problema**: OCM authentication failed

**Solución**:
1. Verifica el token OCM:
   ```bash
   # Obtener nuevo token
   ocm token
   ```
2. Actualiza la credencial `ocm-token` en Jenkins con el nuevo token

### Build queda en "Pending"

**Problema**: No hay agentes disponibles o están ocupados

**Solución**:
- Verifica que tienes agentes online: **Manage Jenkins** → **Manage Nodes**
- O cambia `agent any` por `agent { label 'linux' }` en el Jenkinsfile

---

## 📊 Próximos Pasos

Una vez que este job funciona correctamente:

1. **Crear jobs para otros checks**:
   - `cluster-health-certificates`
   - `cluster-health-pvc-growth`
   - `cluster-health-quotas`
   - etc.

2. **Agrupar en una vista**:
   - Crea un Dashboard con todos los health checks

3. **Configurar notificaciones**:
   - Añade notificaciones de Slack/Email en caso de fallos

4. **Automatizar para múltiples clusters**:
   - Crear un job parametrizado que itere sobre lista de clusters

---

## 📚 Referencias

- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Jenkins Credentials](https://www.jenkins.io/doc/book/using/using-credentials/)
- [Service Logs API](https://github.com/openshift/ops-sop/blob/master/v4/knowledge_base/service_log.md)

---

**Última actualización**: 2026-10-15  
**Autor**: Red Hat SRE Team
