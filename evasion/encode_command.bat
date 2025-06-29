@echo off
set /p cmd=Enter command to encode: 
echo.

REM Encode to base64 using certutil
echo %cmd% > temp.txt
certutil -encode temp.txt encoded.txt > nul
for /f "skip=1 tokens=* delims=" %%a in (encoded.txt) do (
    if not "%%a"=="" if not "%%a"=="-----BEGIN CERTIFICATE-----" if not "%%a"=="-----END CERTIFICATE-----" (
        set encoded=%%a
        goto done
    )
)
:done
del temp.txt
del encoded.txt
echo [+] Base64 Encoded Command: %encoded%
