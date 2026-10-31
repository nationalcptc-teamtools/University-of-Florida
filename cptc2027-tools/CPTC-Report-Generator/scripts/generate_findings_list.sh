#!/bin/sh
curRisk=5
risk4() {
  printf "%% [============== CRITICAL RISK ================]\n\\\\renewcommand{\\\\currentFindingColor}{criticalPurple}\n\\\\renewcommand{\\\\currentFindingBackground}{criticalPurpleBackground}\n\\\\riskSubsection{Critical Risk Findings}\n\\\\setFindingSection{C}\n\n"
}
risk3() {
  printf "\n%% [============== HIGH RISK ================]\n\\\\renewcommand{\\\\currentFindingColor}{highRed}\n\\\\renewcommand{\\\\currentFindingBackground}{highRedBackground}\n\\\\riskSubsection{High Risk Findings}\n\\\\setFindingSection{H}\n\n"
}
risk2() {
  printf "\n%% [============== MEDIUM RISK ================]\n\\\\renewcommand{\\\\currentFindingColor}{mediumOrange}\n\\\\renewcommand{\\\\currentFindingBackground}{mediumOrangeBackground}\n\\\\riskSubsection{Medium Risk Findings}\n\\\\setFindingSection{M}\n\n"
}
risk1() {
  printf "\n%% [============== LOW RISK ================]\n\\\\renewcommand{\\\\currentFindingColor}{lowGreen}\n\\\\renewcommand{\\\\currentFindingBackground}{lowGreenBackground}\n\\\\riskSubsection{Low Risk Findings}\n\\\\setFindingSection{L}\n\n"
}
risk0() {
  printf "\n%% [============== INFORMATIONAL ================]\n\\\\renewcommand{\\\\currentFindingColor}{infoBlue}\n\\\\renewcommand{\\\\currentFindingBackground}{infoBlueBackground}\n\\\\riskSubsection{Informational Findings}\n\\\\setFindingSection{I}\n\n"
}

while read -r risk score finding; do
  while echo "$curRisk > $risk" | bc -l | grep -q 1; do
    curRisk=$((curRisk-1))
    risk${curRisk}
  done
  printf "\\\\importFinding{\\\\input{content/technicalReport/findings/$finding}}\n"
done < ../scores.txt

while echo "$curRisk > 0" | bc -l | grep -q 1; do
  curRisk=$((curRisk-1))
  risk${curRisk}
done

printf "\n\n\\\\renewcommand{\\\\currentFindingColor}{black}\n\\\\renewcommand{\\\\currentFindingBackground}{black}\n"
