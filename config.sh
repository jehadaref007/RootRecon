#!/bin/bash

# RootRecon - Advanced Configuration and Utility Functions

# Color Codes for Enhanced Readability
BLUE='\033[94m'
RED='\033[91m'
GREEN='\033[92m'
ORANGE='\033[93m'
RESET='\e[0m'
BOLD='\e[1m'
UNDERLINE='\e[4m'

# Global Configuration Variables
VERSION="1.1"
BROWSER="firefox"
DELAY=5
QUIET_MODE=false
VERBOSE=false
REPORT_DIR="reconnaissance_reports"
MAX_THREADS=5
MAX_RETRIES=3

# Dependency Check List
CORE_DEPENDENCIES=("curl" "jq" "whois" "dig" "xmllint" "parallel")
OPTIONAL_DEPENDENCIES=("nmap" "pandoc" "wkhtmltopdf" "searchsploit")

# Logging Configuration
LOG_FILE="${REPORT_DIR}/rootrecon_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG_DIR="${REPORT_DIR}/errors"

# Ensure directories exist
mkdir -p "$REPORT_DIR" "$ERROR_LOG_DIR"

# Advanced Input Validation Function
validate_input() {
    local input="$1"
    local type="${2:-auto}"
    
    # التحقق التلقائي من نوع المدخل
    if [[ "$type" == "auto" ]]; then
        if [[ "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
            type="ip"
        elif [[ "$input" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
            type="domain"
        else
            log_message "ERROR" "Unable to determine input type for: $input"
            return 1
        fi
    fi
    
    case "$type" in
        "domain")
            if [[ ! "$input" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
                log_message "ERROR" "Invalid domain format: $input"
                return 1
            fi
            ;;
        "ip")
            if [[ ! "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
                log_message "ERROR" "Invalid IP address format: $input"
                return 1
            fi
            ;;
        *)
            log_message "ERROR" "Unsupported input type: $type"
            return 1
            ;;
    esac
    
    return 0
}

# Input Sanitization Function
sanitize_input() {
    local input="$1"
    local mode="${2:-strict}"
    
    case "$mode" in
        "strict")
            # إزالة جميع الأحرف غير الآمنة
            echo "$input" | tr -cd '[:alnum:].-'
            ;;
        "loose")
            # تنظيف أساسي مع الاحتفاظ ببعض الأحرف
            echo "$input" | sed -E 's/[;<>*|`&$()]//g'
            ;;
        *)
            log_message "WARNING" "Unknown sanitization mode. Using strict mode."
            sanitize_input "$input"
            ;;
    esac
}

# Advanced Error Handling Function
handle_error() {
    local exit_code=$1
    local error_message="$2"
    local context="${3:-Unknown Context}"
    local error_log="${ERROR_LOG_DIR}/error_$(date +%Y%m%d_%H%M%S).log"
    
    # تسجيل تفاصيل الخطأ
    {
        echo "Error Timestamp: $(date)"
        echo "Context: $context"
        echo "Exit Code: $exit_code"
        echo "Error Message: $error_message"
        echo "System Info: $(uname -a)"
        echo "---"
    } >> "$error_log"
    
    # عرض رسالة الخطأ
    log_message "ERROR" "$error_message (Exit Code: $exit_code, Context: $context)"
    
    return "$exit_code"
}

# Logging Function with Enhanced Capabilities
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local log_prefix=""
    
    # تحديد اللون والبادئة حسب مستوى الخطأ
    case "$level" in
        "INFO")
            log_prefix="${BLUE}[INFO]${RESET}"
            ;;
        "WARNING")
            log_prefix="${ORANGE}[WARNING]${RESET}"
            ;;
        "ERROR")
            log_prefix="${RED}[ERROR]${RESET}"
            ;;
        "SUCCESS")
            log_prefix="${GREEN}[SUCCESS]${RESET}"
            ;;
        *)
            log_prefix="[LOG]"
            ;;
    esac
    
    # طباعة الرسالة وتسجيلها
    echo -e "${log_prefix} ${timestamp}: ${message}" | tee -a "$LOG_FILE"
    
    # تسجيل الأخطاء في ملف منفصل
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${log_prefix} ${timestamp}: ${message}" >> "${ERROR_LOG_DIR}/errors.log"
    fi
}

# Dependency Check Function with More Detailed Reporting
check_dependencies() {
    log_message "INFO" "Performing comprehensive dependency check..."
    
    local missing_core_deps=()
    local missing_optional_deps=()
    
    # فحص التبعيات الأساسية
    for dep in "${CORE_DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_core_deps+=("$dep")
        fi
    done
    
    # فحص التبعيات الاختيارية
    for dep in "${OPTIONAL_DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_optional_deps+=("$dep")
        fi
    done
    
    # التقرير النهائي
    if [ ${#missing_core_deps[@]} -gt 0 ]; then
        log_message "ERROR" "Missing critical dependencies: ${missing_core_deps[*]}"
        return 1
    fi
    
    if [ ${#missing_optional_deps[@]} -gt 0 ]; then
        log_message "WARNING" "Missing optional dependencies: ${missing_optional_deps[*]}"
    fi
    
    log_message "SUCCESS" "All core dependencies are satisfied"
    return 0
}

# Export utility functions
export -f validate_input
export -f sanitize_input
export -f handle_error
export -f log_message
export -f check_dependencies
