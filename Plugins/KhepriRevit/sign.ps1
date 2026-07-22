param([Parameter(Mandatory = $true)][string]$Dir)
# Sign the built Khepri Revit DLLs with the local self-signed dev cert (CN=KhepriSelfSign) so Revit
# loads the add-in headlessly without the unsigned-file security prompt. Invoked as an MSBuild
# post-build step (see KhepriRevit.csproj). A missing cert is a no-op — it must never fail the build
# (e.g. on a machine without the dev cert).
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -like '*KhepriSelfSign*' } |
        Select-Object -First 1
if (-not $cert) {
    Write-Host '  [sign] KhepriSelfSign cert not found in CurrentUser\My; skipping (add-in will be unsigned).'
    exit 0
}
foreach ($name in 'KhepriRevit.dll', 'KhepriBase.dll') {
    $path = Join-Path $Dir $name
    if (Test-Path $path) {
        try {
            $r = Set-AuthenticodeSignature -FilePath $path -Certificate $cert -ErrorAction Stop
            Write-Host "  [sign] $name = $($r.Status)"
        } catch {
            Write-Host "  [sign] $name FAILED: $($_.Exception.Message)"
        }
    }
}
exit 0
