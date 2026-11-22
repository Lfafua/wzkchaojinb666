@echo off
cd /d "%~dp0"
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $dir=(Get-Location).Path; $dst=Join-Path $dir 'PCForge-0.11-Windows-x64.zip'; if(Test-Path $dst){ throw 'Archive already exists' }; $tmp=[IO.Path]::GetTempFileName(); try { $out=[IO.File]::OpenWrite($tmp); try { 0..4 | ForEach-Object { $p=Join-Path $dir ('pcforge.zip.part{0:D2}' -f $_); $s=[IO.File]::OpenRead($p); try {$s.CopyTo($out)} finally {$s.Dispose()} } } finally {$out.Dispose()}; if((Get-FileHash $tmp).Hash -ne '7683ec2cdbf47a81ac0a6288155a07aa3ee25e7cffc4369f87373835ab16158a') {throw 'Checksum failed'}; [IO.File]::Copy($tmp,$dst); Write-Host 'Archive verified.' } finally { Remove-Item -LiteralPath $tmp }"
pause
