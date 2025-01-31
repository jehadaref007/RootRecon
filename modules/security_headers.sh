#!/bin/bash

# استيراد الإعدادات العامة
source "$(cd "$(dirname "$0")/.." && pwd)/config.sh"

# دالة تحليل رؤوس الأمان المتقدمة
analyze_security_headers() {
    local domain="$1"
    
    # التحقق من صحة المدخلات
    if ! validate_input "$domain" "domain"; then
        log_message "ERROR" "Invalid domain for security headers analysis: $domain"
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
    local results_dir="${REPORT_DIR}/security_headers_${domain}_${timestamp}"
    mkdir -p "$results_dir"
    
    log_message "INFO" "Starting comprehensive security headers analysis for: $domain"
    
    # مصفوفة لتخزين نتائج التحليل
    local analysis_results=()
    
    # رؤوس الأمان للتحقق
    local security_headers=(
        "Strict-Transport-Security"
        "Content-Security-Policy"
        "X-Frame-Options"
        "X-XSS-Protection"
        "X-Content-Type-Options"
        "Referrer-Policy"
        "Feature-Policy"
        "Permissions-Policy"
    )
    
    # استخراج الرؤوس باستخدام curl
    local headers_file="${results_dir}/raw_headers.txt"
    curl -sI "https://$domain" > "$headers_file" 2>&1
    
    if [ $? -ne 0 ]; then
        handle_error $? "Failed to retrieve headers" "Security Headers Extraction"
        return 1
    fi
    
    # تحليل كل رأس أمان
    for header in "${security_headers[@]}"; do
        local header_analysis="${results_dir}/${header,,}_analysis.txt"
        
        # البحث عن الرأس وتحليله
        if grep -qi "$header" "$headers_file"; then
            # استخراج قيمة الرأس
            local header_value=$(grep -i "$header" "$headers_file" | cut -d':' -f2- | xargs)
            
            {
                echo "Header: $header"
                echo "Value: $header_value"
                
                # تحليل متقدم لكل رأس
                case "$header" in
                    "Strict-Transport-Security")
                        if [[ "$header_value" =~ (max-age=[0-9]+) ]]; then
                            echo "Analysis: HSTS Enabled - Provides protection against SSL stripping attacks"
                            analysis_results+=("HSTS Enabled")
                        else
                            echo "Warning: HSTS not properly configured"
                            analysis_results+=("HSTS Misconfigured")
                        fi
                        ;;
                    "Content-Security-Policy")
                        if [[ -n "$header_value" ]]; then
                            echo "Analysis: CSP Enabled - Helps prevent XSS and data injection attacks"
                            analysis_results+=("CSP Enabled")
                        else
                            echo "Warning: Content Security Policy not set"
                            analysis_results+=("CSP Missing")
                        fi
                        ;;
                    "X-Frame-Options")
                        if [[ "$header_value" =~ (DENY|SAMEORIGIN) ]]; then
                            echo "Analysis: Clickjacking protection enabled"
                            analysis_results+=("Clickjacking Protection")
                        else
                            echo "Warning: Potential clickjacking vulnerability"
                            analysis_results+=("Clickjacking Risk")
                        fi
                        ;;
                    "X-XSS-Protection")
                        if [[ "$header_value" =~ (1;mode=block) ]]; then
                            echo "Analysis: XSS protection enabled"
                            analysis_results+=("XSS Protection")
                        else
                            echo "Warning: XSS protection not fully configured"
                            analysis_results+=("XSS Protection Weak")
                        fi
                        ;;
                    *)
                        echo "Basic header present"
                        analysis_results+=("${header} Present")
                        ;;
                esac
            } > "$header_analysis"
        else
            {
                echo "Header: $header"
                echo "Status: Not Found"
                echo "Risk: Potential security vulnerability"
            } > "$header_analysis"
            analysis_results+=("${header} Missing")
        fi
    done
    
    # توليف تقرير شامل
    {
        echo "Security Headers Analysis Report for: $domain"
        echo "-------------------------------------------"
        echo "Analysis Timestamp: $timestamp"
        
        echo -e "\nOverall Analysis:"
        printf '%s\n' "${analysis_results[@]}"
        
        echo -e "\nDetailed Header Analysis:"
        for header in "${security_headers[@]}"; do
            echo -e "\n${header} Analysis:"
            cat "${results_dir}/${header,,}_analysis.txt"
        done
        
        echo -e "\nNote: This is a comprehensive security headers report"
        echo "Recommendations:"
        echo "1. Implement missing security headers"
        echo "2. Review and strengthen existing header configurations"
    } > "${results_dir}/security_headers_report.txt"
    
    # طباعة ملخص النتائج
    log_message "SUCCESS" "Security headers analysis completed for $domain"
    
    return 0
}

# دالة لتقييم مستوى الأمان الإجمالي للرؤوس
calculate_security_headers_score() {
    local domain="$1"
    local report_file="${2:-${REPORT_DIR}/security_headers_report.txt}"
    
    log_message "INFO" "Calculating security headers score for: $domain"
    
    # التحقق من وجود ملف التقرير
    if [[ ! -f "$report_file" ]]; then
        log_message "ERROR" "Security headers report not found: $report_file"
        return 1
    fi
    
    # حساب النقاط بناءً على الرؤوس الموجودة
    local total_score=0
    local max_score=100
    
    # قواعد تسجيل النقاط
    if grep -q "HSTS Enabled" "$report_file"; then
        ((total_score+=15))
    fi
    
    if grep -q "CSP Enabled" "$report_file"; then
        ((total_score+=25))
    fi
    
    if grep -q "Clickjacking Protection" "$report_file"; then
        ((total_score+=15))
    fi
    
    if grep -q "XSS Protection" "$report_file"; then
        ((total_score+=15))
    fi
    
    # تقييم النتيجة
    local security_level=""
    if ((total_score >= 70)); then
        security_level="High"
    elif ((total_score >= 40)); then
        security_level="Medium"
    else
        security_level="Low"
    fi
    
    # كتابة نتيجة التقييم
    {
        echo "Security Headers Score Report"
        echo "Domain: $domain"
        echo "Total Score: $total_score / $max_score"
        echo "Security Level: $security_level"
    } > "${REPORT_DIR}/security_headers_score.txt"
    
    log_message "SUCCESS" "Security headers score calculation completed for $domain"
}

# تصدير الدوال للاستخدام في وحدات أخرى
export -f analyze_security_headers
export -f calculate_security_headers_score
