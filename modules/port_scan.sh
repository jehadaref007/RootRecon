#!/bin/bash

# استيراد الإعدادات العامة
source "$(cd "$(dirname "$0")/.." && pwd)/config.sh"

# دالة المسح المتقدم للمنافذ
advanced_port_scan() {
    local target="$1"
    
    # التحقق من صحة المدخلات
    if ! validate_input "$target"; then
        log_message "ERROR" "Invalid target for port scanning: $target"
        return 1
    fi
    
    # تنظيف المدخلات
    target=$(sanitize_input "$target")
    
    # التحقق من اتصال الشبكة
    if ! ping -c 4 "$target" &> /dev/null; then
        handle_error 1 "Cannot resolve or ping target" "Network Connectivity Check"
        return 1
    fi
    
    # إنشاء مجلد للنتائج مع طابع زمني دقيق
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local results_dir="${REPORT_DIR}/port_scan_${target}_${timestamp}"
    mkdir -p "$results_dir"
    
    # تعريف المتغيرات للمسح
    local scan_types=("TCP" "UDP" "SYN")
    local port_ranges=(
        "1-1024"    # المنافذ المعروفة
        "1025-49151" # المنافذ المسجلة
        "49152-65535" # المنافذ الديناميكية والخاصة
    )
    
    log_message "INFO" "Starting comprehensive port scanning for: $target"
    
    # مصفوفة لتخزين نتائج المسح
    local scan_results=()
    
    # حلقة لتنفيذ مسح المنافذ بأنواع مختلفة
    for scan_type in "${scan_types[@]}"; do
        for port_range in "${port_ranges[@]}"; do
            local output_file="${results_dir}/nmap_${scan_type,,}_scan_${port_range}"
            
            # تنفيذ مسح Nmap مع معالجة الأخطاء
            case "$scan_type" in
                "TCP")
                    nmap -sT -p "$port_range" -sV -O \
                         -oA "$output_file" \
                         -v --open \
                         "$target" > "${output_file}.txt" 2>&1
                    ;;
                "UDP")
                    nmap -sU -p "$port_range" \
                         -oA "$output_file" \
                         -v --open \
                         "$target" > "${output_file}.txt" 2>&1
                    ;;
                "SYN")
                    nmap -sS -p "$port_range" -sV -O \
                         -oA "$output_file" \
                         -v --open \
                         "$target" > "${output_file}.txt" 2>&1
                    ;;
            esac
            
            # التحقق من نتيجة المسح
            local scan_result=$?
            if [ $scan_result -eq 0 ]; then
                scan_results+=("${scan_type} scan for range ${port_range}: Completed successfully")
            else
                handle_error "$scan_result" "${scan_type} port scan failed" "Port Scanning"
            fi
        done
    done
    
    # توليف تقرير شامل للمنافذ
    {
        echo "Port Scan Report for Target: $target"
        echo "-------------------------------------------"
        echo "Scan Timestamp: $timestamp"
        echo "Scan Types: ${scan_types[*]}"
        echo "Port Ranges: ${port_ranges[*]}"
        echo -e "\nScan Results:"
        printf '%s\n' "${scan_results[@]}"
        
        echo -e "\nOpen Ports Summary:"
        # استخراج المنافذ المفتوحة من ملفات النتائج
        for file in "${results_dir}"/nmap_*_scan_*.gnmap; do
            if [ -f "$file" ]; then
                grep -E 'Status: Open' "$file" || echo "No open ports found in $(basename "$file")"
            fi
        done
        
        echo -e "\nNote: Comprehensive port analysis requires manual review"
    } > "${results_dir}/port_scan_summary.txt"
    
    # طباعة ملخص النتائج
    log_message "SUCCESS" "Port scanning completed for $target"
    
    return 0
}

# دالة للتحقق من الخدمات المستخدمة على المنافذ
identify_port_services() {
    local target="$1"
    local port_file="${2:-${REPORT_DIR}/port_scan_summary.txt}"
    
    log_message "INFO" "Identifying services running on open ports for: $target"
    
    # التحقق من وجود ملف المنافذ
    if [[ ! -f "$port_file" ]]; then
        log_message "ERROR" "Port scan summary file not found: $port_file"
        return 1
    fi
    
    # استخراج المنافذ المفتوحة وتحديد الخدمات
    local open_ports=$(grep -oP '(?<=Port: )\d+' "$port_file")
    
    if [[ -z "$open_ports" ]]; then
        log_message "WARNING" "No open ports found for $target"
        return 0
    fi
    
    # تنفيذ مسح الخدمات
    nmap -sV -p "$open_ports" "$target" > "${REPORT_DIR}/service_identification.txt" 2>&1
    
    log_message "SUCCESS" "Service identification completed for $target"
}

# تصدير الدوال للاستخدام في وحدات أخرى
export -f advanced_port_scan
export -f identify_port_services
