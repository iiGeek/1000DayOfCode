#!/usr/bin/env bash
# DevSecOps setup script for Deepin / Debian-based systems
# Author: Saad's AI buddy 😎

set -euo pipefail

########################
#  COLORS & ICONS
########################
if command -v tput >/dev/null 2>&1; then
  GREEN="$(tput setaf 2)"
  RED="$(tput setaf 1)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  CYAN="$(tput setaf 6)"
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
else
  GREEN=""; RED=""; YELLOW=""; BLUE=""; CYAN=""; BOLD=""; RESET=""
fi

ICON_OK="✔"
ICON_ERR="✖"
ICON_WAIT="⏳"
ICON_INFO="➜"

########################
#  SUDO / USER CHECK
########################
if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

if ! ${SUDO} -v >/dev/null 2>&1; then
  echo -e "${RED}${ICON_ERR} هذا السكربت يحتاج صلاحيات sudo. تأكد إن مستخدمك في sudoers.${RESET}"
  exit 1
fi

########################
#  PROGRESS HANDLING
########################
TOTAL_STEPS=11
CURRENT_STEP=0
BAR_WIDTH=32

draw_progress() {
  local percent="$1"
  local msg="$2"

  local filled=$(( percent * BAR_WIDTH / 100 ))
  local empty=$(( BAR_WIDTH - filled ))
  local bar_filled
  local bar_empty

  bar_filled=$(printf "%${filled}s" | tr ' ' '#')
  bar_empty=$(printf "%${empty}s")

  echo -ne "${CYAN}[${bar_filled}${bar_empty}] ${percent}%${RESET} ${ICON_WAIT} ${msg}\r"
}

finish_step() {
  local msg="$1"
  echo -ne "\r${GREEN}${ICON_OK} ${msg}$(printf '%*s' 40 ' ')${RESET}\n"
}

next_step() {
  local msg="$1"
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
  draw_progress "${percent}" "${msg}"
}

########################
#  LOG FUNCTIONS
########################
log_info() {  echo -e "${BLUE}${ICON_INFO} $*${RESET}"; }
log_ok()   {  echo -e "${GREEN}${ICON_OK} $*${RESET}"; }
log_warn() {  echo -e "${YELLOW}${ICON_ERR} $*${RESET}"; }
log_err()  {  echo -e "${RED}${ICON_ERR} $*${RESET}"; }

########################
#  ERROR HANDLER
########################
trap 'log_err "صار خطأ غير متوقع. راجع آخر الرسائل فوق."; exit 1' ERR

########################
#  PRECHECKS
########################
log_info "بدء إعداد بيئة DevSecOps على هذا الجهاز…"

# بسيط: فحص اتصال إنترنت
if ! ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
  log_warn "ما قدرت أوصل للإنترنت (8.8.8.8). إذا عندك بروكسي أو DNS غريب، عدّله وحاول مرة ثانية."
fi

CODENAME="$(lsb_release -cs 2>/dev/null || echo 'bookworm')"

########################
#  STEP 1: SYSTEM UPDATE
########################
next_step "تحديث النظام والحزم…"
${SUDO} apt update -y >/dev/null
${SUDO} apt upgrade -y >/dev/null
finish_step "تم تحديث النظام."

########################
#  STEP 2: BASE TOOLS
########################
next_step "تثبيت الأدوات الأساسية…"
${SUDO} apt install -y \
  build-essential \
  curl wget gnupg ca-certificates \
  software-properties-common apt-transport-https \
  net-tools \
  unzip zip \
  htop tree \
  lsb-release \
  >/dev/null
finish_step "تم تثبيت الأدوات الأساسية."

########################
#  STEP 3: GIT
########################
next_step "تثبيت Git…"
${SUDO} apt install -y git >/dev/null
finish_step "تم تثبيت Git."

########################
#  STEP 4: Python & Pip
########################
next_step "تثبيت Python3 و Pip و venv…"
${SUDO} apt install -y python3 python3-pip python3-venv >/dev/null
finish_step "تم تثبيت Python."

########################
#  STEP 5: Java 17 (JDK)
########################
next_step "تثبيت OpenJDK 17…"
${SUDO} apt install -y openjdk-17-jdk >/dev/null || \
  ${SUDO} apt install -y default-jdk >/dev/null
finish_step "تم تثبيت Java."

########################
#  STEP 6: NodeJS (LTS)
########################
next_step "تثبيت Node.js (آخر LTS) من NodeSource…"
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | ${SUDO} -E bash - >/dev/null
  ${SUDO} apt install -y nodejs >/dev/null
else
  log_info "NodeJS موجود مسبقاً، بتخليه كما هو."
fi
finish_step "تم تجهيز Node.js."

########################
#  STEP 7: Docker Engine
########################
next_step "تجهيز مستودعات Docker وتثبيته…"

if ! command -v docker >/dev/null 2>&1; then
  ${SUDO} install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | ${SUDO} gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  ${SUDO} chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian ${CODENAME} stable" | \
  ${SUDO} tee /etc/apt/sources.list.d/docker.list >/dev/null

  ${SUDO} apt update -y >/dev/null
  ${SUDO} apt install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin \
    >/dev/null

  ${SUDO} usermod -aG docker "$USER" || true
else
  log_info "Docker مثبت مسبقاً، بتجاوز التثبيت."
fi
finish_step "تم إعداد Docker (قد تحتاج تسوي إعادة تشغيل عشان تفعل مجموعة docker)."

########################
#  STEP 8: VS Code
########################
next_step "تثبيت Visual Studio Code…"

if ! command -v code >/dev/null 2>&1; then
  TMP_DEB="/tmp/vscode_latest.deb"
  wget -qO "${TMP_DEB}" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
  ${SUDO} apt install -y "${TMP_DEB}" >/dev/null || {
    log_warn "فشل تثبيت VS Code من الملف .deb. حاول تثبته يدوياً لاحقاً."
  }
  rm -f "${TMP_DEB}" || true
else
  log_info "VS Code موجود مسبقاً."
fi
finish_step "محاولة تثبيت VS Code انتهت."

########################
#  STEP 9: NET & SECURITY CLI TOOLS
########################
next_step "تثبيت أدوات الشبكات والأمن الأساسية…"
${SUDO} apt install -y \
  nmap tcpdump traceroute whois dnsutils \
  >/dev/null || true

# Nikto
if ! ${SUDO} apt install -y nikto >/dev/null 2>&1; then
  log_warn "Nikto غير متوفر في المستودعات الحالية."
fi

finish_step "تم تثبيت أدوات الشبكات الأساسية وما توفر من أدوات الأمن."

########################
#  STEP 10: Pentest Tools (Metasploit, Hashcat, John)
########################
next_step "تثبيت أدوات الاختبار الهجومي (إن توفرت)…"

if ! ${SUDO} apt install -y metasploit-framework >/dev/null 2>&1; then
  log_warn "metasploit-framework غير متوفر في هذه الريبو. ممكن تحتاج مستودع خارجي لاحقاً."
fi

${SUDO} apt install -y hashcat john >/dev/null 2>&1 || \
  log_warn "بعض أدوات الكراك (hashcat / john) ما قدرت تنزل كاملة."

finish_step "محاولة تثبيت أدوات البنتست انتهت."

########################
#  STEP 11: DevSecOps Scanners (Trivy, Bandit, Semgrep)
########################
next_step "تثبيت أدوات فحص الحاويات والكود…"

# Trivy من المستودع إذا متوفر
if ! ${SUDO} apt install -y trivy >/dev/null 2>&1; then
  log_warn "Trivy غير متوفر من apt. تقدر تثبته لاحقاً من GitHub (أداة قوية لفحص Docker)."
fi

# pip tools
if command -v pip3 >/dev/null 2>&1; then
  python3 -m pip install --user --upgrade pip >/dev/null 2>&1 || true
  python3 -m pip install --user bandit semgrep >/dev/null 2>&1 || \
    log_warn "بعض أدوات pip (bandit/semgrep) ما تثبتت. تأكد من الإنترنت وجرب مرة ثانية."
else
  log_warn "pip3 غير متوفر، ما أقدر أثبت أدوات Python الأمنية."
fi

finish_step "محاولة تثبيت أدوات DevSecOps للكود والحاويات انتهت."

########################
#  SUMMARY
########################
echo
log_ok "انتهى السكربت 🎉"
echo
echo -e "${BOLD}ملخص سريع للأشياء اللي المفروض تكون عندك الآن:${RESET}"
echo "- Git"
echo "- Python 3 + pip + venv"
echo "- Java (JDK 17 أو الافتراضي)"
echo "- Node.js (آخر LTS من NodeSource)"
echo "- Docker Engine + Docker Compose plugin"
echo "- Visual Studio Code (إذا تثبّت بنجاح)"
echo "- أدوات الشبكات: nmap, tcpdump, traceroute, whois, dnsutils, htop, tree..."
echo "- أدوات أمنية: nikto (إذا متوفر), hashcat, john, metasploit (إذا متوفر), trivy (إذا متوفر)"
echo "- أدوات تحليل الكود: bandit, semgrep (عن طريق pip)"
echo
log_info "أنصحك بعد إعادة تشغيل الجهاز، تتأكد إن docker يشتغل بدون sudo:"
echo -e "${CYAN}  docker run hello-world${RESET}"
echo
log_info "لو فيه جزء فشل، أرسل لي مخرجات التثبيت الأخيرة ونصلحها خطوة خطوة."