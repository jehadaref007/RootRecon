#!/bin/bash

# استيراد الإعدادات العامة
source "$(cd "$(dirname "$0")/.." && pwd)/config.sh"

# دالة استخراج معلومات النطاق المتقدمة
extract_domain_info() {
    local domain="$1"
    
    # التحقق من صحة المدخلات
    if ! validate_input "$domain" "domain"; then
        log_message "ERROR" "Invalid domain for information extraction: $domain"
        return 1
    fi
    
    # تنظيف المدخلات
    domain=$(sanitize_input "$domain")
    
    # التحقق من اتصال الشبكة
    if ! ping -c 4 "$domain" &> /dev/null; then
        handle_error 1 "Cannot resolve or ping domain" "Network Connectivity Check"
        return 1
    fi
    
    # إنشاء مجلد للنتائج مع طابع زمني دقيق
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local results_dir="${REPORT_DIR}/domain_info_${domain}_${timestamp}"
    mkdir -p "$results_dir"
    
    log_message "INFO" "Starting comprehensive domain information extraction for: $domain"
    
    # مصفوفة لتخزين نتائج الاستعلامات
    local query_results=()
    
    # 1. معلومات WHOIS
    log_message "INFO" "Extracting WHOIS information"
    whois "$domain" > "${results_dir}/whois_info.txt" 2>&1
    if [ $? -eq 0 ]; then
        query_results+=("WHOIS information extracted successfully")
    else
        handle_error $? "WHOIS query failed" "Domain WHOIS Lookup"
    fi
    
    # 2. سجلات DNS
    log_message "INFO" "Retrieving DNS records"
    local dns_record_types=("A" "AAAA" "MX" "NS" "TXT" "CNAME")
    
    for record_type in "${dns_record_types[@]}"; do
        dig +short "$record_type" "$domain" > "${results_dir}/dns_${record_type,,}_records.txt" 2>&1
        if [ $? -eq 0 ]; then
            query_results+=("DNS ${record_type} records retrieved")
        else
            handle_error $? "DNS ${record_type} record query failed" "DNS Lookup"
        fi
    done
    
    # 3. معلومات SSL/TLS
    log_message "INFO" "Checking SSL/TLS certificate information"
    openssl s_client -connect "$domain:443" -showcerts < /dev/null > "${results_dir}/ssl_certificate_info.txt" 2>&1
    if [ $? -eq 0 ]; then
        query_results+=("SSL/TLS certificate information extracted")
    else
        handle_error $? "SSL certificate query failed" "SSL Certificate Check"
    fi
    
    # 4. تتبع المسار الشبكي
    log_message "INFO" "Performing network traceroute"
    traceroute "$domain" > "${results_dir}/network_traceroute.txt" 2>&1
    if [ $? -eq 0 ]; then
        query_results+=("Network traceroute completed")
    else
        handle_error $? "Traceroute failed" "Network Traceroute"
    fi
    
    # توليف تقرير شامل للمعلومات
    {
        echo "Domain Information Report for: $domain"
        echo "-------------------------------------------"
        echo "Extraction Timestamp: $timestamp"
        
        echo -e "\nQuery Results:"
        printf '%s\n' "${query_results[@]}"
        
        echo -e "\nDetailed Information:"
        echo "1. WHOIS Information:"
        cat "${results_dir}/whois_info.txt"
        
        echo -e "\n2. DNS Records:"
        for record_type in "${dns_record_types[@]}"; do
            echo "   ${record_type} Records:"
            cat "${results_dir}/dns_${record_type,,}_records.txt"
        done
        
        echo -e "\n3. SSL/TLS Certificate Information:"
        cat "${results_dir}/ssl_certificate_info.txt"
        
        echo -e "\n4. Network Traceroute:"
        cat "${results_dir}/network_traceroute.txt"
        
        echo -e "\nNote: This is a comprehensive domain information report"
    } > "${results_dir}/domain_info_report.txt"
    
    # طباعة ملخص النتائج
    log_message "SUCCESS" "Domain information extraction completed for $domain"
    
    return 0
}

# دالة لتحليل معلومات النطاق بشكل متقدم
analyze_domain_reputation() {
    local domain="$1"
    
    log_message "INFO" "Analyzing domain reputation for: $domain"
    
    # التحقق من صحة المدخلات
    if ! validate_input "$domain" "domain"; then
        log_message "ERROR" "Invalid domain for reputation analysis: $domain"
        return 1
    fi
    
    # تنظيف المدخلات
    domain=$(sanitize_input "$domain")
    
    # استخدام أدوات مختلفة لتحليل سمعة النطاق
    local reputation_sources=(
        "https://urlhaus.abuse.ch/api/v1/host/$domain"
        "https://www.virustotal.com/vtapi/v2/url/report"
    )
    
    local results_dir="${REPORT_DIR}/domain_reputation_${domain}"
    mkdir -p "$results_dir"
    
    for source in "${reputation_sources[@]}"; do
        local output_file="${results_dir}/reputation_$(basename "$source").json"
        
        # استخدام curl للاستعلام عن سمعة النطاق
        curl -s "$source" > "$output_file" 2>&1
        
        if [ $? -eq 0 ]; then
            log_message "INFO" "Retrieved reputation data from $source"
        else
            handle_error $? "Failed to retrieve reputation data" "Domain Reputation Check"
        fi
    done
    
    log_message "SUCCESS" "Domain reputation analysis completed for $domain"
}

# تصدير الدوال للاستخدام في وحدات أخرى
export -f extract_domain_info
export -f analyze_domain_reputation
