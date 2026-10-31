#!/bin/sh

if [ $# -ne 3 ]; then
  echo "Usage: $0 <path_to_finding_dir> <path_to_output_dir> <path_to_image_dir>" >&2
  echo "Example: $0 FindingName report/content/technicalReport/findings/ report/images/findings/" >&2
  exit 1
fi

FINDING_DIR="$1"
FINDING_NAME="$(basename "$FINDING_DIR")"
OUTPUT_FILE="${FINDING_NAME}.tex"
INPUT_IMAGE_DIR="$1/images"
OUTPUT_IMAGE_DIR="$3/${FINDING_NAME}"

# Helper: run html_2_tex.sh safely
html_to_tex() {
  CPTC_FINDING_NAME="$FINDING_NAME" ./html_2_tex.sh
}
listScore() {
  serialized="$(cat "${FINDING_DIR}cvs.txt")"
  score=$(echo "$serialized" | sed -n 's/{\([^}]*\)}.*/\1/p')
  
  if echo "$score >= 9.0" | bc -l | grep -q 1; then
    echo "4 $score ${FINDING_NAME}" >> ../scores.tmp
  elif echo "$score >= 7.0" | bc -l | grep -q 1; then
    echo "3 $score ${FINDING_NAME}" >> ../scores.tmp
  elif echo "$score >= 4.0" | bc -l | grep -q 1; then
    echo "2 $score ${FINDING_NAME}" >> ../scores.tmp
  elif echo "$score >= 1.0" | bc -l | grep -q 1; then
    echo "1 $score ${FINDING_NAME}" >> ../scores.tmp
  else
    echo "0 $score ${FINDING_NAME}" >> ../scores.tmp
  fi
}

if [ -d "$INPUT_IMAGE_DIR" ]; then
  cp -r "$INPUT_IMAGE_DIR" "$OUTPUT_IMAGE_DIR"
fi

{
  # Finding title
  printf "\\\\findingSubsubsection{%s}\n\n" "${FINDING_NAME}"

  # CVSS
  printf "\\\\cvss"
  cat "${FINDING_DIR}/cvs.txt"
  printf "\n\n"

  # Affected systems
  printf "\\\\affectedSystems{\n"
  cat "${FINDING_DIR}/ips.txt"
  printf "\n}\n\n"

  # Details
  printf "\\\\findingSect{Details:}\\\\\\\\\n"
  html_to_tex < "${FINDING_DIR}/details.txt"
  printf "\n\n"

  # Confirmation
  printf "\\\\findingSect{Confirmation:}\\\\\\\\\n"
  html_to_tex < "${FINDING_DIR}/confirmation.txt"
  printf "\n\n"

  # Impact
  printf "\\\\findingSect{Impact:}\\\\\\\\\n"
  html_to_tex < "${FINDING_DIR}/impact.txt"
  printf "\n\n"

  # Mitigation
  printf "\\\\findingSect{Mitigation:}\\\\\\\\\n"
  html_to_tex < "${FINDING_DIR}/mitigation.txt"
  printf "\n\n"

  # Resources
  printf "\\\\findingSect{Resources:}\\\\\\\\\n"
  html_to_tex < "${FINDING_DIR}/references.txt"
  printf "\n"
} > "$2${OUTPUT_FILE}"

echo "Generated ${OUTPUT_FILE}"

listScore
