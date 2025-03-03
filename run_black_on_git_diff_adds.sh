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
curl --request GET --header "Authorization: Bearer ${GITHUB_TOKEN}" --header "X-GitHub-Api-Version: 2022-11-28" --header "Accept: application/vnd.github.diff ${github_pr_url}" > github_diff.txt
diff_length=`wc -l github_diff.txt`

while IFS= read -r line; do
    echo "github_diff.txt:->>$line"
done < github_diff.txt

echo "approximate diff size: ${diff_length}"
python_files=`cat github_diff.txt | grep -E -- "\+\+\+" | awk '{print $2}' | grep -Po -- "(?<=[ab]/).+\.py$"`
echo "python files with diff: ${python_files}"

if [ ! "${python_files}" ];then
   echo "no python files to check"
else
    echo "python files edited in this PR: ${python_files}"

    if [[ -z "${LINE_LENGTH}" ]]; then
    line_length=130
    else
        line_length="${LINE_LENGTH}"
    fi

    black --line-length ${line_length} --check ${python_files} 

fi
