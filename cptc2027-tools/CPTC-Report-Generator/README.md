# CPTC-Report-Generator
A collaborative, rich text editor that automatically converts findings to this template: https://github.com/ufsit/CPTC-Report

## Setup

After cloning the repo, simply run `python3 app.py`. Now you can visit `localhost:5001` in your web browser to interact with the tool.

## Features

On the left-side panel, you will see a list of all current findings (with a button to delete them). You can create a new finding by typing the finding name at the top and then hitting `Create Finding`. Additionally, you can use any of the **prewrites** available to auto-populate your new finding with data from that prewrite.

For each finding you will see the following features are tracked:
- A CVSS score calculator
- A list of affected IPs/machines
- Several fields for the finding, each supported by a rich text editor
- Images can be uploaded and removed from the finding at the bottom

Press **Save All** any time you want to save changes made to your finding (excluding images). Alternatively, if you only ever edited one field, you can save just that field by pressing its corresponding save button.

## Report Generation

Once you have documented all of your findings, run `./generate_report.sh` to automatically generate a LaTeX-based report in `report`. This folder can then be uploaded to an Overleaf server, where it can be rendered and later compiled to a PDF.