if (-Not (Test-Path -Path .\docker.key -ErrorAction SilentlyContinue)) {
    & openssl genrsa -out docker.key 4096
}
if (-Not (Test-Path -Path .\docker.csr -ErrorAction SilentlyContinue)) {
    & openssl req -subj "/CN=ws16cont" -sha256 -new -key docker.key -config .\docker.cnf -out .\docker.csr
}
if (-Not (Test-Path -Path .\docker.crt -ErrorAction SilentlyContinue)) {
    & certreq -submit -attrib "CertificateTemplate:WebServer" -config dc-03.inmylab.de\cainmylab .\docker.csr .\docker.crt
    & openssl x509 -text -noout -in .\docker.crt >docker.txt
    $array = & openssl x509 -in docker.crt -text -noout
    for ($i = 0; $i -lt $array.length -and $array[$i] -notmatch 'Authority Information Access'; ++$i) {}
    $Url = $array[$i + 1]
    if ($Url -match 'URI:(.+)$') {
        $Url = $Matches[1]
    }
    Invoke-WebRequest -Uri http://cdp.inmylab.de/cainmylab.crt -UseBasicParsing -OutFile ca.crt
    & openssl x509 -in ca.crt -inform DER -out ca.pem
}
if (-Not (Test-Path -Path .\client.key -ErrorAction SilentlyContinue)) {
    & openssl genrsa -out client.key 4096
}
if (-Not (Test-Path -Path .\client.csr -ErrorAction SilentlyContinue)) {
    & openssl req -subj "/CN=client" -sha256 -new -key client.key -config .\client.cnf -out .\client.csr
}
if (-Not (Test-Path -Path .\client.crt -ErrorAction SilentlyContinue)) {
    & certreq -submit -attrib "CertificateTemplate:User" -config dc-03.inmylab.de\cainmylab .\client.csr .\client.crt
    & openssl x509 -text -noout -in .\client.crt >client.txt
}

if (Get-Service -Name docker -ErrorAction SilentlyContinue) {
    New-Item -Path c:\ProgramData\docker -ItemType Directory -Force
    New-Item -Path c:\ProgramData\docker\config -ItemType Directory -Force
    Copy-Item -Path daemon.json -Destination c:\ProgramData\docker\config\
    New-Item -Path c:\ProgramData\docker\certs.d -ItemType Directory -Force
    Copy-Item -Path ca.pem      -Destination C:\ProgramData\docker\certs.d\ca.pem
    Copy-Item -Path docker.crt  -Destination c:\ProgramData\docker\certs.d\server-cert.pem
    Copy-Item -Path docker.key  -Destination c:\ProgramData\docker\certs.d\server-key.pem

    Restart-Service -Name docker

    New-NetFirewallRule -Name 'DockerTLS' -DisplayName 'Docker TLS' -Direction Inbound -Protocol TCP -LocalPort 2376 -Action Allow -ErrorAction SilentlyContinue
}

New-Item -Path ~\.docker -ItemType Directory -Force
Copy-Item -Path ca.pem      -Destination ~\.docker\ca.pem
Copy-Item -Path client.crt  -Destination ~\.docker\cert.pem
Copy-Item -Path client.key  -Destination ~\.docker\key.pem