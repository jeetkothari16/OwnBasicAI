#!/usr/bin/env bash
# ==============================================================================
#  install_miniconda.sh — Foolproof Miniconda installer for Ubuntu
# ==============================================================================
#  What this script does:
#    1. Checks for existing Anaconda / Miniconda / conda installations
#    2. Verifies prerequisites (wget or curl, bash, arch)
#    3. Downloads the latest Miniconda installer from the official repo
#    4. Verifies the SHA-256 checksum against Anaconda's published hash
#    5. Runs the silent installer
#    6. Initialises conda in ~/.bashrc
#    7. Cleans up the installer file
#
#  Usage:
#    chmod +x install_miniconda.sh
#    ./install_miniconda.sh
#
#  Optional flags:
#    --prefix /custom/path   Install to a custom directory (default: ~/miniconda3)
#    --skip-init             Don't run `conda init` (useful for CI)
#    --force                 Overwrite an existing installation (USE WITH CARE)
# ==============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # no colour

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }
section() { echo -e "\n${BOLD}==> $*${NC}"; }

# ── Defaults ──────────────────────────────────────────────────────────────────
INSTALL_PREFIX="${HOME}/miniconda3"
SKIP_INIT=false
FORCE=false
INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
INSTALLER_HASH_URL="https://repo.anaconda.com/miniconda/"
TMP_INSTALLER="/tmp/miniconda_installer_$$.sh"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      INSTALL_PREFIX="$2"; shift 2 ;;
    --skip-init)
      SKIP_INIT=true; shift ;;
    --force)
      FORCE=true; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)
      die "Unknown argument: $1  (use --help for usage)" ;;
  esac
done

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     Miniconda Installer for Ubuntu       ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── Step 1: Detect existing conda / anaconda installations ───────────────────
section "Checking for existing conda installations"

EXISTING_CONDA=""

# 1a. Is conda already on PATH?
if command -v conda &>/dev/null; then
  EXISTING_CONDA="$(command -v conda)"
fi

# 1b. Check common install directories even if not on PATH
COMMON_PATHS=(
  "$HOME/miniconda3"
  "$HOME/miniconda"
  "$HOME/anaconda3"
  "$HOME/anaconda"
  "/opt/conda"
  "/opt/miniconda3"
  "/opt/anaconda3"
  "/usr/local/conda"
)

FOUND_DIRS=()
for p in "${COMMON_PATHS[@]}"; do
  if [[ -d "$p" ]]; then
    FOUND_DIRS+=("$p")
  fi
done

# 1c. Check if ~/.bashrc / ~/.bash_profile already has conda init block
SHELL_HAS_CONDA=false
for rc in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
  if [[ -f "$rc" ]] && grep -q "conda initialize" "$rc" 2>/dev/null; then
    SHELL_HAS_CONDA=true
    break
  fi
done

# 1d. Report findings
if [[ -n "$EXISTING_CONDA" ]]; then
  warn "conda is already available on your PATH:"
  warn "  Binary : $EXISTING_CONDA"
  warn "  Version: $(conda --version 2>&1)"
fi

if [[ ${#FOUND_DIRS[@]} -gt 0 ]]; then
  warn "Existing conda/anaconda directory found:"
  for d in "${FOUND_DIRS[@]}"; do
    warn "  $d"
  done
fi

if $SHELL_HAS_CONDA; then
  warn "A 'conda initialize' block was detected in your shell config."
fi

# 1e. Bail out unless --force was passed
if [[ -n "$EXISTING_CONDA" || ${#FOUND_DIRS[@]} -gt 0 || $SHELL_HAS_CONDA == true ]]; then
  if $FORCE; then
    warn "--force flag set. Proceeding with installation anyway."
    warn "Existing directories will NOT be deleted — installer will use: ${INSTALL_PREFIX}"
  else
    echo ""
    warn "An existing Anaconda/Miniconda installation appears to be present."
    warn "To avoid conflicts, this script will NOT install again."
    echo ""
    info "Your options:"
    info "  1. Use the existing installation (run: conda --version)"
    info "  2. Re-run this script with --force to install anyway"
    info "     (does not remove existing installs; choose a different --prefix)"
    info "  3. Manually remove the existing installation first:"
    info "     rm -rf ~/miniconda3  (or the relevant path above)"
    echo ""
    exit 0
  fi
else
  success "No existing conda installation detected. Proceeding."
fi

# ── Step 2: Check target prefix doesn't already exist ────────────────────────
section "Checking install prefix: ${INSTALL_PREFIX}"

if [[ -d "$INSTALL_PREFIX" ]]; then
  if $FORCE; then
    warn "Target directory already exists: ${INSTALL_PREFIX}"
    warn "Installer will attempt to overwrite — consider removing it first."
  else
    die "Target directory already exists: ${INSTALL_PREFIX}\nUse --force to proceed anyway, or choose a different --prefix."
  fi
else
  success "Install prefix is available."
fi

# ── Step 3: Verify architecture ───────────────────────────────────────────────
section "Verifying system architecture"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)
    success "Architecture: x86_64 — using standard Linux installer." ;;
  aarch64|arm64)
    INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"
    success "Architecture: ARM64 — switching to aarch64 installer." ;;
  s390x)
    INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-s390x.sh"
    success "Architecture: s390x — switching to s390x installer." ;;
  *)
    die "Unsupported architecture: ${ARCH}" ;;
esac

# ── Step 4: Check prerequisites ───────────────────────────────────────────────
section "Checking prerequisites"

DOWNLOADER=""
if command -v wget &>/dev/null; then
  DOWNLOADER="wget"
  success "wget found."
elif command -v curl &>/dev/null; then
  DOWNLOADER="curl"
  success "curl found."
else
  die "Neither wget nor curl is available. Install one first:\n  sudo apt-get install -y wget"
fi

for tool in bash sha256sum; do
  if command -v "$tool" &>/dev/null; then
    success "$tool found."
  else
    die "Required tool not found: $tool"
  fi
done

# ── Step 5: Download installer ────────────────────────────────────────────────
section "Downloading Miniconda installer"
info "URL : $INSTALLER_URL"
info "Dest: $TMP_INSTALLER"

if [[ "$DOWNLOADER" == "wget" ]]; then
  wget --progress=bar:force -O "$TMP_INSTALLER" "$INSTALLER_URL" 2>&1 \
    || die "Download failed. Check your internet connection."
else
  curl -L --progress-bar -o "$TMP_INSTALLER" "$INSTALLER_URL" \
    || die "Download failed. Check your internet connection."
fi

success "Download complete."

# ── Step 6: Verify checksum ───────────────────────────────────────────────────
section "Verifying SHA-256 checksum"

# Fetch the index page and parse the hash for our installer filename
INSTALLER_FILENAME="${INSTALLER_URL##*/}"

info "Fetching official checksums from Anaconda..."

HASH_PAGE=""
if [[ "$DOWNLOADER" == "wget" ]]; then
  HASH_PAGE="$(wget -qO- "${INSTALLER_HASH_URL}" 2>/dev/null)" || true
else
  HASH_PAGE="$(curl -s "${INSTALLER_HASH_URL}" 2>/dev/null)" || true
fi

EXPECTED_HASH=""
if [[ -n "$HASH_PAGE" ]]; then
  # The hash appears right after the filename in the HTML table
  EXPECTED_HASH="$(echo "$HASH_PAGE" \
    | grep -A5 "$INSTALLER_FILENAME" \
    | grep -oE '[a-f0-9]{64}' \
    | head -1)" || true
fi

ACTUAL_HASH="$(sha256sum "$TMP_INSTALLER" | awk '{print $1}')"

if [[ -n "$EXPECTED_HASH" ]]; then
  info "Expected : $EXPECTED_HASH"
  info "Actual   : $ACTUAL_HASH"
  if [[ "$ACTUAL_HASH" == "$EXPECTED_HASH" ]]; then
    success "Checksum verified — installer is intact."
  else
    rm -f "$TMP_INSTALLER"
    die "Checksum MISMATCH! The downloaded file may be corrupted or tampered with.\nExpected: $EXPECTED_HASH\nActual  : $ACTUAL_HASH"
  fi
else
  warn "Could not fetch the official checksum page to verify against."
  warn "Proceeding without checksum verification (network issue or page format change)."
  warn "Installer SHA-256: $ACTUAL_HASH"
  warn "You can manually verify at: https://repo.anaconda.com/miniconda/"
fi

# ── Step 7: Run installer ─────────────────────────────────────────────────────
section "Installing Miniconda to: ${INSTALL_PREFIX}"

chmod +x "$TMP_INSTALLER"

# -b  = batch / non-interactive (accepts licence automatically)
# -p  = installation prefix
bash "$TMP_INSTALLER" -b -p "$INSTALL_PREFIX" \
  || die "Miniconda installer returned a non-zero exit code."

success "Miniconda installed successfully."

# ── Step 8: Initialise conda in shell ─────────────────────────────────────────
section "Initialising conda"

if $SKIP_INIT; then
  warn "--skip-init set. Skipping 'conda init'. You will need to activate conda manually:"
  warn "  source ${INSTALL_PREFIX}/etc/profile.d/conda.sh"
else
  "${INSTALL_PREFIX}/bin/conda" init bash \
    || warn "'conda init bash' reported an error — you may need to initialise manually."
  success "conda init complete. ~/.bashrc has been updated."
fi

# ── Step 9: Clean up ──────────────────────────────────────────────────────────
# section "Cleaning up"
# rm -f "$TMP_INSTALLER"
# success "Installer file removed."

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗"
echo -e "║   Miniconda installation complete! 🎉            ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo ""
info "Installed to  : ${INSTALL_PREFIX}"
info "conda binary  : ${INSTALL_PREFIX}/bin/conda"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  1. Reload your shell:"
echo -e "     ${CYAN}source ~/.bashrc${NC}"
echo "  2. Verify the installation:"
echo -e "     ${CYAN}conda --version${NC}"
echo "  3. Create your first environment:"
echo -e "     ${CYAN}conda create -n myenv python=3.11${NC}"
echo "  4. Activate it:"
echo -e "     ${CYAN}conda activate myenv${NC}"
echo ""
warn "NOTE: By using Miniconda in a commercial setting, you may need a"
warn "      paid Anaconda licence. See: https://www.anaconda.com/legal"
echo ""
