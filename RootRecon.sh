#!/bin/bash

# RootRecon - Advanced Security and Reconnaissance Tool
# Version 1.1

# استيراد الوحدات والإعدادات
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/modules/domain_info.sh"
source "$(dirname "$0")/modules/security_headers.sh"
source "$(dirname "$0")/modules/vulnerability_scan.sh"
source "$(dirname "$0")/modules/port_scan.sh"
source "$(dirname "$0")/modules/cve_scan.sh"
source "$(dirname "$0")/modules/generate_report.sh"

# دالة عرض المساعدة مع معلومات مفصلة
usage() {
    echo "RootRecon v${VERSION} - Advanced Security and Reconnaissance Tool"
    echo "Usage: $0 [options] <target>"
    echo ""
    echo "Options:"
    echo "  -d, --domain     Target domain or IP to scan"
    echo "  -q, --quiet      Enable quiet mode (minimal output)"
    echo "  -v, --verbose    Enable verbose mode (detailed output)"
    echo "  -o, --output     Specify custom output directory"
    echo "  -r, --retry      Number of scan retries (default: ${MAX_RETRIES})"
    echo "  -t, --threads    Number of parallel threads (default: ${MAX_THREADS})"
    echo "  -h, --help       Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d example.com"
    echo "  $0 --domain example.com --quiet"
    echo "  $0 -d 192.168.1.1 -o /custom/report/path -r 3 -t 5"
    echo ""
    echo "Security and Performance Notes:"
    echo "  - Always ensure you have permission before scanning"
    echo "  - Scanning may take considerable time depending on target complexity"
}

# معالجة الأوامر والخيارات مع التحقق المتقدم
parse_arguments() {
    local ARGS
    
    # استخدام getopt للتعامل مع الخيارات المركبة
    ARGS=$(getopt -o d:qvr:t:o:h --long domain:,quiet,verbose,retry:,threads:,output:,help -n "$0" -- "$@")
    
    if [ $? -ne 0 ]; then
        usage
        exit 1
    fi
    
    eval set -- "$ARGS"
    
    # متغيرات افتراضية
    local target=""
    local retry_count=$MAX_RETRIES
    local thread_count=$MAX_THREADS
    
    while true; do
        case "$1" in
            -d|--domain)
                # التحقق من صحة المدخلات باستخدام دالة validate_input
                if ! validate_input "$2"; then
                    log_message "ERROR" "Invalid target: $2"
                    usage
                    exit 1
                fi
                
                # تنظيف المدخلات
                target=$(sanitize_input "$2")
                shift 2
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -r|--retry)
                # التحقق من عدد محاولات إعادة المحاولة
                if [[ ! "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 10 ]; then
                    log_message "ERROR" "Invalid retry count. Must be between 1-10."
                    exit 1
                fi
                retry_count="$2"
                shift 2
                ;;
            -t|--threads)
                # التحقق من عدد الخيوط
                if [[ ! "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 20 ]; then
                    log_message "ERROR" "Invalid thread count. Must be between 1-20."
                    exit 1
                fi
                thread_count="$2"
                shift 2
                ;;
            -o|--output)
                # التحقق من صحة مسار المجلد
                if [[ ! -d "$2" ]]; then
                    log_message "ERROR" "Output directory does not exist: $2"
                    exit 1
                fi
                REPORT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                log_message "ERROR" "Invalid argument: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # التأكد من وجود هدف
    if [[ -z "$target" ]]; then
        log_message "ERROR" "No target specified. Use -h for help."
        usage
        exit 1
    fi
    
    # تصدير المتغيرات للاستخدام العام
    export TARGET="$target"
    export MAX_RETRIES="$retry_count"
    export MAX_THREADS="$thread_count"
}

# الدالة الرئيسية للمسح والتحليل مع دعم التوازي
main_reconnaissance() {
    local target="$1"
    
    # التحقق من التبعيات
    check_dependencies || exit 1
    
    # تحديث قاعدة بيانات الثغرات
    update_vulnerability_database
    
    log_message "INFO" "Starting comprehensive reconnaissance for target: $target"
    
    # استخدام GNU Parallel للتنفيذ المتوازي
    local parallel_command=(
        "extract_domain_info '$target'"
        "analyze_security_headers '$target'"
        "scan_vulnerabilities '$target'"
        "advanced_port_scan '$target'"
        "check_cve_vulnerabilities '$target'"
    )
    
    # تنفيذ المهام بشكل متوازٍ
    parallel -j "$MAX_THREADS" ::: "${parallel_command[@]}" || {
        handle_error $? "Parallel scan failed for target: $target" "main_reconnaissance"
        return 1
    }
    
    # توليد التقرير النهائي
    generate_html_report "$target" || {
        handle_error $? "Report generation failed for target: $target" "main_reconnaissance"
        return 1
    }
    
    log_message "SUCCESS" "Reconnaissance completed successfully for target: $target"
    return 0
}

# نقطة الدخول الرئيسية
main() {
    # معالجة الأوامر والخيارات
    parse_arguments "$@"
    
    # بدء المسح الرئيسي
    main_reconnaissance "$TARGET"
}

# تشغيل الدالة الرئيسية
main "$@"
