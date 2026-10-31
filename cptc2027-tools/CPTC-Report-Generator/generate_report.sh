#!/bin/bash

REPORT_BASE_DIR="../report/"
REPORT_CONTENT_DIR="${REPORT_BASE_DIR}content/"
REPORT_FINDING_DIR="${REPORT_CONTENT_DIR}technicalReport/findings/"
REPORT_IMAGE_DIR="${REPORT_BASE_DIR}images/findings/"
FINDINGS_LIST_LOC="${REPORT_CONTENT_DIR}technicalReport/allFindings.tex"
APPENDIX_FILE="${REPORT_CONTENT_DIR}appendices.tex"
GENERATE_FINDING_SCRIPT="./generate_finding_latex.sh"
FINDINGS_LIST_SCRIPT="./generate_findings_list.sh"
SETTING_FILE="../report/settings/settings.tex"
OVERVIEW_DIR="../overviews/"
APPENDIX_DIR="../appendix/"

# Translate findings
cd scripts
mkdir -p "$REPORT_FINDING_DIR"
mkdir -p "$REPORT_IMAGE_DIR"

for finding_dir in ../findings/*/; do
  # Skip if not a directory
  [ -d "$finding_dir" ] || continue

  $GENERATE_FINDING_SCRIPT "$finding_dir" "$REPORT_FINDING_DIR" "$REPORT_IMAGE_DIR"
done

sort -ur ../scores.tmp > ../scores.txt
rm ../scores.tmp

${FINDINGS_LIST_SCRIPT} > ${FINDINGS_LIST_LOC}

readSetting() {
  filename="$1"
  if [ -f "${OVERVIEW_DIR}${filename}" ]; then
    head -n 1 "${OVERVIEW_DIR}${filename}" | sed 's/[[:blank:]]*$//'
  else
    echo ""
  fi
}
writeSetting() {
  settingName="$1"
  content="$2"
  preface='s/\({\\'
  after='}\){[^}]*}$/\1'
  sed -i "${preface}${settingName}${after}{${content}}/" $SETTING_FILE
}
writeTex() {
  filename="$1"
  destination="$2"
  ./html_2_tex.sh < "${OVERVIEW_DIR}${filename}" > "$destination"
}
getSpace() {
  echo "$1 "
}
getPossessive() {
  if [[ "$1" == *s ]]; then
    echo "$1' "
  else
    echo "$1's "
  fi
}
dateStr() {
  str="$1"
  year=$2
  month="${str:5:2}"
  day="${str:8:2}"
  
  case "$month" in
    01) monthStr="January" ;;
    02) monthStr="February" ;;
    03) monthStr="March" ;;
    04) monthStr="April" ;;
    05) monthStr="May" ;;
    06) monthStr="June" ;;
    07) monthStr="July" ;;
    08) monthStr="August" ;;
    09) monthStr="September" ;;
    10) monthStr="October" ;;
    11) monthStr="November" ;;
    12) monthStr="December" ;;
  esac

  case "$day" in
    01) dayStr="1st" ;;
    02) dayStr="2nd" ;;
    03) dayStr="3rd" ;;
    21) dayStr="21st" ;;
    22) dayStr="22nd" ;;
    23) dayStr="23rd" ;;
    31) dayStr="31st" ;;
    0*) dayStr="${day:1:1}th" ;;
    *)  dayStr="${day}th" ;;
  esac

  if $year; then
    echo "${monthStr} ${dayStr}, ${str:0:4}"
  else
    echo "${monthStr} ${dayStr}"
  fi
}

# Translate settings
value="$(readSetting team-name.txt)"
valueS="$(getSpace "$value")"
valueP="$(getPossessive "$value")"
writeSetting "team" "$valueS"
writeSetting "teamP" "$valueP"
writeSetting "teamNoSpace" "$value"

value="$(readSetting team-email.txt)"
writeSetting "teamEmail" "$value"

value="$(readSetting team-phone.txt)"
writeSetting "teamPhone" "$value"

value="$(readSetting client-name.txt)"
valueS="$(getSpace "$value")"
valueP="$(getPossessive "$value")"
writeSetting "client" "$valueS"
writeSetting "clientP" "$valueP"
writeSetting "clientNoSpace" "$value"

valueS="$(readSetting start-time.txt)"
writeSetting "engagementStartTime" "$valueS"
valueE="$(readSetting end-time.txt)"
writeSetting "engagementEndTime" "$valueE"
startStr="$(dateStr "$valueS" false)"
endStr="$(dateStr "$valueE" false)"
if [[ "$startStr" == "$endStr" ]]; then
  writeSetting "timeRange" "On ${sartStr}"
else
  writeSetting "timeRange" "Between ${startStr} and ${endStr}"
fi

valueR="$(readSetting report-time.txt)"
writeSetting "reportTime" "$valueR"
valueStr="$(dateStr "$valueR" true)"
writeSetting "reportDay" "$valueStr"


# Translate overview
writeTex "executive.txt" "${REPORT_CONTENT_DIR}executive.tex"
writeTex "rationale.txt" "${REPORT_CONTENT_DIR}rationale.tex"
writeTex "goals.txt" "${REPORT_CONTENT_DIR}engagementOverview/goals.tex"
writeTex "ai-workflow.txt" "${REPORT_CONTENT_DIR}engagementOverview/AIworkflow.tex"
writeTex "ai-efficacy.txt" "${REPORT_CONTENT_DIR}engagementOverview/AIefficacy.tex"
writeTex "scope.txt" "${REPORT_CONTENT_DIR}engagementOverview/scope.tex"
writeTex "strengths.txt" "${REPORT_CONTENT_DIR}engagementOverview/keyStrengths.tex"
writeTex "recommendations.txt" "${REPORT_CONTENT_DIR}engagementOverview/recommendations.tex"

# Translate appendix
(echo '\section{Appendices}'; echo ''; echo '\renewcommand{\currentFindingColor}{black}'; echo '\renewcommand{\currentFindingBackground}{black}'; echo '') > ${APPENDIX_FILE}
for app_file in ${APPENDIX_DIR}entries/*; do
  # Skip if not .txt
  echo $app_file | grep -q '.txt' || continue

  appId="$(echo $app_file | sed 's/^\(.*\).txt$/\1/')"
  appName="$(head -n 1 $app_file)"
  echo "\newAppendix{${appName}} \label{sec:${appId}}" >> ${APPENDIX_FILE}
  ./html_2_tex.sh < <(tail -n +2 $app_file) >> ${APPENDIX_FILE}
  echo '\newpage' >> ${APPENDIX_FILE}
  echo '' >> ${APPENDIX_FILE}
done

echo '\newAppendix{Tools Used} \label{sec:toolsAppendix}' >> ${APPENDIX_FILE}
for tool_file in ${APPENDIX_DIR}tools/*; do
  # Ship if not .json
  echo $tool_file | grep -q '.json' || continue

  toolName=$(./html_2_tex.sh < <(jq -r '.name' "$tool_file"))
  toolVersion=$(./html_2_tex.sh < <(jq -r '.version' "$tool_file"))
  toolLink=$(./html_2_tex.sh < <(jq -r '.link' "$tool_file"))
  toolDescription=$(./html_2_tex.sh < <(jq -r '.description' "$tool_file"))

  echo "\toolref{${toolName}}{${toolVersion}}{${toolDescription}}{${toolLink}}" >> ${APPENDIX_FILE}
  echo '' >> ${APPENDIX_FILE}
done
