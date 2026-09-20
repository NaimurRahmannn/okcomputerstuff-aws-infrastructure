$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pipeline = Join-Path $root 'Jenkinsfile.blog'
$deployScript = Join-Path $root 'infra/deploy-app.sh'

$pipelineText = Get-Content -Raw $pipeline
$deployText = Get-Content -Raw $deployScript

if ($pipelineText -notmatch [regex]::Escape('awscli-exe-linux-x86_64.zip')) {
    throw 'Jenkinsfile.blog must install the official AWS CLI bundle.'
}
if ($deployText -notmatch [regex]::Escape('awscli-exe-linux-x86_64.zip')) {
    throw 'deploy-app.sh must install the official AWS CLI bundle.'
}
if ($pipelineText -notmatch [regex]::Escape('AWS_CLI_BIN')) {
    throw 'Jenkinsfile.blog must invoke the workspace AWS CLI explicitly.'
}
if ($pipelineText -match 'sh """') {
    throw 'Jenkinsfile.blog must not interpolate credentials into an sh triple-quoted string.'
}
if ($pipelineText -match 'shellQuote\(env\.APP_INSTANCE_ID\)') {
    throw 'Jenkinsfile.blog must pass APP_INSTANCE_ID through the shell environment.'
}
if ($deployText -notmatch [regex]::Escape('AWS_CLI_BIN')) {
    throw 'deploy-app.sh must invoke the installed AWS CLI explicitly.'
}
if ($deployText -match [regex]::Escape('apt-get install -y awscli')) {
    throw 'deploy-app.sh must not install the distro awscli package.'
}

Write-Output 'deployment CLI regression checks passed'
