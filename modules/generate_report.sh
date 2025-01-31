#!/bin/bash

# استيراد الإعدادات العامة
source "$(cd "$(dirname "$0")/.." && pwd)/config.sh"

# دالة توليد التقرير الرئيسي المتكامل
generate_html_report() {
    local target="$1"
    
    # التحقق من صحة المدخلات
    if ! validate_input "$target"; then
        log_message "ERROR" "Invalid target for report generation: $target"
        return 1
    fi
    
    # تنظيف المدخلات
    target=$(sanitize_input "$target")
    
    # إنشاء مجلد للتقارير مع طابع زمني دقيق
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_dir="${REPORT_DIR}/comprehensive_report_${target}_${timestamp}"
    mkdir -p "$report_dir"
    
    log_message "INFO" "Generating comprehensive security report for: $target"
    
    # مجموعة التقارير الفرعية
    local report_sources=(
        "${REPORT_DIR}/domain_info_${target}_*/domain_info_report.txt"
        "${REPORT_DIR}/port_scan_${target}_*/port_scan_summary.txt"
        "${REPORT_DIR}/vulnerability_scan_${target}_*/vulnerability_assessment.txt"
        "${REPORT_DIR}/security_headers_${target}_*/security_headers_report.txt"
        "${REPORT_DIR}/cve_scan_${target}_*/cve_scan_report.txt"
    )
    
    # توليد التقرير HTML
    local html_report="${report_dir}/security_assessment_report.html"
    {
        # رأس التقرير HTML
        echo "<!DOCTYPE html>"
        echo "<html lang='ar' dir='rtl'>"
        echo "<head>"
        echo "  <meta charset='UTF-8'>"
        echo "  <title>RootRecon Security Assessment Report</title>"
        echo "  <style>"
        echo "    body { font-family: Arial, sans-serif; line-height: 1.6; direction: rtl; }"
        echo "    .report-section { background-color: #f4f4f4; margin: 10px 0; padding: 15px; border-radius: 5px; }"
        echo "    .section-title { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }"
        echo "    .high-risk { color: red; font-weight: bold; }"
        echo "    .medium-risk { color: orange; }"
        echo "    .low-risk { color: green; }"
        echo "  </style>"
        echo "</head>"
        echo "<body>"
        
        # عنوان التقرير الرئيسي
        echo "<h1>RootRecon Security Assessment Report</h1>"
        echo "<div class='report-section'>"
        echo "  <h2>Target Information</h2>"
        echo "  <p><strong>Target:</strong> $target</p>"
        echo "  <p><strong>Scan Timestamp:</strong> $timestamp</p>"
        echo "</div>"
        
        # دمج التقارير الفرعية
        for source in "${report_sources[@]}"; do
            for report in $source; do
                if [ -f "$report" ]; then
                    local section_name=$(basename "$(dirname "$report")")
                    echo "<div class='report-section'>"
                    echo "  <h2 class='section-title'>$section_name Report</h2>"
                    echo "  <pre>"
                    cat "$report"
                    echo "  </pre>"
                    echo "</div>"
                fi
            done
        done
        
        # ملخص التقييم والتوصيات
        echo "<div class='report-section'>"
        echo "  <h2>Security Assessment Summary</h2>"
        
        # حساب درجة المخاطر الإجمالية
        local risk_level="low"
        local cve_count=$(grep -oP '"total_cve_count": \K\d+' "${REPORT_DIR}/cve_scan_${target}_"*/cve_vulnerabilities.json 2>/dev/null)
        
        if [[ -n "$cve_count" && "$cve_count" -gt 0 ]]; then
            if [ "$cve_count" -lt 5 ]; then
                risk_level="medium"
            else
                risk_level="high"
            fi
        fi
        
        echo "  <p>Overall Risk Level: <span class='${risk_level}-risk'>$risk_level</span></p>"
        
        echo "  <h3>Recommendations</h3>"
        echo "  <ul>"
        echo "    <li>Immediately address identified vulnerabilities</li>"
        echo "    <li>Update and patch all systems and services</li>"
        echo "    <li>Implement recommended security configurations</li>"
        echo "    <li>Conduct regular security assessments</li>"
        echo "  </ul>"
        echo "</div>"
        
        # إغلاق وثيقة HTML
        echo "</body>"
        echo "</html>"
    } > "$html_report"
    
    # توليد نسخة PDF (اختياري)
    if command -v wkhtmltopdf &> /dev/null; then
        wkhtmltopdf "$html_report" "${report_dir}/security_assessment_report.pdf"
        log_message "SUCCESS" "Generated PDF report"
    else
        log_message "WARNING" "wkhtmltopdf not installed. Skipping PDF generation."
    fi
    
    log_message "SUCCESS" "Comprehensive security report generated for $target"
    
    return 0
}

# دالة توليد تقرير موجز
generate_summary_report() {
    local target="$1"
    local full_report_path="${2:-${REPORT_DIR}/comprehensive_report_${target}_*/security_assessment_report.html}"
    
    log_message "INFO" "Generating summary report for: $target"
    
    # العثور على أحدث تقرير
    local latest_report=$(find $full_report_path -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")
    
    if [[ -z "$latest_report" ]]; then
        log_message "ERROR" "No comprehensive report found for $target"
        return 1
    fi
    
    # استخراج المعلومات الرئيسية
    local summary_file="${REPORT_DIR}/security_summary_${target}.txt"
    {
        echo "RootRecon Security Summary"
        echo "========================="
        echo "Target: $target"
        echo "Report Date: $(date '+%Y-%m-%d %H:%M:%S')"
        
        echo -e "\nKey Findings:"
        grep -E 'Risk Level|CVE|Open Ports|Vulnerabilities' "$latest_report"
        
        echo -e "\nQuick Recommendations:"
        echo "1. Patch critical vulnerabilities"
        echo "2. Review and harden network configurations"
        echo "3. Implement multi-layered security measures"
    } > "$summary_file"
    
    log_message "SUCCESS" "Summary report generated: $summary_file"
}

# تصدير الدوال للاستخدام في وحدات أخرى
export -f generate_html_report
export -f generate_summary_report
