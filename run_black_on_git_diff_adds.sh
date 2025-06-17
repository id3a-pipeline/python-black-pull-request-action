#!/bin/bash
if [[ -z ${GITHUB_TOKEN} ]]
then
    echo "must define the environment variable GITHUB_TOKEN, try: 'GITHUB_TOKEN : \$\{\{ secrets.GITHUB_TOKEN \}\}' in your workflow's main.yml"
    exit 1
fi

if [[ ${GITHUB_EVENT_NAME} != "pull_request" ]]
then
    echo "this action runs only on pull request events"
    exit 1
fi

github_pr_url=`jq '.pull_request.url' ${GITHUB_EVENT_PATH}`
# github pr url sometimes has leading and trailing quotes
github_pr_url=`sed -e 's/^"//' -e 's/"$//' <<<"$github_pr_url"`
echo "looking for diff at ${github_pr_url}"

curl --request GET ${github_pr_url} --header "Authorization: Bearer ${GITHUB_TOKEN}" --header "Accept: application/vnd.github.v3.diff" > github_diff.txt
diff_length=`wc -l github_diff.txt`

while IFS= read -r line; do
    echo "github_diff.txt:->>$line"
done < github_diff.txt

#echo "approximate diff size: ${diff_length}"
python_files=`cat github_diff.txt | grep -E -- "\+\+\+" | awk '{print $2}' | grep -Po -- "(?<=[ab]/).+\.py$"`
#echo "python files with diff: ${python_files}"

if [ ! "${python_files}" ];then
   echo "no python files to check!"
else
    existing_python_files=""
    for file in $python_files; do
        #echo "Checking file exists: ./$file"
        if [ -f "./$file" ]; then
            existing_python_files="$existing_python_files $file"
        fi
    done
    existing_python_files=$(echo "$existing_python_files" | xargs)
    echo "python files edited in this PR:"
    echo "${existing_python_files}"
    echo "-----------------------------------"
    if [[ -z "${LINE_LENGTH}" ]]; then
    line_length=108
    else
        line_length="${LINE_LENGTH}"
    fi
    echo "-----------------------------------"
    echo "To quickly fix this, open the file in PyCharm, click 'Ctrl + A'"
    echo "then click 'Ctrl + Shift + L' to reformat the file correctly."
    echo "--"
    echo "See below for files that nee black formatting done on them:"
    echo "--"
    black --line-length ${line_length} --check ${existing_python_files}
    
fi
