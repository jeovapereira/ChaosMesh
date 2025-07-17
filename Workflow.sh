#!/bin/bash

# Configurações
CHAOS_NAMESPACE="chaos-testing"
SCHEDULE_TIME="0 2 * * 3"  # Toda quarta-feira às 02:00
EXPERIMENT_DURATION="10m"   # Duração padrão dos experimentos
TARGET_NAMESPACE="default"  # Namespace alvo dos experimentos

# Verifica se o Chaos Mesh está instalado
function check_chaos_mesh() {
    echo "Verificando a instalação do Chaos Mesh..."
    if ! kubectl get pods -n "${CHAOS_NAMESPACE}" | grep -q chaos-controller-manager; then
        echo "Chaos Mesh não encontrado no namespace ${CHAOS_NAMESPACE}"
        echo "Por favor, instale o Chaos Mesh primeiro: https://chaos-mesh.org/docs/"
        exit 1
    fi
    echo "Chaos Mesh está instalado e funcionando."
}

# Cria o namespace se não existir
function ensure_namespace() {
    if ! kubectl get namespace "${CHAOS_NAMESPACE}" &> /dev/null; then
        echo "Criando namespace ${CHAOS_NAMESPACE}..."
        kubectl create namespace "${CHAOS_NAMESPACE}"
    fi
}

# Aplica um experimento agendado
function apply_scheduled_experiment() {
    local experiment_file=$1
    echo "Aplicando experimento agendado: ${experiment_file}"
    kubectl apply -f "${experiment_file}" -n "${CHAOS_NAMESPACE}"
}

# Monitora os experimentos agendados
function monitor_schedules() {
    echo "Monitorando experimentos agendados..."
    kubectl get schedules -n "${CHAOS_NAMESPACE}" -w
}

# Cria arquivos YAML para os experimentos agendados
function generate_experiment_files() {
    echo "Gerando arquivos de experimentos agendados..."

    # Pod Failure
    cat <<EOF > pod-failure-schedule.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Schedule
metadata:
  name: weekly-pod-failure
spec:
  schedule: "${SCHEDULE_TIME}"
  historyLimit: 5
  concurrencyPolicy: Forbid
  type: PodChaos
  podChaos:
    action: pod-failure
    mode: all
    selector:
      namespaces:
        - ${TARGET_NAMESPACE}
    duration: "${EXPERIMENT_DURATION}"
EOF

    # Network Latency
    cat <<EOF > network-latency-schedule.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Schedule
metadata:
  name: weekly-network-latency
spec:
  schedule: "${SCHEDULE_TIME}"
  historyLimit: 5
  concurrencyPolicy: Forbid
  type: NetworkChaos
  networkChaos:
    action: delay
    mode: all
    selector:
      namespaces:
        - ${TARGET_NAMESPACE}
    delay:
      latency: "100ms"
      correlation: "100"
      jitter: "10ms"
    duration: "${EXPERIMENT_DURATION}"
EOF

    # CPU Stress
    cat <<EOF > cpu-stress-schedule.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Schedule
metadata:
  name: weekly-cpu-stress
spec:
  schedule: "${SCHEDULE_TIME}"
  historyLimit: 5
  concurrencyPolicy: Forbid
  type: StressChaos
  stressChaos:
    mode: one
    selector:
      namespaces:
        - ${TARGET_NAMESPACE}
    stressors:
      cpu:
        workers: 4
        load: 80
        options: ["--cpu 4", "--timeout 300"]
    duration: "${EXPERIMENT_DURATION}"
EOF
}

# Fluxo principal de execução
function main() {
    check_chaos_mesh
    ensure_namespace
    generate_experiment_files
    
    # Aplica os experimentos
    apply_scheduled_experiment pod-failure-schedule.yaml
    apply_scheduled_experiment network-latency-schedule.yaml
    apply_scheduled_experiment cpu-stress-schedule.yaml
    
    # Inicia o monitoramento (opcional - pode ser executado em outro terminal)
    # monitor_schedules
    
    echo "Workflow concluído. Experimentos agendados para execução toda quarta-feira às 02:00."
    echo "Você pode verificar os agendamentos com:"
    echo "  kubectl get schedules -n ${CHAOS_NAMESPACE}"
}

main