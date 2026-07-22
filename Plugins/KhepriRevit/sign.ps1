param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Dir,
    [Parameter(Mandatory = $true, Position = 1, ValueFromRemainingArguments = $true)][string[]]$Names
)
# Sign the named DLLs in $Dir with the local self-signed dev cert (CN=KhepriSelfSign) so the host
# app (Revit / AutoCAD) loads the add-in without the unsigned-file security prompt. Invoked as an
# MSBuild post-build step. Each project signs ONLY the assembly it produces — KhepriBase is signed
# once, in its own build, and inherited (signature preserved) by the copies the plugins reference,
# so no DLL is ever re-signed. A missing cert is a no-op; this must never fail the build.
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -like '*KhepriSelfSign*' } |
        Select-Object -First 1
if (-not $cert) {
    Write-Host '  [sign] KhepriSelfSign cert not found in CurrentUser\My; skipping (add-in will be unsigned).'
    exit 0
}
foreach ($name in $Names) {
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
