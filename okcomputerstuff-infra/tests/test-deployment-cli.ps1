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
if ($pipelineText -notmatch [regex]::Escape("okcomputerstuff-rds-host")) {
    throw 'Jenkinsfile.blog must bind the RDS endpoint credential.'
}
if ($pipelineText -notmatch [regex]::Escape('RDS_PORT')) {
    throw 'Jenkinsfile.blog must pass the RDS port explicitly.'
}
if ($pipelineText -notmatch [regex]::Escape('shellQuote(env.RDS_HOST')) {
    throw 'Jenkinsfile.blog must pass the RDS host to the deployment script.'
}
if ($deployText -notmatch [regex]::Escape('RDS_HOST="${6:?RDS host is required}"')) {
    throw 'deploy-app.sh must accept the RDS host separately from the secret.'
}
if ($deployText -notmatch [regex]::Escape('RDS_PORT="${7:-3306}"')) {
    throw 'deploy-app.sh must accept the RDS port separately from the secret.'
}
if ($deployText -match [regex]::Escape('required_rds = ("username", "password", "host", "port")')) {
    throw 'deploy-app.sh must not require host and port in the RDS-managed secret.'
}

Write-Output 'deployment CLI regression checks passed'
