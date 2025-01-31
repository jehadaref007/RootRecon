#!/bin/bash

# استيراد الإعدادات العامة
source "$(cd "$(dirname "$0")/.." && pwd)/config.sh"

# دالة التحقق من ثغرات CVE المتقدمة
check_cve_vulnerabilities() {
    local target="$1"
    
    # التحقق من صحة المدخلات
    if ! validate_input "$target"; then
        log_message "ERROR" "Invalid target for CVE vulnerability check: $target"
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
    local results_dir="${REPORT_DIR}/cve_scan_${target}_${timestamp}"
    mkdir -p "$results_dir"
    
    log_message "INFO" "Starting comprehensive CVE vulnerability scanning for: $target"
    
    # مصفوفة لتخزين نتائج المسح
    local scan_results=()
    
    # أدوات مسح CVE المتعددة
    local cve_tools=(
        "nmap --script vuln"
        "searchsploit -w"
        "openvas-cli"
    )
    
    # تنفيذ مسح CVE باستخدام أدوات متعددة
    for tool in "${cve_tools[@]}"; do
        local output_file="${results_dir}/cve_scan_$(echo "$tool" | cut -d' ' -f1).txt"
        
        # تنفيذ المسح مع معالجة الأخطاء
        case "$tool" in
            "nmap --script vuln")
                $tool "$target" > "$output_file" 2>&1
                ;;
            "searchsploit -w")
                $tool "$target" > "$output_file" 2>&1
                ;;
            "openvas-cli")
                # يتطلب إعداد مسبق لـ OpenVAS
                if command -v openvas-cli &> /dev/null; then
                    openvas-cli scan "$target" > "$output_file" 2>&1
                else
                    log_message "WARNING" "OpenVAS not installed. Skipping scan."
                    continue
                fi
                ;;
        esac
        
        # التحقق من نتيجة المسح
        local scan_result=$?
        if [ $scan_result -eq 0 ]; then
            scan_results+=("CVE scan with $tool: Completed successfully")
        else
            handle_error "$scan_result" "CVE scan with $tool failed" "CVE Vulnerability Scanning"
        fi
    done
    
    # استخراج وتصنيف الثغرات باستخدام jq
    local vulnerabilities_file="${results_dir}/cve_vulnerabilities.json"
    {
        echo "{"
        echo "  \"target\": \"$target\","
        echo "  \"scan_timestamp\": \"$timestamp\","
        echo "  \"vulnerability_summary\": {"
        
        # استخراج الثغرات من ملفات المسح
        local cve_count=0
        for file in "${results_dir}"/cve_scan_*.txt; do
            if [ -f "$file" ]; then
                # استخراج معرفات CVE باستخدام regex
                local file_cves=$(grep -oP 'CVE-\d{4}-\d+' "$file")
                if [ -n "$file_cves" ]; then
                    echo "    \"$(basename "$file")\": ["
                    for cve in $file_cves; do
                        echo "      \"$cve\""
                        ((cve_count++))
                    done
                    echo "    ],"
                fi
            fi
        done
        
        echo "    \"total_cve_count\": $cve_count"
        echo "  }"
        echo "}"
    } | jq '.' > "$vulnerabilities_file"
    
    # توليف تقرير شامل
    {
        echo "CVE Vulnerability Scan Report for: $target"
        echo "-------------------------------------------"
        echo "Scan Timestamp: $timestamp"
        
        echo -e "\nScan Results:"
        printf '%s\n' "${scan_results[@]}"
        
        echo -e "\nVulnerability Summary:"
        jq '.vulnerability_summary' "$vulnerabilities_file"
        
        echo -e "\nNote: This report requires manual review and further investigation"
        echo "Recommendations:"
        echo "1. Patch identified vulnerabilities immediately"
        echo "2. Consult with security experts for detailed mitigation strategies"
    } > "${results_dir}/cve_scan_report.txt"
    
    # طباعة ملخص النتائج
    log_message "SUCCESS" "CVE vulnerability scanning completed for $target"
    
    return 0
}

# دالة لتحديث قاعدة بيانات الثغرات
update_cve_database() {
    log_message "INFO" "Updating CVE vulnerability databases"
    
    # تحديث قواعد بيانات مختلفة
    local update_commands=(
        "nmap --script-updatedb"
        "searchsploit -u"
    )
    
    for cmd in "${update_commands[@]}"; do
        log_message "INFO" "Running: $cmd"
        $cmd || {
            handle_error $? "Failed to update database with $cmd" "CVE Database Update"
        }
    done
    
    # التحقق من وجود أحدث قواعد البيانات
    local cve_db_dir="${HOME}/.local/share/cve-database"
    mkdir -p "$cve_db_dir"
    
    # تنزيل أحدث قاعدة بيانات CVE
    curl -L "https://github.com/CVEProject/cvelist/archive/master.zip" -o "${cve_db_dir}/cvelist.zip"
    unzip -o "${cve_db_dir}/cvelist.zip" -d "$cve_db_dir"
    
    log_message "SUCCESS" "CVE vulnerability databases updated successfully"
}

# تصدير الدوال للاستخدام في وحدات أخرى
export -f check_cve_vulnerabilities
export -f update_cve_database
